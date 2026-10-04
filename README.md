# strata-image

Automated container builds of [Niko1221/Strata](https://github.com/Niko1221/Strata) for NVIDIA RTX 30-series
cards (sm_86), published to GHCR as `ghcr.io/ryanmelena/strata`. The image runs as any non-root UID.

## How it works

`.github/workflows/strata-build.yml` runs every 4 hours. It checks Strata's newest release tag. If the tag differs
from `UPSTREAM_TAG`, it:

1. builds the upstream Dockerfile at that tag,
2. builds this repo's `Dockerfile` on top of it,
3. smoke-tests the result as UID 2000,
4. pushes `ghcr.io/ryanmelena/strata:<tag>` and `:latest`,
5. commits the new tag to `UPSTREAM_TAG`.

Only release tags trigger a build, not every commit to upstream `main`. A failed build leaves `UPSTREAM_TAG`
unchanged, so the next scheduled run retries.

## Running as non-root

Upstream Strata assumes root. This repo's `Dockerfile` makes `/opt/strata` writable by any UID and sets
`HOME=/data`, so the image runs under whatever `user:` you set. The host directory mounted at `/data` must be
owned by that UID. The extra layer re-adds `/opt/strata` with new permissions, so the image is larger than
upstream by roughly the size of that directory.

## Usage

Host requirements: NVIDIA driver 580 or newer (the image is CUDA 13.0) and the NVIDIA Container Toolkit.

```bash
mkdir -p ./data && chown -R 2000:2000 ./data
echo "STRATA_API_KEY=$(openssl rand -hex 32)" > .env && chmod 600 .env
```

```yaml
services:
  strata:
    image: ghcr.io/ryanmelena/strata:latest
    user: "2000:2000"
    restart: unless-stopped
    environment:
      MODEL: IQ2_XS                # Q2_0 | IQ2_XS | IQ3_XXS | IQ3_S
      CONTEXT: "32768"
      VISION: "no"                 # no | yes | cpu
      API_KEY: ${STRATA_API_KEY:?set STRATA_API_KEY in .env}
    volumes:
      - ./data:/data
    ports:
      - "8080:8080"
    ulimits:
      memlock: { soft: -1, hard: -1 }
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

The first start downloads the model (~70-85 GB) into `./data`. The API is OpenAI-compatible at
`http://<host>:8080/v1` and Anthropic-compatible at `/v1/messages`. All upstream settings (`FAMILY`, `KV`,
`GPU`, `GPUS`, `LOW_RAM`, `REINSTALL`, ...) work as documented in
[Strata's INSTALL.md](https://github.com/Niko1221/Strata/blob/main/docs/INSTALL.md#docker-linux).

## Maintenance

- **Force a rebuild:** Actions → Build Strata → Run workflow → tick *force*.
- **Other GPUs:** change `CUDA_ARCHITECTURES=86` in the workflow (89 for RTX 40, 120 for RTX 50; separate
  several with `;`).
- **Old tags:** each image is several GB. Delete old versions under the package's **Manage versions**.
- **Schedule shutoff:** GitHub disables scheduled workflows after 60 days without repo activity. If upstream goes
  that long without a release, re-enable the workflow from the Actions tab.

## License

Build tooling in this repo: MIT. Strata itself is MIT; the models it downloads carry their own licenses.
