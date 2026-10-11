# poh-chain

Solana-style Proof of History + Proof of Stake chains for Nadcab Console, on the
[Agave](https://github.com/anza-xyz/agave) validator (v4.3.0).

CI builds the `nadcab/poh-chain` Docker image, boots a two-validator cluster with an RPC node,
checks block production, finality, a treasury transfer, fees, the bundled programs and the
WebSocket API, then publishes the image to the `latest` release:

```sh
curl -fsSL https://github.com/ndcbweb/poh-chain/releases/download/latest/poh-chain.tar.gz | gunzip | docker load
```

## Image

| Command | What it does |
| --- | --- |
| `poh-genesis` | Validator keys, genesis (treasury, stake, SPL Token / Token-2022 / ATA / Memo and core BPF programs) and a ledger per bootstrap validator. Idempotent. |
| `poh-validator N` | Bootstrap validator N. Ports: gossip `8001 + 100(N-1)`, dynamic `8002-8040` (+offset), RPC `8899` (+offset). |
| `poh-rpc` | Non-voting RPC node following the validators: JSON-RPC on `RPC_PORT` (8545), WebSocket on `RPC_PORT + 1`, transaction history and token indexes. |

All commands keep state in `/data`. Run with `--network host` and `--ulimit nofile=1000000:1000000`.

### poh-genesis

| Env | Default | |
| --- | --- | --- |
| `VALIDATORS` | 1 | Bootstrap validators (1-4) |
| `TREASURY_PUBKEY` | | Base58 address that receives the supply |
| `TREASURY_LAMPORTS` | | Treasury balance (1 coin = 10^9 lamports) |
| `VALIDATOR_LAMPORTS` | 500 coins | Each validator identity's balance (pays vote fees) |
| `STAKE_LAMPORTS` | 1000 coins | Each validator's delegated stake |
| `TICKS_PER_SLOT` / `TICK_US` | 64 / 6250 | Slot time = ticks x tick duration (400 ms) |
| `SLOTS_PER_EPOCH` | 432000 | Epoch length; `WARMUP=1` starts with short epochs |
| `LAMPORTS_PER_SIGNATURE` | 5000 | Base fee |
| `FEE_BURN` | 50 | Percent of fees burned |
| `COMMISSION` | 10 | Validators' vote commission |
| `INFLATION` | full | `full` (8% tapering to 1.5%), `pico` or `none` |

`/data/cluster.json` records the genesis hash, shred version and validator keys.
