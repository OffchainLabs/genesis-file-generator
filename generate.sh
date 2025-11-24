#!/bin/bash

# Exits if sub-processes fail,
# or if an unset variable is attempted to be used,
# or if there's a pipe failure
set -euo pipefail

# Load variables from .env file (allowing overrides from CLI)
currentEnvs=$(declare -p -x)
set -o allexport
source .env
set +o allexport
eval "$currentEnvs"

# Ensure env variables are set
if [ -z "$CHAIN_ID" ] || [ -z "$L1_BASE_FEE" ] || [ -z "$NITRO_NODE_IMAGE" ]; then
  echo "Error: Environment variables are not set in .env. You need to set CHAIN_ID, L1_BASE_FEE, and NITRO_NODE_IMAGE."
  exit 1
fi

# Run the script (without printing any standard output)
forge script script/Predeploys.s.sol:Predeploys \
  --chain-id $CHAIN_ID \
  > /dev/null

# Minify the chainConfig property in the generated genesis file
# NOTE: we need to minify the chainConfig because nitro will use it to obtain the genesis blockhash,
# and if there are any unnecessary whitespaces, the blockhash will be different from what is found on-chain.
PLACEHOLDER="__CONFIG_MINIFIED__"
GENESIS_FILE="genesis/genesis.json"
config_minified=$(jq -c '.config' "$GENESIS_FILE")

# Set the placeholder in the chainConfig property and save the result
tmp=$(mktemp)
jq --arg ph "$PLACEHOLDER" '.config = $ph' "$GENESIS_FILE" | jq '.' > "$tmp"

# Replace the placeholder with the minified config
awk -v ph="\"$PLACEHOLDER\"" -v rep="$config_minified" '
  { sub(ph, rep); print }
' "$tmp" > "$GENESIS_FILE"

rm "$tmp"

# Output the generated genesis file
cat genesis/genesis.json