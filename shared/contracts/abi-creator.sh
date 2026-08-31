#!/bin/bash

# WARNING: execute this from the repository root.
set -euo pipefail

sol_directory="shared/contracts/sol"
abi_directory="shared/contracts/abi"

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

mkdir -p "$abi_directory"

for p in "$sol_directory"/*.sol; do
    file=$(basename "$p")
    contract_name="${file%.sol}"
    file_with_extension="$contract_name.json"
    solc --base-path . --include-path "node_modules" \
        "@openzeppelin/=node_modules/@openzeppelin/" \
        "$p" \
        --combined-json abi --overwrite --json-indent 2 | \
        extract_abi "$p" "$contract_name" | jq --indent 2 . > "$abi_directory/$file_with_extension"
done
