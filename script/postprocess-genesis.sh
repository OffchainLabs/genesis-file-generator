#!/bin/bash

# Exits if sub-processes fail,
# or if an unset variable is attempted to be used,
# or if there's a pipe failure
set -euo pipefail

# This script expects to run from the repo root.
GENESIS_PATH="genesis/genesis.json"

if ! command -v jq &> /dev/null; then
  echo "Error: jq is required to post-process genesis.json."
  exit 1
fi

if [ ! -f "$GENESIS_PATH" ]; then
  echo "Error: $GENESIS_PATH not found after Foundry script."
  exit 1
fi

resolve_abs_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    echo "$path"
  else
    echo "$(pwd)/$path"
  fi
}

ALLOC_ABS_PATH=""
CHAIN_CONFIG_ABS_PATH=""

if [ -n "${CUSTOM_ALLOC_ACCOUNT_FILE:-}" ]; then
  ALLOC_ABS_PATH="$(resolve_abs_path "$CUSTOM_ALLOC_ACCOUNT_FILE")"
  if [ ! -f "$ALLOC_ABS_PATH" ]; then
    echo "Error: Custom alloc account file not found: $CUSTOM_ALLOC_ACCOUNT_FILE"
    exit 1
  fi
fi

if [ -n "${CUSTOM_SERIALIZED_CHAIN_CONFIG:-}" ]; then
  CHAIN_CONFIG_ABS_PATH="$(resolve_abs_path "$CUSTOM_SERIALIZED_CHAIN_CONFIG")"
  if [ ! -f "$CHAIN_CONFIG_ABS_PATH" ]; then
    echo "Error: Custom serialized chain config file not found: $CUSTOM_SERIALIZED_CHAIN_CONFIG"
    exit 1
  fi
fi

DROP_DEFAULTS=false
if [ "${LOAD_DEFAULT_PREDEPLOYS:-true}" = "false" ]; then
  DROP_DEFAULTS=true
fi

ENABLE_NATIVE_JSON=false
if [ "${ENABLE_NATIVE_TOKEN_SUPPLY:-false}" = "true" ]; then
  ENABLE_NATIVE_JSON=true
fi

SET_CONFIG=false
if [ -n "$CHAIN_CONFIG_ABS_PATH" ]; then
  SET_CONFIG=true
fi

DEFAULT_PREDEPLOY_JSON="[]"
if [ -n "$ALLOC_ABS_PATH" ] || [ "$DROP_DEFAULTS" = "true" ]; then
  if [ ! -f "src/PredeployConstants.sol" ]; then
    echo "Error: src/PredeployConstants.sol not found."
    exit 1
  fi
  default_predeploy_list=$(grep -oE '0x[0-9a-fA-F]{40}' src/PredeployConstants.sol | tr 'A-F' 'a-f' | sort -u)
  if [ -n "$default_predeploy_list" ]; then
    DEFAULT_PREDEPLOY_JSON=$(printf '%s\n' "$default_predeploy_list" | jq -R -s -c 'split("\n")[:-1]')
  fi
fi

JQ_CUSTOM_ALLOC_ARG=(--argjson customAlloc null)
if [ -n "$ALLOC_ABS_PATH" ]; then
  # jq (jqlang/jq) does not support --argfile; use --rawfile + fromjson instead.
  JQ_CUSTOM_ALLOC_ARG=(--rawfile customAlloc "$ALLOC_ABS_PATH")
fi

JQ_CONFIG_ARG=(--argjson cfg null)
if [ -n "$CHAIN_CONFIG_ABS_PATH" ]; then
  # jq (jqlang/jq) does not support --argfile; use --rawfile + fromjson instead.
  JQ_CONFIG_ARG=(--rawfile cfg "$CHAIN_CONFIG_ABS_PATH")
fi

JQ_FILTER='
def normkey:
  ascii_downcase | if startswith("0x") then . else "0x"+. end;
def normalize_alloc:
  to_entries | map({key:(.key|normkey), value:.value}) | from_entries;
def parse_json($v):
  if $v == null then null
  elif ($v|type) == "string" then ($v | fromjson)
  else $v end;
def remove_defaults($defaults):
  if $defaults == null or ($defaults|length==0) then .
  else .alloc |= with_entries(
    (.key|normkey) as $k
    | select( ($defaults | index($k)) | not )
  )
  end;
def merge_custom_alloc($custom; $defaults):
  if $custom == null then .
  else
    (.alloc // {}) as $alloc_in
    | ($alloc_in | normalize_alloc) as $alloc
    | ($custom | normalize_alloc) as $cust
    | ($alloc | keys) as $ak
    | ($cust | keys) as $ck
    | ($ck | map(select(. as $k | ($ak | index($k)) != null))) as $conflicts
    | if ($conflicts|length) > 0 then
        error("Address conflict detected in alloc: " + ($conflicts|join(", ")))
      else
        (if $defaults != null and ($defaults|length>0) then
            ($ck | map(select(. as $k | ($defaults | index($k)) != null))) as $defaultConflicts
            | if ($defaultConflicts|length) > 0 then
                error("Custom alloc conflicts with default predeploy address: " + ($defaultConflicts|join(", ")))
              else .
              end
          else .
          end)
        | .alloc = ($alloc + $cust)
      end
  end;
. as $genesis
| (if $setConfig then .config = (parse_json($cfg)) else . end)
| (if $enableNative then .arbOSInit = ((.arbOSInit // {}) + {nativeTokenSupplyManagementEnabled:true}) else . end)
| (if $dropDefaults then remove_defaults($defaults) else . end)
| merge_custom_alloc(parse_json($customAlloc); $defaults)
'

tmp_genesis="genesis/genesis.json.tmp"
jq \
  --argjson enableNative "$ENABLE_NATIVE_JSON" \
  --argjson dropDefaults "$DROP_DEFAULTS" \
  --argjson defaults "$DEFAULT_PREDEPLOY_JSON" \
  --argjson setConfig "$SET_CONFIG" \
  "${JQ_CUSTOM_ALLOC_ARG[@]}" \
  "${JQ_CONFIG_ARG[@]}" \
  "$JQ_FILTER" \
  "$GENESIS_PATH" > "$tmp_genesis"
mv "$tmp_genesis" "$GENESIS_PATH"
