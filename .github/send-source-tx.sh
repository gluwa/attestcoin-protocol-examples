#!/bin/bash
#
# Sends one transaction to the source chain, waits until the RPC reliably shows
# it, then prints its receipt as a single line of JSON on stdout. Progress and
# errors go to stderr.
#
# Usage:
#   .github/send-source-tx.sh <rpc-url> <private-key> <cast mktx arguments...>
#
#   .github/send-source-tx.sh "$RPC" "$PK" "$WALLET" --value 1000000000000000
#   .github/send-source-tx.sh "$RPC" "$PK" "$TOKEN" "burn(uint256)" 5000000000000000000
#   .github/send-source-tx.sh "$RPC" "$PK" --create "$BYTECODE"
#
# Why not plain `cast send`: the Sepolia RPC (QuickNode) spreads requests across
# nodes that can be a block apart. A request made just after a transaction can
# reach a node that hasn't seen it yet and get no receipt, the old nonce or the
# old balance. `cast send` then fails even though the transaction landed, or the
# next transaction is built from stale state.
#
# Instead, this script:
#   1. reads the nonce several times and keeps the highest, then builds and
#      signs the transaction with that nonce (`cast mktx`). Signing first fixes
#      the hash before anything is sent, so resending after an error can never
#      create a second transaction;
#   2. publishes it, retrying on errors;
#   3. polls for the receipt and fails unless the transaction succeeded;
#   4. waits until several reads in a row show both the receipt and the higher
#      nonce, so the caller's next request sees the new state.
# It never waits for new blocks, so it also works against anvil, which only
# mines when it receives a transaction.

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <rpc-url> <private-key> <cast mktx arguments...>" >&2
  exit 2
fi

CAST=${CAST:-$HOME/.foundry/bin/cast}
RPC_URL=$1
PRIVATE_KEY=$2
shift 2

MAX_ROUNDS=3         # rebuilds allowed if another transaction takes our nonce
BUILD_ATTEMPTS=10
PUBLISH_ATTEMPTS=10
RECEIPT_ATTEMPTS=45  # 45 x DELAY = 3 minutes for the transaction to be mined
NONCE_TAKEN_CHECKS=5 # consecutive checks before deciding our nonce was taken
SETTLE_READS=3       # consecutive reads that must agree once it is mined
SETTLE_ATTEMPTS=15   # at most ~1 minute; real lag lasts seconds
DELAY=4

log() { echo "send-source-tx: $*" >&2; }

FROM=$("$CAST" wallet address --private-key "$PRIVATE_KEY")

# Highest nonce from several separate requests, so one node that is behind
# can't hand back a nonce that has already been used. Fails if every read fails.
highest_nonce() {
  local highest=-1 nonce
  for _ in 1 2 3; do
    if nonce=$("$CAST" nonce --rpc-url "$RPC_URL" "$FROM" 2>/dev/null) && [ "$nonce" -gt "$highest" ]; then
      highest=$nonce
    fi
  done
  [ "$highest" -ge 0 ] && echo "$highest"
}

# Sets NONCE, RAW_TX and TX_HASH. Nothing has been sent at this point, so
# retrying (for example after a gas estimate ran against stale state) is safe.
build_tx() {
  local attempt
  for attempt in $(seq 1 "$BUILD_ATTEMPTS"); do
    if NONCE=$(highest_nonce) &&
      RAW_TX=$("$CAST" mktx --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --nonce "$NONCE" "$@"); then
      TX_HASH=$("$CAST" keccak "$RAW_TX")
      return 0
    fi
    log "could not build the transaction (attempt $attempt/$BUILD_ATTEMPTS); retrying"
    sleep "$DELAY"
  done
  return 1
}

# Publishing the same signed transaction again is harmless: it has the same
# hash, so the node either accepts it once or reports that it already has it.
publish_tx() {
  local attempt out
  for attempt in $(seq 1 "$PUBLISH_ATTEMPTS"); do
    if out=$("$CAST" publish --async --rpc-url "$RPC_URL" "$RAW_TX" 2>&1); then
      return 0
    fi
    case "$out" in
      *"already known"* | *"nonce too low"* | *"underpriced"*)
        # The node already has a transaction with this nonce: ours from an
        # earlier attempt, or another one. The receipt check tells which.
        log "publish: $out"
        return 0
        ;;
    esac
    log "publish failed (attempt $attempt/$PUBLISH_ATTEMPTS): $out"
    sleep "$DELAY"
  done
  return 1
}

# Sets RECEIPT. Returns 1 if the transaction is never mined, and 3 if the nonce
# kept showing as used while our transaction stayed missing, meaning another
# transaction took the nonce.
wait_for_receipt() {
  local attempt taken=0 nonce
  for attempt in $(seq 1 "$RECEIPT_ATTEMPTS"); do
    if RECEIPT=$("$CAST" receipt --async --json --rpc-url "$RPC_URL" "$TX_HASH" 2>/dev/null); then
      return 0
    fi
    if nonce=$(highest_nonce) && [ "$nonce" -gt "$NONCE" ]; then
      taken=$((taken + 1))
      [ "$taken" -ge "$NONCE_TAKEN_CHECKS" ] && return 3
    else
      taken=0
    fi
    sleep "$DELAY"
  done
  return 1
}

# Succeeds once SETTLE_READS reads in a row see both the receipt and the higher
# nonce.
wait_until_settled() {
  local attempt agreed=0 nonce
  for attempt in $(seq 1 "$SETTLE_ATTEMPTS"); do
    if "$CAST" receipt --async --rpc-url "$RPC_URL" "$TX_HASH" status >/dev/null 2>&1 &&
      nonce=$("$CAST" nonce --rpc-url "$RPC_URL" "$FROM" 2>/dev/null) && [ "$nonce" -gt "$NONCE" ]; then
      agreed=$((agreed + 1))
      [ "$agreed" -ge "$SETTLE_READS" ] && return 0
      sleep 1
    else
      agreed=0
      sleep "$DELAY"
    fi
  done
  return 1
}

RECEIPT=""
for round in $(seq 1 "$MAX_ROUNDS"); do
  RECEIPT=""
  if ! build_tx "$@"; then
    log "giving up: could not build the transaction"
    exit 1
  fi
  log "sending $TX_HASH from $FROM (nonce $NONCE)"
  if ! publish_tx; then
    log "giving up: could not publish $TX_HASH"
    exit 1
  fi

  rc=0
  wait_for_receipt || rc=$?
  case $rc in
    0) break ;;
    3) log "nonce $NONCE was used by another transaction; rebuilding (round $round/$MAX_ROUNDS)" ;;
    *)
      log "giving up: no receipt for $TX_HASH after $((RECEIPT_ATTEMPTS * DELAY))s"
      exit 1
      ;;
  esac
done

if [ -z "$RECEIPT" ]; then
  log "giving up: another transaction took the nonce in all $MAX_ROUNDS rounds"
  exit 1
fi

STATUS=$(jq -r .status <<<"$RECEIPT")
if [ "$STATUS" != "0x1" ]; then
  log "transaction $TX_HASH failed (status $STATUS):"
  echo "$RECEIPT" >&2
  exit 1
fi

if ! wait_until_settled; then
  # The transaction succeeded, so carry on; the next call may still see stale
  # state, but failing here would hide which step really broke.
  log "warning: the RPC never consistently showed $TX_HASH; continuing anyway"
fi

log "mined $TX_HASH in block $(jq -r .blockNumber <<<"$RECEIPT")"
jq -c . <<<"$RECEIPT"
