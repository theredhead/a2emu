# a2emu.theredhead.nl

The Docker image is fully self-contained: promotional page, universal macOS builder download, checksums, a GitHub source link, and a Node.js backend with SQLite counters. No separate database service or external analytics service is required. Compose keeps counters in a named volume outside the container.

## Deploy with Compose

Copy `compose.yaml` to your server, then run:

```sh
docker compose pull
docker compose up -d
docker compose ps
```

The `a2emu` service listens on HTTP port `80` within Docker, with no host port published. Attach it to the same Docker network as your proxy manager, then configure the proxy host for `a2emu.theredhead.nl` to forward via HTTP to hostname `a2emu`, port `80`. The proxy manager handles HTTPS. Preserve the original Host header.

If the proxy manager is in a separate Compose project, add its existing external network to this service and declare that network in Compose. The image supports AMD64 and ARM64 Linux.

The container runs as a non-root user. Compose includes health checks, restart policy, dropped capabilities and bounded logs.

## Counters and storage

`GET /api/stats` returns page views, visits, total builder-download requests and counts per ZIP file. The download section displays visits and builder downloads. `GET /healthz` is the health endpoint.

A visit is one browser-tab session per UTC day, not a unique person. The frontend keeps a random token in sessionStorage; the server stores only its daily hash. Daily deduplication records are deleted after their day; aggregate totals remain. No cookies, IP addresses or user agents are stored. Recognizable bots are excluded. If storage or JavaScript is disabled, visit counts are approximate.

Downloads count ZIP responses that finish serving, including a range request starting at byte zero. HEAD requests, cache checks, and continuation ranges are excluded. This measures served requests, not unique people or proof of installation.

SQLite lives at `/data/counts.sqlite`, persisted by the `a2emu-data` named volume declared in Compose. Counts survive restarts and container/image updates. The image itself has no implicit VOLUME declaration, so a standalone run without a mount remains self-contained and resets on replacement.

To intentionally start fresh (for example at 1.0), run `docker compose down --volumes` and then `docker compose up -d`. This deletes the counters. To keep the history, update with `docker compose pull && docker compose up -d` without deleting volumes.

## Build and publish

On the macOS development machine:

```sh
scripts/build-release.sh
scripts/package-website.sh
node scripts/check-website.mjs
node --test Website/server.test.mjs
scripts/publish-website.sh
```

Docker Hub login must already be configured (`docker login`). Publishing builds `linux/amd64` and `linux/arm64` and pushes both `theredhead/a2emu:<app-version>` and `theredhead/a2emu:latest`. The Docker context includes only the server and packaged public files, not the workspace or local disks.

## Local preview without Docker

```sh
PUBLIC_DIR="$PWD/Website/dist" DATA_DIR=/tmp/a2emu-preview-data PORT=4173 node Website/server.mjs
```

The static-only preview script remains available as `node scripts/preview-website.mjs`; counters stay hidden without the backend.

Edit `Website/index.html`, `style.css`, or `app.js`, then package again. Downloads are versioned. Source links point to https://github.com/theredhead/a2emu; source archives are not included in the website package. The screenshot shows an exported player; the game shown is not included.
