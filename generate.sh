#!/bin/bash

# Exits if sub-processes fail,
# or if an unset variable is attempted to be used,
# or if there's a pipe failure
set -euo pipefail

# Load variables from .env file
set -o allexport
source .env
set +o allexport

# Ensure env variables are set
if [ -z "$CHAIN_ID" ] || [ -z "$L1_BASE_FEE" ] || [ -z "$NITRO_NODE_IMAGE" ]; then
  echo "Error: Environment variables are not set in .env. You need to set CHAIN_ID, L1_BASE_FEE, and NITRO_NODE_IMAGE."
  exit 1
fi

# Run the script
forge script script/Predeploys.s.sol:Predeploys \
  --chain-id $CHAIN_ID

# Run the genesis generator on nitro
docker run -v $(pwd)/genesis:/data/genesisDir --entrypoint genesis-generator $NITRO_NODE_IMAGE --genesis-json-file /data/genesisDir/genesis.json --initial-l1-base-fee $L1_BASE_FEE

echo "Done!"