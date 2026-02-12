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
ARB_OS_VERSION="$(trim_and_strip_comment "${ARB_OS_VERSION:-}")"
L1_BASE_FEE="$(trim_and_strip_comment "${L1_BASE_FEE:-}")"
CHAIN_OWNER="$(trim_and_strip_comment "${CHAIN_OWNER:-}")"
IS_ANYTRUST="$(trim_and_strip_comment "${IS_ANYTRUST:-}")"
export CHAIN_ID ARB_OS_VERSION L1_BASE_FEE CHAIN_OWNER IS_ANYTRUST

# Ensure env variables are set
if [ -z "$CHAIN_ID" ] || [ -z "$L1_BASE_FEE" ] || [ -z "$NITRO_NODE_IMAGE" ]; then
  echo "Error: Environment variables are not set in .env. You need to set CHAIN_ID, L1_BASE_FEE, and NITRO_NODE_IMAGE."
  exit 1
fi

# Run the script (without printing any standard output)
forge script script/Predeploys.s.sol:Predeploys \
  --chain-id $CHAIN_ID \
  > /dev/null

# Minify serializedChainConfig while keeping it as a JSON string.
# NOTE: nitro uses this value to derive the genesis block hash, so whitespace differences matter.
GENESIS_FILE="genesis/genesis.json"
tmp=$(mktemp)

jq '
  .serializedChainConfig |= (
    if type == "string"
    then (fromjson | tojson)
    else tojson
    end
  )
' "$GENESIS_FILE" > "$tmp"

mv "$tmp" "$GENESIS_FILE"

# Output the generated genesis file
cat genesis/genesis.json