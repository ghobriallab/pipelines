---
name: docker-resolve
description: Resolves a verified Docker container image URL for a given tool by checking Artifact Registry then public registries (Seqera Wave, biocontainers). Returns a strategy and confirmed image URL, or NOT_FOUND if no usable image exists. Use this before ever attempting a docker build.
when_to_use: Before building a Docker image, when you need to check if a container already exists for a tool. Call this whenever a pipeline process needs a container directive verified or populated.
allowed-tools: Bash
user-invocable: false
---

# Docker Resolve Skill

Resolve a verified Docker container image URL for a given tool. Work through the
three checks below **in order** and stop at the first that succeeds.

## Inputs (from task context)

- `TOOL_NAME` — the bioinformatics tool (e.g. `star`, `arcashla`, `featurecounts`)
- `TOOL_VERSION` — desired version (e.g. `2.7.11a`); may be `any` if version is flexible
- `GCP_PROJECT`, `GCP_REGION`, `ARTIFACT_REGISTRY` — loaded from `$PIPELINES_DIR/.env`

## Registry hostname

`$ARTIFACT_REGISTRY` already contains the full registry prefix including the GCP
project. **Never append `$GCP_PROJECT` to it.**

```bash
REGISTRY_HOST="${ARTIFACT_REGISTRY}"
# e.g. us-docker.pkg.dev/ghobrial-pipelines
```

All custom image URLs follow this pattern:
```
${REGISTRY_HOST}/<tool-name>/<tool-name>:<version>
```

---

## Check 1: Artifact Registry — does a custom image already exist?

### 1a. List all repositories

```bash
gcloud artifacts repositories list \
  --project=$GCP_PROJECT \
  --format="value(name)" 2>/dev/null
```

Fuzzy-match the output against `TOOL_NAME` (e.g. `arcashla`, `arcas-hla`, `arcas_hla`
all match `arcasHLA`). If no repos match → skip to Check 2.

### 1b. List images in each matching repository

For each matching repo:

```bash
gcloud artifacts docker images list \
  ${REGISTRY_HOST}/<repo-name> \
  --project=$GCP_PROJECT \
  --include-tags \
  --format="value(version,tags)" 2>/dev/null
```

**Do NOT pass `--location`** — that flag is not accepted by this command.

Collect all image+tag pairs. If the command returns no rows → skip that repo.

### 1c. Verify reachability

Only inspect URLs constructed from actual 1b results — never guessed URLs:

```bash
docker manifest inspect ${REGISTRY_HOST}/<repo>/<image>:<tag> \
  2>/dev/null && echo REACHABLE || echo NOT_REACHABLE
```

Prefer a pinned version tag over `latest` when both exist.

**If a reachable image is found:**
- Strategy = `USE_EXISTING_CUSTOM`
- Output the exact full image URL
- **Stop — do not proceed to Check 2.**

---

## Check 2: Are existing container directives already valid public images?

For each `container` directive already present in the process modules and
`nextflow.config`:

- Seqera Wave URLs (`community.wave.seqera.io/...`):
  ```bash
  curl -s --head "https://community.wave.seqera.io/..." | head -1
  ```
- quay.io / docker.io / ghcr.io images:
  ```bash
  docker manifest inspect <image_url> 2>/dev/null && echo EXISTS || echo MISSING
  ```

**If all existing directives are reachable:**
- Strategy = `USE_EXISTING_PUBLIC`
- Output the confirmed URL(s)
- **Stop.**

---

## Check 3: Are public containers available for this tool?

Check Seqera Wave by probing known URL patterns:
```
community.wave.seqera.io/library/<tool>:<version>--<hash>
```

Also check:
- `quay.io/biocontainers/<tool>:<version>`
- `quay.io/nf-core/<tool>:<version>`

Verify each candidate with `docker manifest inspect` or `curl --head`.

**If a reachable public image is found:**
- Strategy = `POPULATE_PUBLIC`
- Output the verified URL
- **Stop.**

---

## Output

Always return a structured result:

```
STRATEGY: USE_EXISTING_CUSTOM | USE_EXISTING_PUBLIC | POPULATE_PUBLIC | NOT_FOUND
IMAGE_URL: <full image URL, or "none" if NOT_FOUND>
NOTES: <what was checked, what was found or not found>
```

`NOT_FOUND` means all three checks failed — the caller should spawn the
`docker-build` agent to build a custom image.
