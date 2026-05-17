# Custom Caddy Image

This repository builds a custom Caddy Docker image with `xcaddy`, publishes it to GHCR, and only rebuilds when the official Caddy release or plugin release tags change.

## Configure plugins

Edit `plugins.txt`. Blank lines and comments are ignored.

```text
github.com/caddy-dns/cloudflare
github.com/caddy-dns/cloudflare@v0.2.1
```

Unpinned GitHub plugins are resolved to the latest GitHub release tag, falling back to the newest repository tag when no release exists. Pinned plugins stay pinned.

## Published image

The workflow publishes a multi-architecture image to:

```text
ghcr.io/<owner>/<repo>
```

Each release pushes:

- `latest`
- `caddy-vX.Y.Z`
- `caddy-vX.Y.Z-plugins-<sha>`

The `latest` image stores the resolved versions in labels:

- `io.github.my-caddy.caddy.version`
- `io.github.my-caddy.plugins`
- `io.github.my-caddy.plugins.sha256`

## Local checks

Resolve the current desired versions:

```bash
bash scripts/resolve-versions.sh
```

Build locally:

```bash
docker build \
  --build-arg CADDY_VERSION=v2.10.0 \
  --build-arg CADDY_DOCKER_VERSION=2.10.0 \
  --build-arg XCADDY_ARGS="" \
  --build-arg PLUGINS_JSON="[]" \
  --build-arg PLUGINS_SHA256="$(printf '[]' | sha256sum | awk '{print $1}')" \
  --build-arg IMAGE_VERSION=v2.10.0-plugins-4f53cda18c2b \
  --build-arg SOURCE_URL=https://github.com/example/my-caddy \
  -t my-caddy:test .
```
