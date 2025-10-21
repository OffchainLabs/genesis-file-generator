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

# Output the generated genesis file
cat genesis/genesis.json
