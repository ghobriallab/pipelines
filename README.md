# Pipelines

Nextflow pipelines for the Ghobrial Lab, designed for Google Cloud Batch.

## Quick Start

### 1. Configure environment

Copy `.env.example` to `.env` and fill in your values:

```bash
cp .env.example .env
# edit .env with your GCP project, bucket, and registry
```

Then source it (or add to `~/.bashrc`):

```bash
source .env
```

### 2. Create a new pipeline

```
/setup-pipeline <name>
```

Creates `nextflow-<name>/` with full skeleton, installs dev deps, and inits git.

### 3. Add processes to a pipeline

```bash
cd nextflow-<name>
/add-process
```

Interactive — describe the tool, Claude wires it in.

### 4. Run locally

```bash
cd nextflow-<name>
nextflow run main.nf -profile local --samplesheet test_data/samplesheet_test.csv
```

### 5. Run on GCP

```bash
nextflow run main.nf -profile gcp \
  --samplesheet gs://your-bucket/samples.csv \
  --outdir gs://your-bucket/results
```

---

## Repository Layout

```
pipelines/
├── .env                    # Your local config (never committed)
├── .env.example            # Template — copy this to .env
├── .claude/
│   └── commands/
│       ├── setup-pipeline.md   # /setup-pipeline command
│       ├── add-process.md      # /add-process command
│       └── README.md           # Command docs
├── .memory/                # Claude's reference docs (conventions, templates, GCP config)
├── Claude.md               # Claude instructions index
├── nextflow-pipeline1
├── nextflow-pipeline2
```

## Pipelines

## Environment Variables

| Variable | Purpose |
|---|---|
| `GCP_PROJECT` | GCP project ID |
| `GCP_REGION` | GCP region (default: `us-east1`) |
| `GCP_WORK_DIR` | Nextflow scratch dir (`gs://bucket/scratch`) |
| `ARTIFACT_REGISTRY` | Docker registry host (`us-docker.pkg.dev`) |
| `PIPELINES_DIR` | Local root of this repo (default: `$HOME/pipelines`) |

## Reference

- [Claude commands](.claude/commands/README.md) — `/setup-pipeline`, `/add-process`
- [Claude.md](Claude.md) — full development guide index
- [.memory/gcp.md](.memory/gcp.md) — GCP profiles and resource config
- [.memory/containers.md](.memory/containers.md) — container selection and build scripts
