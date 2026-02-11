#!/usr/bin/env bash

set -uo pipefail

DEFAULT_GENESIS_FILE="genesis/genesis.json"
DEFAULT_RPC_URL="http://localhost:8449"
DEFAULT_BLOCK_TAG="latest"

GENESIS_FILE="$DEFAULT_GENESIS_FILE"
RPC_URL="$DEFAULT_RPC_URL"
BLOCK_TAG="$DEFAULT_BLOCK_TAG"

usage() {
  cat <<'EOF'
Usage:
  ./verify_alloc_code.sh [options]

Options:
  -g, --genesis <path>   Genesis file path (default: genesis/genesis.json)
  -r, --rpc <url>        RPC URL (default: http://localhost:8449)
  -b, --block <tag>      eth_getCode block tag (default: latest)
  -h, --help             Show this help message

What it does:
  - Reads every account under alloc in the genesis file
  - Fetches on-chain runtime code via eth_getCode
  - Compares on-chain code with alloc.<address>.code (or 0x if absent)
  - Prints per-address result and summary
EOF
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Error: required command not found: %s\n' "$cmd" >&2
    exit 2
  fi
}

normalize_address() {
  local value="$1"
  local normalized

  normalized="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"

  if [[ "$normalized" =~ ^0x[0-9a-f]{40}$ ]]; then
    printf '%s\n' "$normalized"
    return 0
  fi

  if [[ "$normalized" =~ ^[0-9a-f]{40}$ ]]; then
    printf '0x%s\n' "$normalized"
    return 0
  fi

  return 1
}

normalize_hex() {
  local value="${1:-0x}"
  local normalized

  normalized="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  normalized="${normalized#0x}"

  if [[ -z "$normalized" ]]; then
    printf '0x\n'
    return 0
  fi

  if [[ ! "$normalized" =~ ^[0-9a-f]+$ ]]; then
    return 1
  fi

  if (( ${#normalized} % 2 != 0 )); then
    normalized="0${normalized}"
  fi

  printf '0x%s\n' "$normalized"
}

shorten_hex() {
  local value="$1"
  local max_len="${2:-80}"

  if (( ${#value} <= max_len )); then
    printf '%s' "$value"
  else
    printf '%s...' "${value:0:max_len}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--genesis)
      if [[ $# -lt 2 ]]; then
        printf 'Error: %s expects a value\n' "$1" >&2
        exit 2
      fi
      GENESIS_FILE="$2"
      shift 2
      ;;
    -r|--rpc)
      if [[ $# -lt 2 ]]; then
        printf 'Error: %s expects a value\n' "$1" >&2
        exit 2
      fi
      RPC_URL="$2"
      shift 2
      ;;
    -b|--block)
      if [[ $# -lt 2 ]]; then
        printf 'Error: %s expects a value\n' "$1" >&2
        exit 2
      fi
      BLOCK_TAG="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown option: %s\n' "$1" >&2
      usage
      exit 2
      ;;
  esac
done

require_cmd jq
require_cmd curl

if [[ ! -f "$GENESIS_FILE" ]]; then
  printf 'Error: genesis file not found: %s\n' "$GENESIS_FILE" >&2
  exit 2
fi

if ! jq -e '.alloc and (.alloc | type == "object")' "$GENESIS_FILE" >/dev/null 2>&1; then
  printf 'Error: file does not contain a valid alloc object: %s\n' "$GENESIS_FILE" >&2
  exit 2
fi

total=0
ok=0
mismatch=0
rpc_error=0
invalid=0

printf 'Checking alloc code from %s\n' "$GENESIS_FILE"
printf 'RPC: %s | Block: %s\n' "$RPC_URL" "$BLOCK_TAG"
printf '\n'

jq_query='.alloc | to_entries[] | [.key, (.value | if type == "object" then (.code // "0x") else "0x" end)] | @tsv'

while IFS=$'\t' read -r raw_address raw_expected_code; do
  total=$((total + 1))

  if ! address="$(normalize_address "$raw_address")"; then
    printf '[INVALID] %s (invalid address in alloc)\n' "$raw_address"
    invalid=$((invalid + 1))
    continue
  fi

  if ! expected_code="$(normalize_hex "$raw_expected_code")"; then
    printf '[INVALID] %s (invalid expected code)\n' "$address"
    invalid=$((invalid + 1))
    continue
  fi

  payload="$(jq -nc --arg addr "$address" --arg block "$BLOCK_TAG" '{"jsonrpc":"2.0","method":"eth_getCode","params":[$addr,$block],"id":1}')"

  if ! response="$(curl --silent --show-error --fail \
    --header 'Content-Type: application/json' \
    --data "$payload" \
    "$RPC_URL" 2>&1)"; then
    printf '[RPC_ERROR] %s (%s)\n' "$address" "$response"
    rpc_error=$((rpc_error + 1))
    continue
  fi

  rpc_message="$(printf '%s' "$response" | jq -r '.error.message // empty' 2>/dev/null || true)"
  if [[ -n "$rpc_message" ]]; then
    printf '[RPC_ERROR] %s (%s)\n' "$address" "$rpc_message"
    rpc_error=$((rpc_error + 1))
    continue
  fi

  actual_raw="$(printf '%s' "$response" | jq -r '.result // empty' 2>/dev/null || true)"
  if [[ -z "$actual_raw" ]]; then
    printf '[RPC_ERROR] %s (missing result)\n' "$address"
    rpc_error=$((rpc_error + 1))
    continue
  fi

  if ! actual_code="$(normalize_hex "$actual_raw")"; then
    printf '[RPC_ERROR] %s (invalid code from RPC)\n' "$address"
    rpc_error=$((rpc_error + 1))
    continue
  fi

  if [[ "$actual_code" == "$expected_code" ]]; then
    code_size=$(((${#actual_code} - 2) / 2))
    printf '[OK] %s (%s bytes)\n' "$address" "$code_size"
    ok=$((ok + 1))
  else
    expected_size=$(((${#expected_code} - 2) / 2))
    actual_size=$(((${#actual_code} - 2) / 2))
    printf '[MISMATCH] %s\n' "$address"
    printf '  expected: %s bytes %s\n' "$expected_size" "$(shorten_hex "$expected_code" 90)"
    printf '  actual  : %s bytes %s\n' "$actual_size" "$(shorten_hex "$actual_code" 90)"
    mismatch=$((mismatch + 1))
  fi
done < <(jq -r "$jq_query" "$GENESIS_FILE")

printf '\n'
printf 'Summary: total=%s ok=%s mismatch=%s rpc_error=%s invalid=%s\n' \
  "$total" "$ok" "$mismatch" "$rpc_error" "$invalid"

if (( mismatch == 0 && rpc_error == 0 && invalid == 0 )); then
  printf 'Result: PASS\n'
  exit 0
fi

printf 'Result: FAIL\n'
exit 1
