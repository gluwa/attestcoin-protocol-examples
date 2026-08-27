#!/bin/bash

# WARNING: execute this from the repository root.

sol_directory="loan/contracts/sol"
abi_directory="loan/contracts/abi"

for p in "$sol_directory"/*; do
    file=$(basename "$p")
    contract_name="${file//.sol/}"
    file_with_extension="$contract_name.json"
    solc --base-path . --include-path "node_modules" \
        --allow-paths "bridge/contracts/sol" \
        "$sol_directory/$file" \
        --combined-json abi --overwrite --json-indent 2 | \
        jq ".contracts[\"$p:$contract_name\"].abi // {}" > "$abi_directory/$file_with_extension"
done
