#!/bin/bash

# WARNING: execute this from the repository root.
set -euo pipefail

sol_directory="loan/contracts/sol"
abi_directory="loan/contracts/abi"

extract_abi() {
    local path="$1"
    local name="$2"
    jq -c --arg path "$path" --arg name "$name" '
      (.contracts // {}) as $c
      | ($c[$path + ":" + $name].abi
         // (($c | to_entries | map(select(.key | endswith(":" + $name))) | .[0].value.abi) // null)
         // {})
    '
}

for p in "$sol_directory"/*.sol; do
    file=$(basename "$p")
    contract_name="${file%.sol}"
    file_with_extension="$contract_name.json"
    solc --base-path . --include-path "node_modules" \
        --allow-paths "bridge/contracts/sol" \
        "@openzeppelin/=node_modules/@openzeppelin/" \
        "@gluwa/usc-contracts/=node_modules/@gluwa/usc-contracts/" \
        "@example/bridge/=bridge/contracts/sol/" \
        "$p" \
        --combined-json abi --overwrite --json-indent 2 | \
        extract_abi "$p" "$contract_name" | jq --indent 2 . > "$abi_directory/$file_with_extension"
done
