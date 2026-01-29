#!/bin/bash

# Exits if sub-processes fail,
# or if an unset variable is attempted to be used,
# or if there's a pipe failure
set -euo pipefail

# Default values for CLI flags
ENABLE_NATIVE_TOKEN_SUPPLY=false
CUSTOM_SERIALIZED_CHAIN_CONFIG=""
CUSTOM_ALLOC_ACCOUNT_FILE=""
LOAD_DEFAULT_PREDEPLOYS=true

# Help function
show_help() {
  echo "Usage: ./generate.sh [OPTIONS]"
  echo ""
  echo "Generate a genesis.json file for an Arbitrum chain with pre-deployed contracts."
  echo ""
  echo "Options:"
  echo "  --enable-native-token-supply       Enable nativeTokenSupplyManagementEnabled in arbOSInit"
  echo "  --custom-serializedChainConfig     Path to custom serialized chain config JSON file"
  echo "  --custom-alloc-account-file        Path to custom alloc account file for additional predeploys"
  echo "  --load-default-predeploys          Load default predeploy contracts (default: true)"
  echo "  --no-load-default-predeploys       Skip loading default predeploy contracts"
  echo "  --help, -h                         Show this help message"
  echo ""
  echo "Environment variables (set in .env file):"
  echo "  CHAIN_ID                           Chain ID for the new chain"
  echo "  IS_ANYTRUST                        Whether it's an Anytrust chain (true/false)"
  echo "  ARB_OS_VERSION                     ArbOS version to use"
  echo "  CHAIN_OWNER                        Chain owner address"
  echo "  L1_BASE_FEE                        Initial L1 base fee"
  echo "  NITRO_NODE_IMAGE                   Nitro node Docker image"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --enable-native-token-supply)
      ENABLE_NATIVE_TOKEN_SUPPLY=true
      shift
      ;;
    --custom-serializedChainConfig)
      CUSTOM_SERIALIZED_CHAIN_CONFIG="$2"
      shift 2
      ;;
    --custom-alloc-account-file)
      CUSTOM_ALLOC_ACCOUNT_FILE="$2"
      shift 2
      ;;
    --load-default-predeploys)
      LOAD_DEFAULT_PREDEPLOYS=true
      shift
      ;;
    --no-load-default-predeploys)
      LOAD_DEFAULT_PREDEPLOYS=false
      shift
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help to see available options."
      exit 1
      ;;
  esac
done

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

if ! command -v docker &> /dev/null; then
  echo "Error: Docker is required to run this script."
  exit 1
fi

if ! command -v forge &> /dev/null; then
  echo "Error: forge is required to run this script."
  exit 1
fi

mkdir -p genesis

# Run the Foundry script locally to generate genesis.json
forge script script/Predeploys.s.sol:Predeploys --chain-id "$CHAIN_ID" > /dev/null

# Post-process genesis.json based on CLI flags
export ENABLE_NATIVE_TOKEN_SUPPLY
export LOAD_DEFAULT_PREDEPLOYS
export CUSTOM_ALLOC_ACCOUNT_FILE
export CUSTOM_SERIALIZED_CHAIN_CONFIG

bash script/postprocess-genesis.sh

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
echo "Genesis file generated at: genesis/genesis.json"
# Calculate BlockHash and SendRoot using Nitro's genesis-generator
echo ""
echo "Calculating BlockHash and SendRoot..."
docker run --rm \
  -v "$(pwd)/genesis:/data/genesisDir" \
  --entrypoint genesis-generator \
  "$NITRO_NODE_IMAGE" \
  --genesis-json-file /data/genesisDir/genesis.json \
  --initial-l1-base-fee "$L1_BASE_FEE"
