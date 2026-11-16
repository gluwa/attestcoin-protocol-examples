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
#      the hash before anything is sent, so resending after an error can't
#      create a second transaction;
#   2. publishes it, retrying on errors;
#   3. polls for the receipt and fails unless the transaction succeeded;
#   4. waits until several reads in a row show both the receipt and the higher
#      nonce, so the caller's next request sees the new state.
# A new transaction is signed only when publishing fails with a gas price that
# is too low, or when the nonce stays used for ~30s while our receipt stays
# missing (another sender took it, e.g. parallel workflows sharing the funding
# key). The receipt check keeps watching every hash sent so far, but if our
# first transaction was in fact mined and every read missed it for that long,
# the rebuilt one can land as well.
#
# Contract addresses in the printed receipt are checksummed (cast prints them
# lowercase), matching what `forge create` and ethers return.
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
NONCE_TAKEN_CHECKS=8 # consecutive checks (~30s) before deciding our nonce was taken
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
# Returns 4 if the gas price was too low, so the caller can rebuild with a
# fresh estimate.
publish_tx() {
  local attempt out
  for attempt in $(seq 1 "$PUBLISH_ATTEMPTS"); do
    if out=$("$CAST" publish --async --rpc-url "$RPC_URL" "$RAW_TX" 2>&1); then
      return 0
    fi
    case "$out" in
      *"already known"* | *"nonce too low"* | *"replacement transaction underpriced"*)
        # The node already has a transaction with this nonce: ours from an
        # earlier attempt, or another one. The receipt check tells which.
        log "publish: $out"
        return 0
        ;;
      *"transaction underpriced"* | *"less than block base fee"*)
        # Nothing was accepted; resending the same signed transaction won't help.
        log "publish: gas price too low: $out"
        return 4
        ;;
    esac
    log "publish failed (attempt $attempt/$PUBLISH_ATTEMPTS): $out"
    sleep "$DELAY"
  done
  return 1
}

# Polls every transaction sent so far, since one from an earlier round may have
# been mined after all. Sets RECEIPT, and TX_HASH and NONCE to the transaction
# found. Returns 1 if none is ever mined, and 3 if the current nonce kept
# showing as used while our transactions stayed missing, meaning another
# transaction took the nonce.
wait_for_receipt() {
  local attempt taken=0 nonce i
  for attempt in $(seq 1 "$RECEIPT_ATTEMPTS"); do
    for i in "${!SENT_HASHES[@]}"; do
      if RECEIPT=$("$CAST" receipt --async --json --rpc-url "$RPC_URL" "${SENT_HASHES[$i]}" 2>/dev/null); then
        if [ "${SENT_HASHES[$i]}" != "$TX_HASH" ]; then
          log "warning: earlier transaction ${SENT_HASHES[$i]} was mined; $TX_HASH may land as well"
        fi
        TX_HASH=${SENT_HASHES[$i]}
        NONCE=${SENT_NONCES[$i]}
        return 0
      fi
    done
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
SENT_HASHES=()
SENT_NONCES=()
for round in $(seq 1 "$MAX_ROUNDS"); do
  RECEIPT=""
  if ! build_tx "$@"; then
    log "giving up: could not build the transaction"
    exit 1
  fi
  log "sending $TX_HASH from $FROM (nonce $NONCE)"
  rc=0
  publish_tx || rc=$?
  case $rc in
    0) ;;
    4)
      log "rebuilding with a fresh gas price (round $round/$MAX_ROUNDS)"
      continue
      ;;
    *)
      log "giving up: could not publish $TX_HASH"
      exit 1
      ;;
  esac
  SENT_HASHES+=("$TX_HASH")
  SENT_NONCES+=("$NONCE")

  rc=0
  wait_for_receipt || rc=$?
  case $rc in
    0) break ;;
    3) log "nonce $NONCE was used by another transaction; rebuilding (round $round/$MAX_ROUNDS)" ;;
    *)
      log "giving up: no receipt for ${SENT_HASHES[*]} after $((RECEIPT_ATTEMPTS * DELAY))s"
      exit 1
      ;;
  esac
done

if [ -z "$RECEIPT" ]; then
  log "giving up: no transaction was mined in $MAX_ROUNDS rounds"
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

CONTRACT=$(jq -r '.contractAddress // empty' <<<"$RECEIPT")
if [ -n "$CONTRACT" ]; then
  CONTRACT=$("$CAST" to-check-sum-address "$CONTRACT")
  RECEIPT=$(jq --arg addr "$CONTRACT" '.contractAddress = $addr' <<<"$RECEIPT")
fi

log "mined $TX_HASH in block $(jq -r .blockNumber <<<"$RECEIPT")"
jq -c . <<<"$RECEIPT"
