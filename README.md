# presserl-deployment

Deployment of [Presserl](https://github.com/UnterrainerInformatik/presserl) at
`presserl.unterrainer.info` — the **staging site**, reachable from LAN/VPN only. Its first public fork
is [`guFalcon/alexpresse`](https://github.com/guFalcon/alexpresse) (*Alex-Presse*, `alexpresse.net`),
see [Staging and forks](#staging-and-forks). It holds only what is specific to this site: `deploy/site.env`
(hostname, Keycloak realm, name), the compose file with Traefik labels and the realm file. The
application comes as the upstream image `gufalcon/presserl`; the full installation guide is
upstream in [`deploy/INSTALL.md`](https://github.com/UnterrainerInformatik/presserl/blob/master/deploy/INSTALL.md).

## How it deploys

The upstream pipeline builds the image and sends a `repository_dispatch` (`presserl-image`, with the
version) to this repository. `.github/workflows/deploy.yml` then runs the UnterrainerInformatik
`deploy-workflow`: it copies `deploy/` to `DEPLOY_DIR` on the server (via WireGuard and SSH), writes
`.env` with the version and runs `up.sh`. A manual run (*Actions → DEPLOY → Run workflow*) deploys a
given version or, if left empty, the latest upstream release tag; a push to this repository
redeploys the latest release too.

`up.sh` loads `.env`, `site.env` and `secrets.env` and starts `presserl`, `postgres`, `rustfs`
and `languagetool` with docker compose. `presserl` joins the Traefik network `proxy_default`; the
database, the media store and the spell checker stay on the private compose network. The database keeps its data in `PRESSERL_DB_DIR`,
the uploaded images live in the named volume `<PRESSERL_ROUTER>_presserl-media` (e.g.
`presserl_presserl-media`) — back up both.

## GitHub secrets (this repository)

| Secret | Value |
|---|---|
| `DEPLOY_SSH_PRIVATE_KEY` | private SSH key whose public key is in the deploy user's `~/.ssh/authorized_keys` on the server |
| `DEPLOY_SSH_USER` | deploy user on the server |
| `DEPLOY_SERVER` | server host name or IP as reachable through WireGuard |
| `DEPLOY_SSH_PORT` | usually `22` |
| `DEPLOY_DIR` | e.g. `/app/deploy/presserl` |
| `DATA_DIR` | e.g. `/app/data/presserl` (parent of `PRESSERL_DB_DIR`) |
| `DOCKER_HUB_USER` | `gufalcon` |
| `DOCKER_IMAGE_NAME` | `presserl` |
| `WG_CONFIG` | WireGuard client configuration for the runner |

Upstream needs `DEPLOYMENT_DISPATCH_TOKEN`: a fine-grained personal access token limited to this
repository with *Contents: Read and write* (required for `repository_dispatch`).

## Server secrets (`secrets.env`, once per server)

Never committed; the deploy workflow does not touch it. Create it in `DEPLOY_DIR`:

```sh
cat > secrets.env <<'EOF'
PRESSERL_DB_PASSWORD=<long random string>
PRESSERL_OIDC_BACKEND_SECRET=<Keycloak: Clients > presserl-backend > Credentials>
PRESSERL_OIDC_READER_SECRET=<Keycloak: Clients > presserl-reader > Credentials>
PRESSERL_PUBLISHER_USERNAME=<first publisher>
PRESSERL_PUBLISHER_PASSWORD=<their initial password>
PRESSERL_MEDIA_S3_ACCESS_KEY=<random, e.g. openssl rand -hex 10>
PRESSERL_MEDIA_S3_SECRET_KEY=<random, e.g. openssl rand -hex 20>
EOF
chmod 600 secrets.env
```

The two `PRESSERL_MEDIA_S3_*` values are new with image uploads: add them to an existing
`secrets.env` before the first deploy of a version with uploads, otherwise compose stops with
"missing in secrets.env".

## Keycloak

Import `keycloak/presserl-realm.json` (hostname already set to `presserl.unterrainer.info`) as
described upstream in `INSTALL.md`, step 2 (new realm) or 2a (existing realm).

A realm imported before the reader login lacks the client `presserl-reader`. Add it with a partial
import of the same file (*Clients* only, *If a resource exists: Skip*), then copy its secret into
`PRESSERL_OIDC_READER_SECRET` in `secrets.env` — before the next deploy, otherwise compose stops
with "missing in secrets.env".

## Forking for another newspaper

Fork this repository, then change `deploy/site.env` (`PRESSERL_HOSTNAME`, `PRESSERL_OIDC_ISSUER`,
`PRESSERL_ROUTER`, `PRESSERL_DB_DIR`, name), replace the hostname in `keycloak/presserl-realm.json`,
set the GitHub secrets above and create `secrets.env` on the target server. `up.sh` refuses to
start when `PRESSERL_ROUTER` or `PRESSERL_DB_DIR` already belong to a deployment in another
directory, so a fork pushed before its `site.env` is adapted cannot take over this site.

## Staging and forks

Only this repository receives the upstream dispatch, so staging runs every new image first. A fork
such as `alexpresse` is not dispatched; a release reaches it by promotion:

1. The release runs here on staging and looks fine.
2. In the fork: `git pull upstream master` (remote `upstream` = this repository; on a conflict in
   `deploy/theme/custom.css` keep the fork's own theme).
3. Push the fork. The push redeploys the latest upstream release tag; a manual run
   (*Actions → DEPLOY → Run workflow*) deploys a given version.
