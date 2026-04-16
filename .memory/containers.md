# Container Strategy

## Container Selection Priority (real usage)

check the URL exists always.

1. **Seqera Wave** (preferred for common bioinformatics tools):
   `community.wave.seqera.io/library/<tool>:<version>--<hash>`
   Used in: cd45isoform (samtools)

2. **Official nf-core / biocontainers** (well-maintained community images):
   `quay.io/nf-core/bclconvert:4.4.6`
   `quay.io/biocontainers/samtools:1.17--h00cdaf9_0`
   Used in: bclconvert

3. **Minimal base image** (for simple operations like cat, gzip):
   `ubuntu:22.04`
   Used in: fastq-merge

4. **Custom GCP Artifact Registry** (when tool needs custom build):
   `$ARTIFACT_REGISTRY/<repo>/<image>:<version>`
   Claude reads `$ARTIFACT_REGISTRY` and `$GCP_PROJECT` env vars to build the full path.
   Always use `$ARTIFACT_REGISTRY` verbatim — never derive a regional variant like `us-east1-docker.pkg.dev`.
   Used in: arcashla, cd45isoform, cellranger

## Container Specification Patterns

### Per-process in module (preferred for multi-container pipelines)
```groovy
process SAMTOOLS_INDEX {
    container 'community.wave.seqera.io/library/samtools:1.23--12d9384dd0649f36'
    ...
}
```

### Global default via param (for single-container pipelines)
In nextflow.config (Claude fills in registry path from $ARTIFACT_REGISTRY/$GCP_PROJECT):
```groovy
params {
    tool_container = '$ARTIFACT_REGISTRY/<repo>/<image>:<version>'
}
process {
    container = params.tool_container
}
```

## Custom Dockerfile Patterns

### Ubuntu-based (arcashla, cellranger)
```dockerfile
FROM ubuntu:22.04

LABEL maintainer="Ghobrial Lab"
LABEL description="Tool description"
LABEL version="1.0.0"

RUN apt-get update && apt-get install -y \
    python3 python3-pip samtools \
    && apt-get clean

# Tool-specific installation
RUN pip3 install --no-cache-dir tool-package
```

### Conda-based (template default)
```dockerfile
FROM continuumio/miniconda3:latest

RUN conda install -y -c conda-forge -c bioconda \
    tool1=1.0 \
    tool2=2.0 \
    && conda clean -afy
```

If the tool repository has an env file, use that to install dependencies.

### Conda-based with baked-in reference database (arcashla pattern)

Some tools (arcasHLA, STAR, kallisto) require a reference database that must be
downloaded at build time. Key lessons from arcasHLA:

1. **Always install `git`** if the tool fetches reference via `git clone`
2. **Use a pinned version** (`--version X.Y.Z`) instead of `--update` / `--latest` —
   large reference repos (e.g. IMGTHLA) use Git LFS; without `git-lfs`, clone only
   downloads pointer files and the real data is silently missing
3. Find the recommended pinned version in the tool's own test docs or README

```dockerfile
FROM continuumio/miniconda3:latest
LABEL maintainer="Ghobrial Lab"

# git is required if the tool fetches reference via git clone
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl pigz \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN conda install -y -c conda-forge -c bioconda \
        tool-name \
    && conda clean -afy

# Use pinned version to avoid Git LFS pointer issues
RUN tool-name reference --version X.Y.Z
```

### Build flag: always use `--platform linux/amd64`

GCP Batch VMs are x86_64. Always pass `--platform linux/amd64` when building,
especially on Apple Silicon Macs:
```bash
docker build --platform linux/amd64 -t image:tag .
```

## Build and Push Script

Claude fills in PROJECT_ID and REGION defaults from `$GCP_PROJECT` and `$ARTIFACT_REGISTRY` env vars:

```bash
#!/bin/bash
set -e

PROJECT_ID="${1:-$GCP_PROJECT}"
REGION="${2:-$ARTIFACT_REGISTRY}"
REPOSITORY="${3:-<tool>}"   # Repository is named after the tool, not the pipeline
IMAGE_NAME="<tool>"
VERSION="1.0.0"

FULL_IMAGE="${REGION}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${VERSION}"
LATEST_IMAGE="${REGION}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:latest"

docker build -t ${IMAGE_NAME}:${VERSION} -t ${IMAGE_NAME}:latest .
docker tag ${IMAGE_NAME}:${VERSION} ${FULL_IMAGE}
docker tag ${IMAGE_NAME}:latest ${LATEST_IMAGE}
docker push ${FULL_IMAGE}
docker push ${LATEST_IMAGE}
```

## Known Container Images in Use

Registry prefix is `$ARTIFACT_REGISTRY` (already includes project). Never append `/$GCP_PROJECT`.

| Pipeline | Image | Source |
|----------|-------|--------|
| arcashla | `$ARTIFACT_REGISTRY/arcashla/arcashla:0.6.0` | Custom (conda-based, reference v3.24.0 baked in) |
| bclconvert | `quay.io/nf-core/bclconvert:4.4.6` | Official nf-core |
| cd45isoform | `community.wave.seqera.io/library/samtools:1.23--...` | Seqera Wave |
| cd45isoform | `$ARTIFACT_REGISTRY/cd45isoform/cd45isoform:0.1.0` | Custom |
| cellranger | `$ARTIFACT_REGISTRY/cellranger/cellranger:8.0.1` | Custom (ubuntu-based) |
| cellranger | `community.wave.seqera.io/library/souporcell_gxx:...` | Seqera Wave |
| fastq-merge | `ubuntu:22.04` | Docker Hub |
