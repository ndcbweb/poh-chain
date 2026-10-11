#!/usr/bin/env bash
# Boots a 2-validator cluster plus an RPC node from nadcab/poh-chain:latest on this machine, then
# checks block production, consensus, a treasury transfer, fees, programs and the WebSocket API.
set -euo pipefail
cd "$(dirname "$0")/.."

image=nadcab/poh-chain:latest
work=$(mktemp -d)
host_ip=$(hostname -I | awk '{print $1}')
rpc_url="http://$host_ip:8545"
lamports_per_signature=7000

sudo sysctl -qw vm.max_map_count=1000000 fs.nr_open=1000000 \
  net.core.rmem_max=134217728 net.core.rmem_default=134217728 \
  net.core.wmem_max=134217728 net.core.wmem_default=134217728

cleanup() {
  status=$?
  if (( status != 0 )); then
    for name in poh-v1 poh-v2 poh-rpc; do
      echo "===== $name (last 80 lines)"
      docker logs --tail 80 "$name" 2>&1 || true
    done
  fi
  docker rm -f poh-v1 poh-v2 poh-rpc >/dev/null 2>&1 || true
  exit "$status"
}
trap cleanup EXIT

run() {
  docker run -d --name "$1" --network host --ulimit nofile=1000000:1000000 \
    --log-opt max-size=50m --log-opt max-file=3 \
    -e HOST_IP="$host_ip" "${@:3}" -v "$work/$2:/data" "$image" "${run_cmd[@]}"
}
call() {
  curl -sf --max-time 10 "$rpc_url" -H 'content-type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":${2:-[]}}"
}

treasury=$(node test/keypair.mjs "$work/treasury.json")
echo "treasury $treasury"

mkdir -p "$work/validators" "$work/rpc"
docker run --rm -v "$work/validators:/data" \
  -e VALIDATORS=2 -e TREASURY_PUBKEY="$treasury" -e TREASURY_LAMPORTS=1000000000000000000 \
  -e STAKE_LAMPORTS=5000000000000 -e SLOTS_PER_EPOCH=8192 \
  -e LAMPORTS_PER_SIGNATURE=$lamports_per_signature -e COMMISSION=7 \
  "$image" poh-genesis
genesis_hash=$(sudo jq -r .genesisHash "$work/validators/cluster.json")
[[ -n $genesis_hash && $genesis_hash != null ]]

run_cmd=(poh-validator 1); run poh-v1 validators
run_cmd=(poh-validator 2); run poh-v2 validators
run_cmd=(poh-rpc); run poh-rpc rpc -e ENTRY_IP="$host_ip" -e GOSSIP_PORT=8601 -e DYNAMIC_PORT_RANGE=8602-8640

echo "Waiting for the RPC node to follow the chain"
for attempt in $(seq 1 120); do
  slot=$(call getSlot | jq -r '.result // 0' 2>/dev/null || echo 0)
  [[ $slot -gt 30 ]] && break
  sleep 5
done
echo "rpc slot $slot after $((attempt * 5))s"
[[ $slot -gt 30 ]]

[[ $(call getGenesisHash | jq -r .result) == "$genesis_hash" ]]
call getVersion | jq -c .result
votes=$(call getVoteAccounts)
echo "$votes" | jq -c '.result.current[] | {node: .nodePubkey, stake: .activatedStake, commission}'
[[ $(echo "$votes" | jq '.result.current | length') -eq 2 ]]
[[ $(echo "$votes" | jq -c '[.result.current[].commission] | unique') == "[7]" ]]

sleep 20
finalized=$(call getSlot '[{"commitment":"finalized"}]' | jq -r .result)
echo "finalized slot $finalized"
[[ $finalized -gt 10 ]]

[[ $(call getBalance "[\"$treasury\"]" | jq -r .result.value) -eq 1000000000000000000 ]]

recipient=$(node test/keypair.mjs "$work/recipient.json")
docker run --rm --network host -v "$work:/keys" "$image" \
  solana -u "$rpc_url" -k /keys/treasury.json transfer --allow-unfunded-recipient "$recipient" 12.5 --output json \
  > "$work/transfer.json"
signature=$(jq -r .signature "$work/transfer.json")
echo "transfer $signature"
for attempt in $(seq 1 30); do
  balance=$(call getBalance "[\"$recipient\",{\"commitment\":\"confirmed\"}]" | jq -r .result.value)
  [[ $balance -eq 12500000000 ]] && break
  sleep 2
done
[[ $balance -eq 12500000000 ]]

tx=$(call getTransaction "[\"$signature\",{\"commitment\":\"confirmed\",\"maxSupportedTransactionVersion\":0}]")
fee=$(echo "$tx" | jq -r .result.meta.fee)
echo "fee $fee"
[[ $fee -eq $lamports_per_signature ]]
[[ $(call getSignaturesForAddress "[\"$recipient\",{\"commitment\":\"confirmed\"}]" | jq '.result | length') -ge 1 ]]

for program in TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb \
  ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr Stake11111111111111111111111111111111111111; do
  [[ $(call getAccountInfo "[\"$program\",{\"encoding\":\"base64\"}]" | jq -r .result.value.executable) == true ]] \
    || { echo "missing program $program"; exit 1; }
done

call getEpochInfo | jq -c .result
call getSupply | jq -c '.result.value | {total, circulating}'
call getBlock "[$finalized,{\"maxSupportedTransactionVersion\":0,\"transactionDetails\":\"signatures\"}]" | jq -c '.result | {blockhash, blockHeight, blockTime}'

node --input-type=module -e "
  const ws = new WebSocket('ws://$host_ip:8546');
  const timer = setTimeout(() => { console.error('no slot notification'); process.exit(1); }, 20000);
  ws.onopen = () => ws.send(JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'slotSubscribe' }));
  ws.onmessage = (event) => {
    const msg = JSON.parse(event.data);
    if (msg.method === 'slotNotification') { console.log('ws slot', msg.params.result.slot); clearTimeout(timer); process.exit(0); }
  };
"

echo "===== resources"
docker stats --no-stream --format '{{.Name}} {{.MemUsage}} {{.CPUPerc}}'
before=$(sudo du -sk "$work/validators/validator-1/ledger" | cut -f1)
slot_before=$(call getSlot | jq -r .result)
sleep 120
after=$(sudo du -sk "$work/validators/validator-1/ledger" | cut -f1)
slot_after=$(call getSlot | jq -r .result)
echo "validator ledger grew $(( after - before )) KB over $(( slot_after - slot_before )) slots in 120s"
sudo du -sh "$work/validators/validator-1/ledger" "$work/rpc/ledger"
docker stats --no-stream --format '{{.Name}} {{.MemUsage}} {{.CPUPerc}}'
echo "integration test passed"
