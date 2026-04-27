# Claude Agent Guide: lido-charon-distributed-validator-node (LCDVN)

This repo is the Docker Compose launcher for one node of an Obol Distributed Validator (DV) cluster operating inside the **Lido Simple DVT module** (staking module ID 2 on mainnet). It is a near-twin of `charon-distributed-validator-node` (CDVN) with Lido-specific additions: the `validator-ejector` service and the Lido EasyTrack / oracle wiring.

> This repo is a **deployment guide, not a canonical deployment**. Lido Simple DVT operators are expected to fork/clone and adapt for their own ops — version-pin client images, tune monitoring, add HA, etc. Don't treat it as turnkey production config.

For non-Lido DV operators use `charon-distributed-validator-node` instead. Module coverage: **Simple DVT only**. Lido CSM and stVault are **not** yet optimised for this repo.

## Quickstart

```bash
# Pick a network
cp .env.sample.hoodi .env          # or .env.sample.mainnet

# If using commit-boost (instead of mev-boost):
cp commit-boost/config.toml.sample.hoodi commit-boost/config.toml

# Edit .env to set your Lido-specific values (see below), client selection, monitoring.
# Drop a completed .charon/ (from DKG) into the repo root.
docker compose up -d
docker compose logs -f charon
```

**Prerequisite:** a `.charon/` directory from a completed DKG ceremony must exist in the repo root before start. No DKG yet → run one via [launchpad.obol.org](https://launchpad.obol.org) first.

## Mandatory Lido-specific env vars

All exist in `.env.sample.*` — uncomment and set:

| Var | What | Where to find |
|-----|------|---------------|
| `VE_OPERATOR_ID` | Your Lido Simple DVT operator ID | [operators.lido.fi](https://operators.lido.fi) (mainnet) / Lido testnet dashboard (hoodi) |
| `VE_EASY_TRACK_MOTION_CREATOR_ADDRESSES_ALLOWLIST` | Your cluster's Lido Operator SAFE manager address(es), JSON array | The SAFE you registered with Lido when onboarding |
| `VE_STAKING_MODULE_ID` | Pre-set to `2` (Simple DVT) — don't change | `.env.sample.*` |
| `VE_LOCATOR_ADDRESS`, `VE_ORACLE_ADDRESSES_ALLOWLIST`, `VE_EASY_TRACK_ADDRESS` | Lido contract addresses for the network | Pre-populated per network in the env samples — treat as config, not secret |

To enable Obol's log collection (helps the core team diagnose cluster issues), uncomment `MONITORING=${MONITORING:-monitoring},monitoring-log-collector`.

## validator-ejector

Lido publishes validator exit signals via on-chain oracles. The `validator-ejector` service in this stack watches the CL/EL, listens for signed exit messages targeting this operator, and forwards them to the DV so Charon + VCs can cooperate to exit the validator. This is the **key Lido-specific piece** — without it, a DV running under Lido Simple DVT can't honour Lido's exit protocol and risks slashing or socialised losses.

If `validator-ejector` won't start or logs oracle-address mismatches, double-check `VE_ORACLE_ADDRESSES_ALLOWLIST` against the network's Lido deployment (they rotate occasionally).

## Client stack (same shape as CDVN)

Modular via `.env` knobs: `EL`, `CL`, `VC`, `MEV`. Defaults ship reasonable choices per network.

> **Pick non-default clients where you can.** Same reasoning as CDVN — every operator running defaults deepens client supermajorities and raises correlated-failure risk for Ethereum and for the cluster. Within a Lido Simple DVT cluster, coordinate with your co-operators (step 6 of the README): pick EL/CL/VC combinations *different* from theirs so a single client bug can't take the whole cluster offline.

## Networks

Env samples shipped: `.env.sample.mainnet`, `.env.sample.hoodi`.

- **mainnet** — Lido Simple DVT live module, `VE_STAKING_MODULE_ID=2`.
- **hoodi** — Lido's current testnet target.

The README still mentions `.env.sample.holesky` — this is **stale**. Holesky is dead; the sample doesn't ship and shouldn't be used.

## Compose layout

Same structure as CDVN, plus Lido-specific services:

- `docker-compose.yml` — Charon, validator-ejector, monitoring base.
- `compose-el.yml` / `compose-cl.yml` / `compose-vc.yml` / `compose-mev.yml` — client variants wired via `EL`/`CL`/`VC`/`MEV` in `.env`.
- `compose-monitoring.yml`, `compose-debug.yml` — observability add-ons.
- `commit-boost/` — commit-boost config samples per network (requires `MEV=mev-commitboost`).
- `alloy/` — log-collection config.

## Standard workflows

### Verify cluster health after setup
```bash
docker compose exec charon charon alpha test <beacon|validator|peers|infra>
```
Use the global `test-a-dv-cluster` skill to interpret failures.

### Update to a new release
```bash
docker compose down
git stash                 # save local .env / custom overrides
git pull
git checkout v0.X.Y       # pin to a release tag
git stash apply
docker compose up -d
```

### Switching a client
Same as CDVN: `docker compose down`, edit the `EL`/`CL`/`VC`/`MEV` line in `.env`, `docker compose up -d`. For commit-boost, also update `commit-boost/config.toml`.

### Use an external beacon node + execution client (skip the local EL/CL stack)

When the operator already runs a BN/EL elsewhere and doesn't want Docker Compose to start its own, set both clients to the `-none` sentinel and point Charon + validator-ejector at the external endpoints:

```bash
EL=el-none
CL=cl-none

# Charon → external BN / EL
CHARON_BEACON_NODE_ENDPOINTS=https://your-bn.example:5052
CHARON_EXECUTION_CLIENT_RPC_ENDPOINT=https://your-el.example:8545

# Lido-specific: validator-ejector has its own endpoint vars (see gotcha below)
VE_BEACON_NODE_URL=https://your-bn.example:5052
VE_EXECUTION_NODE_URL=https://your-el.example:8545
```

`el-none` / `cl-none` don't match any Compose profile, so nothing local gets started for those layers. The VC still runs locally and talks to Charon as usual — no VC-side changes needed.

**Lido gotcha (validator-ejector):** `VE_BEACON_NODE_URL` and `VE_EXECUTION_NODE_URL` default to `http://${CL}:5052` and `http://${EL}:8545` in the env samples. If `CL`/`EL` are set to `cl-none`/`el-none` and these two vars aren't overridden, they resolve to `http://cl-none:5052` / `http://el-none:8545` — hostnames that don't exist — and validator-ejector fails to start. CDVN doesn't have this trap; it's specific to this repo. (The defaults could be reworked so this isn't needed — tracked as a future fix, leaving as-is for now.)

**Auth to hosted providers:** Charon supports optional HTTP headers on BN requests via `CHARON_BEACON_NODE_HEADERS` (see the env sample). Use it to pass API keys when the external BN requires auth. The env sample warns the headers are sent to primary and fallback endpoints alike, so only wire in BNs you trust.

**Mixed cases** (local CL + external EL, or vice versa) aren't covered explicitly — same pattern, but only set the one `-none` sentinel and only override the endpoint var(s) for the external side. Don't forget the matching `VE_*` override.

### Run two DV stacks on one host, sharing the BN/EL from one of them

Common ops pattern: stack A runs a full EL+CL+Charon+VC+validator-ejector. Stack B runs only Charon+VC+validator-ejector (with `EL=el-none`/`CL=cl-none`) and reuses stack A's BN/EL to avoid running two sync'd clients on the same box. Each stack is **its own DV cluster** — separate `.charon/` from a separate DKG, separate `VE_OPERATOR_ID`, separate validator-ejector instance. They just happen to share client infrastructure.

Goal: stack B's Charon reaches stack A's `lighthouse` / `nethermind` (or whichever clients) by service name, with no extra host-port publishing. Achieved by attaching stack B's containers to stack A's Docker network as a secondary network, while keeping stack B's own `dvnode` network for internal comms (VC ↔ Charon ↔ validator-ejector).

**Stack A** — no structural changes. Just pin the Compose project name so the network name is predictable:

```bash
# stack-a/.env
COMPOSE_PROJECT_NAME=stack-a       # → network becomes "stack-a_dvnode"
```

Start stack A first so the network exists before stack B comes up.

**Stack B** — set `EL=el-none`, `CL=cl-none`, override endpoint vars to stack A's service names, and change the Charon P2P host port so it doesn't clash with stack A's 3610:

```bash
# stack-b/.env
COMPOSE_PROJECT_NAME=stack-b
EL=el-none
CL=cl-none
CHARON_BEACON_NODE_ENDPOINTS=http://lighthouse:5052       # service name on stack A's network
CHARON_EXECUTION_CLIENT_RPC_ENDPOINT=http://nethermind:8545
VE_BEACON_NODE_URL=http://lighthouse:5052
VE_EXECUTION_NODE_URL=http://nethermind:8545
CHARON_PORT_P2P_TCP=3611                                   # must differ from stack A's 3610
```

Add a `docker-compose.override.yml` in stack B that attaches Charon + validator-ejector to stack A's network as a secondary:

```yaml
# stack-b/docker-compose.override.yml
services:
  charon:
    networks:
      - dvnode
      - stack-a
  validator-ejector:
    networks:
      - dvnode
      - stack-a

networks:
  stack-a:
    external: true
    name: stack-a_dvnode    # must match stack A's <COMPOSE_PROJECT_NAME>_dvnode
```

**Why a secondary network rather than `external: true` on `dvnode` itself:** if both stacks share one network as `dvnode`, the service aliases `charon`, `validator-ejector`, and the VC name collide — Docker's embedded DNS will return IPs from either stack for those names, and stack B's VC could end up talking to stack A's Charon. Keeping each stack's own `dvnode` private, and only joining a shared secondary network for BN/EL access, avoids that. Adjust VCs similarly if you ever need them to reach across (normally you don't — the VC talks to Charon only, on the private network).

**Port conflicts to watch on the host:**
- `CHARON_PORT_P2P_TCP` (3610 default) — must differ per stack.
- `MONITORING_PORT_GRAFANA` (3000), `MONITORING_PORT_LOKI`, any other published monitoring ports — only relevant if stack B runs its own monitoring. Usually skip monitoring on stack B and let stack A's Prometheus scrape stack B's Charon over the shared network.
- Charon's validator API (3600) and metrics (3620) are **not** published to the host by default — network-internal only — so they don't collide.

**Validator-ejector gotcha still applies:** the `VE_*` overrides above are required, for the same reason as the external-BN section above.

**Prerequisites:**
- Same Docker host.
- Same Docker engine version high enough to support secondary networks on a service (any recent Compose v2 is fine).
- Stack A up before stack B — otherwise stack B's `external: true` lookup fails.

## Monitoring & alerts

Same stack as CDVN: Prometheus + Grafana + Loki + Alloy. Remote-write and Loki push target Obol's hosted monitoring; Discord alerts via `ALERT_DISCORD_IDS`. See the `obol-monitoring` skill for deep diagnostics.

Lido operators should keep `monitoring-log-collector` enabled so the core team can correlate validator-ejector / exit issues across the Simple DVT module.

## Ports

Charon: 3600 (validator API) / 3610 (p2p tcp) / 3620 (metrics). EL/CL ports overridable via `EL_PORT_*` / `CL_PORT_*` env vars.

## Deployment best practices

Obol maintains a [deployment best practices guide](https://docs.obol.org/run-a-dv/prepare/deployment-best-practices) covering hardware sizing, networking, monitoring, backups, key handling, and operational hygiene. **Proactively offer to audit the user's setup against it** — walk through `.env` values, client pinning, monitoring + Discord alerting, `validator-ejector` health, and `.charon/` backup posture, then surface concrete improvements. Lido Simple DVT operators are held to a higher reliability bar than solo DVs (socialised slashing risk, exit-protocol SLAs), so the review should weight monitoring coverage and exit-path readiness heavily.

## Related products

- **`charon-distributed-validator-node`** — (CDVN) non-Lido stock DV stack. Same shape, simpler config.
- **Obol Stack + `helm-charts/charts/dv-pod`** — Kubernetes-native path; Lido SDVT operators running on k8s should evaluate this.
- **DappNode** (`dappnode/DAppNodePackage-obol-generic`) — third-party package to run a DV on a DappNode.

## Key docs

- Obol: https://docs.obol.org/docs/int/key-concepts
- Obol errors: https://docs.obol.org/docs/faq/errors
- Lido Simple DVT: https://operators.lido.fi/modules/simple-dvt
- validator-ejector (Lido): https://github.com/lidofinance/validator-ejector
- Deployment best practices: https://docs.obol.org/run-a-dv/prepare/deployment-best-practices
- Launchpad: https://launchpad.obol.org
- Canonical agent index: https://obol.org/llms.txt
