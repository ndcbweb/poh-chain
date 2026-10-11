#!/usr/bin/env bash
# Downloads the on-chain programs Solana clusters ship in genesis (same set and versions as
# agave v4.3.0 fetch-spl.sh / fetch-core-bpf.sh) and writes the matching solana-genesis arguments.
set -euo pipefail

out=${1:?usage: programs.sh OUT_DIR}
mkdir -p "$out"
upgradeable=BPFLoaderUpgradeab1e11111111111111111111111
args=()

add() {
  local file=$1 address=$2 loader=$3 url=$4
  curl -fsSL --retry 5 --retry-delay 2 -o "$out/$file" "$url"
  if [[ $loader == "$upgradeable" ]]; then
    args+=(--upgradeable-program "$address" "$loader" "$out/$file" none)
  else
    args+=(--bpf-program "$address" "$loader" "$out/$file")
  fi
}

gh=https://github.com/solana-program

add spl-token.so TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA "$upgradeable" \
  "$gh/token/releases/download/p-token@v1.0.0/spl_p_token.so"
add spl-token-2022.so TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb "$upgradeable" \
  "$gh/token-2022/releases/download/program@v10.0.0/spl_token_2022.so"
add spl-memo-1.so Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMNo BPFLoader1111111111111111111111111111111111 \
  "$gh/memo/releases/download/program@v1.0.0/spl_memo.so"
add spl-memo-3.so MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr BPFLoader2111111111111111111111111111111111 \
  "$gh/memo/releases/download/program@v3.0.0/spl_memo.so"
add spl-memo-4.so Memo4c2pN8afCj432Lb7RMVKi9PbQnnW7ewFFaV3oAH "$upgradeable" \
  "$gh/memo/releases/download/program@v4.0.0/spl_memo.so"
add spl-associated-token-account.so ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL BPFLoader2111111111111111111111111111111111 \
  "$gh/associated-token-account/releases/download/program@v1.1.2/spl_associated_token_account.so"
add spl-feature-proposal.so Feat1YXHhH6t1juaWF74WLcfv4XoNocjXA6sPWHNgAse BPFLoader2111111111111111111111111111111111 \
  "$gh/feature-proposal/releases/download/program@v1.0.0/spl_feature_proposal.so"

add core-address-lookup-table.so AddressLookupTab1e1111111111111111111111111 "$upgradeable" \
  "$gh/address-lookup-table/releases/download/program%40v3.0.0/solana_address_lookup_table_program.so"
add core-config.so Config1111111111111111111111111111111111111 "$upgradeable" \
  "$gh/config/releases/download/program%40v3.0.0/solana_config_program.so"
add core-feature-gate.so Feature111111111111111111111111111111111111 "$upgradeable" \
  "$gh/feature-gate/releases/download/program%40v0.0.1/solana_feature_gate_program.so"
add core-stake.so Stake11111111111111111111111111111111111111 "$upgradeable" \
  "$gh/stake/releases/download/program%40v5.1.0/solana_stake_program.so"

printf '%s\n' "${args[@]}" > "$out/genesis-args"
ls -l "$out"
