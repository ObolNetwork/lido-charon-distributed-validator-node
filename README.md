![Obol Logo](https://obol.tech/obolnetwork.png)

<h1 align="center">Lido Charon Distributed Validator Node (LCDVN)</h1>

This repo contains the [docker-compose](https://docs.docker.com/compose/) files needed to run one node in a [charon](https://github.com/ObolNetwork/charon) [Distributed Validator Cluster](https://docs.obol.tech/docs/int/key-concepts#distributed-validator-cluster) for a Lido Simple DVT module.

A distributed validator node is a machine running:

- An Ethereum Execution client
- An Ethereum Consensus client
- An Ethereum Distributed Validator client
- An Ethereum Validator client

![Distributed Validator Node](DVNode.png)

# Getting Started

**`lido-charon-distributed-validator-node` is a repo intended as a _deployment guide_ and is not intended to be the canonical way to deploy a distributed validator.**

**Operators are encouraged to use this repository to build and maintain their own configurations that work for their individual use case.**


Check the Obol [docs](https://docs.obol.tech/docs/start/quickstart_group) for detailed instructions on how to get started using example repos. 

To configure this repo for a particular network, follow these instructions. If you do not, your node will fail to start. 

1. Copy `.env.sample.<network-name>` to `.env`:

```sh
    # mainnet
    cp .env.sample.mainnet .env

    # holesky
    cp .env.sample.holesky .env

    # hoodi
    cp .env.sample.hoodi .env
```

> **_NOTE:_** If you are using commit-boost, instead of mev-boost, do the same for commit-boost's config:

```sh
    # mainnet
    cp commit-boost/.config.toml.sample.mainnet commit-boost/config.toml

    # holesky
    cp commit-boost/.config.toml.sample.holesky commit-boost/config.toml

    # hoodi
    cp commit-boost/.config.toml.sample.hoodi commit-boost/config.toml
```

2. Grab your operator ID from the lido [mainnet dashboard](https://operators.lido.fi/) or [testnet dashboard](https://operators-holesky.testnet.fi/).
3. Find `VE_OPERATOR_ID` in `.env` and set it to your operator ID.
4. Find `VE_EASY_TRACK_MOTION_CREATOR_ADDRESSES_ALLOWLIST=["0xYourNodeOperatorRewardAddress"]`, uncomment it, and change `0xYourNodeOperatorRewardAddress` to your Lido Operator SAFE manager address for your cluster.
5. To enable log collection with alloy which will stream logs to the Obol Core team to help identify cluster issues find `MONITORING=${MONITORING:-monitoring},monitoring-log-collector` and uncomment it.
6. Consult with the others in your cluster, and choose a set of execution layer (EL), consensus layer (CL), validator client (VC) and mev clients (MEV) for your setup that maximises the client diversity of your cluster; by commenting and uncommenting one of each in the opening lines of your `.env` file.
7. Save and close the `.env` file.

> [!IMPORTANT]  
> You will need a `.charon/` folder from a completed DKG ceremony present in this repo to complete the remaining setup of the node.

Finally, to run the node run the following command.

```sh
docker compose up -d
```

To update your node to a new release, run the following commands;

```sh
# Stop the node
docker compose down
# Save any local changes
git stash
git pull
# Check out the latest version of the repo (replace `v.0.*.* with e.g. `v0.2.0`)
git checkout v0.*.*
# Re-apply the local changes
git stash apply
# Restart the node
docker compose up -d
```

# Security

- **Grafana is only published on `127.0.0.1`.** To view it from another machine, use an SSH tunnel: `ssh -L 3000:127.0.0.1:3000 <user>@<node>`, then open `http://localhost:3000`. Anonymous visitors get read-only access, and password logins are disabled because dashboards and datasources are provisioned from this repo.
- **Docker-published ports bypass host firewalls such as `ufw`.** Only bind a port to a non-loopback address (e.g. `MONITORING_IP_GRAFANA`, `EL_IP_HTTP`) if a provider or network firewall restricts who can reach it. By default only the P2P ports are published on all interfaces.
- **Avoid descriptive hostnames.** DNS names and TLS certificates naming the network or staking module (e.g. `lido`, `mainnet`) make a node easy to find with internet-wide scans.
- **If you ran a release before the Grafana hardening,** Grafana now starts from a fresh Docker volume and no longer uses `data/grafana`. After upgrading, run `./grafana/security-check.sh` (it may need `sudo`). It reports whether Grafana is published on a public address. It lists anything in the old `data/grafana` that this stack does not create, such as service accounts, tokens, users, datasources, plugins, organizations, dashboards, alert rules and contact points. It also lists changed or added files under `grafana/`, which older releases mounted writable. Report findings to security@obol.tech, then delete `data/grafana`. Grafana stores secrets with a default encryption key, so if your Grafana was reachable, rotate any credentials you stored in it, such as webhook URLs or tokens used by contact points.
- **Upgrading leaves the old Grafana database behind.** Anything created in the Grafana UI, such as custom dashboards, alert rules, contact points or users, stays in the unused `data/grafana` and does not carry over to the fresh Grafana. Before upgrading, export any custom dashboards (Share > Export) and note your alert rules. Do not copy the old database across, as it may contain unauthorized changes. To set customizations up again, add dashboards as JSON files under `grafana/dashboards/`, or re-enable logins with your own admin password in a `docker-compose.override.yml`, adding `:docker-compose.override.yml` to the end of `COMPOSE_FILE` in `.env` so it is loaded:

  ```yaml
  services:
    grafana:
      environment:
        GF_AUTH_DISABLE_LOGIN_FORM: "false"
        # Visitors must log in to see anything.
        GF_AUTH_ANONYMOUS_ENABLED: "false"
        GF_SECURITY_ADMIN_PASSWORD: "<a strong password>"
        # Generate with: openssl rand -hex 32
        GF_SECURITY_SECRET_KEY: "<your own random key>"
  ```

  **Set the admin password before you restart with this override.** `GF_SECURITY_ADMIN_PASSWORD` only applies when Grafana creates its database, and your Grafana has most likely already created it with the default `admin` / `admin`. Run `docker compose exec grafana grafana cli admin reset-admin-password '<a strong password>'` first, then `docker compose up -d`.

  `GF_SECURITY_SECRET_KEY` replaces Grafana's publicly known default key for encrypting stored secrets, such as the webhook URLs and tokens of contact points. Set it before adding any. Changing it later makes the secrets already stored unreadable, and you'll have to enter them again.

  Keep Grafana bound to `127.0.0.1` and reach it through an SSH tunnel. Logins go over plain HTTP, so only bind it elsewhere behind a provider or network firewall.

# FAQs

Check the Obol docs for frequent [errors and resolutions](https://docs.obol.tech/docs/faq/errors).
