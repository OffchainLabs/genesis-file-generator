#!/bin/bash

# Exits if sub-processes fail,
# or if an unset variable is attempted to be used,
# or if there's a pipe failure
set -euo pipefail

# Path to the generated genesis file
GENESIS_FILE="genesis/genesis.json"

# Help function
show_help() {
  echo "Usage: ./generate.sh [OPTIONS]"
  echo ""
  echo "Generate a genesis.json file for an Arbitrum chain with pre-deployed contracts."
  echo ""
  echo "Options:"
  echo "  --help, -h                         Show this help message"
  echo ""
  echo "Environment variables (set in .env file):"
  echo "  CHAIN_ID                           Chain ID for the new chain"
  echo "  IS_ANYTRUST                        Whether it's an Anytrust chain (true/false)"
  echo "  ARBOS_VERSION                      ArbOS version to use"
  echo "  CHAIN_OWNER                        Chain owner address"
  echo "  L1_BASE_FEE                        Initial L1 base fee"
  echo "  ENABLE_NATIVE_TOKEN_SUPPLY         Whether to enable native token supply management in ArbOS (true/false)"
  echo "  NITRO_NODE_IMAGE                   Nitro node Docker image"
  echo "  LOAD_DEFAULT_PREDEPLOYS            Whether to include default predeploys in the genesis file (true/false)"
  echo "  CUSTOM_ALLOC_ACCOUNT_FILE          Path to custom alloc account file for additional predeploys (optional)"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
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

# docker --env-file keeps inline comments in values (e.g. "1000  # note"),
# so we normalize env vars before passing them to forge.
trim_and_strip_comment() {
  local raw="$1"
  raw="${raw%%#*}"
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"
  printf "%s" "$raw"
}

CHAIN_ID="$(trim_and_strip_comment "${CHAIN_ID:-}")"
ARBOS_VERSION="$(trim_and_strip_comment "${ARBOS_VERSION:-}")"
L1_BASE_FEE="$(trim_and_strip_comment "${L1_BASE_FEE:-}")"
CHAIN_OWNER="$(trim_and_strip_comment "${CHAIN_OWNER:-}")"
IS_ANYTRUST="$(trim_and_strip_comment "${IS_ANYTRUST:-}")"
LOAD_DEFAULT_PREDEPLOYS="$(trim_and_strip_comment "${LOAD_DEFAULT_PREDEPLOYS:-}")"
ENABLE_NATIVE_TOKEN_SUPPLY="$(trim_and_strip_comment "${ENABLE_NATIVE_TOKEN_SUPPLY:-}")"
export CHAIN_ID ARBOS_VERSION L1_BASE_FEE CHAIN_OWNER IS_ANYTRUST LOAD_DEFAULT_PREDEPLOYS ENABLE_NATIVE_TOKEN_SUPPLY

# Ensure env variables are set
if [ -z "$CHAIN_ID" ] || [ -z "$L1_BASE_FEE" ] || [ -z "$NITRO_NODE_IMAGE" ] || [ -z "$CHAIN_OWNER" ] || [ -z "$ARBOS_VERSION" ]; then
  echo "Error: Environment variables are not set in .env. You need to set at least CHAIN_ID, L1_BASE_FEE, NITRO_NODE_IMAGE, CHAIN_OWNER, and ARBOS_VERSION."
  exit 1
fi

# Ensure forge and jq are installed
if ! command -v forge &> /dev/null; then
  echo "Error: forge is required to run this script."
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "Error: jq is required to run this script."
  exit 1
fi

mkdir -p genesis

# Run the Foundry script locally to generate the initial genesis.json file
forge script script/GenerateGenesis.s.sol:GenerateGenesis --chain-id "$CHAIN_ID" > /dev/null

# Add additional alloc entries if specified
if [ -n "$CUSTOM_ALLOC_ACCOUNT_FILE" ]; then
  if [ ! -f "$CUSTOM_ALLOC_ACCOUNT_FILE" ]; then
    echo "Error: Custom alloc account file was specified, but not found: $CUSTOM_ALLOC_ACCOUNT_FILE"
    exit 1
  fi

  tmpExtraAlloc=$(mktemp)
  # jq uses --slurpfile to read the custom alloc entries as an array and then merge it with the existing .alloc object
  jq --slurpfile customAllocEntriesFile "$CUSTOM_ALLOC_ACCOUNT_FILE" '.alloc += $customAllocEntriesFile[0]' "$GENESIS_FILE" > "$tmpExtraAlloc"
  mv "$tmpExtraAlloc" "$GENESIS_FILE"
fi

# Minify serializedChainConfig while keeping it as a JSON string.
# NOTE: nitro uses this value to derive the genesis block hash, so whitespace (and other characters) differences matter.
tmpSerializedConfig=$(mktemp)

# Serialization of the chain config is performed with jq:
# It checks if serializedChainConfig is a string and:
#    - If it's a string: parse it (fromjson) and re-encode it (tojson) to normalize formatting
#    - If it's not a string: directly encode it to JSON string format
jq '
  .serializedChainConfig |= (
    if type == "string"
    then (fromjson | tojson)
    else tojson
    end
  )
' "$GENESIS_FILE" > "$tmpSerializedConfig"

mv "$tmpSerializedConfig" "$GENESIS_FILE"

# Output the generated genesis file
cat "$GENESIS_FILE"