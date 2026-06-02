# GCP Configuration

## Environment Variables (Claude reads these when generating configs)

Claude reads shell env vars to fill config values instead of hardcoding:

| Env Var            | Purpose                          | Example                        |
|--------------------|----------------------------------|--------------------------------|
| `GCP_PROJECT`      | GCP project ID                   | `my-project`                   |
| `GCP_REGION`       | GCP region                       | `us-east1`                     |
| `GCP_WORK_DIR`     | Nextflow work dir (GCS bucket)   | `gs://my-bucket/scratch`       |
| `ARTIFACT_REGISTRY`| Docker registry host             | `us-docker.pkg.dev`            |
| `PIPELINES_DIR`    | Local pipelines root dir         | `/home/user/pipelines`         |

Set in shell profile (`~/.bashrc` or `~/.zshrc`).

## Core GCP Profile (non-bulk RNAseq default)

Use this for all pipelines except bulk RNAseq (single-cell, ATAC, WGS, CellRanger, VDJ, etc.).
`stageInMode/stageOutMode = 'copy'` + attached `pd-balanced` disk avoids FUSE failures with large files.

Placeholders below — Claude substitutes from env vars when creating files:

```groovy
profiles {
    gcp {
        workDir = 'GCP_WORK_DIR_VALUE'

        process {
            executor      = 'google-batch'
            disk          = [request: 1500.GB, type: 'pd-balanced']
            stageInMode   = 'copy'
            stageOutMode  = 'copy'
            machineType   = 'n2-*,c2-*,m3-*'
        }

        google {
            project                 = 'GCP_PROJECT_VALUE'
            location                = 'GCP_REGION_VALUE'
            batch.spot              = params.use_spot
            batch.bootDiskSize      = 50.GB
            batch.installGpuDrivers = params.use_gpu
        }
    }
}
```

**Disk syntax note:** in `nextflow.config` always use the map form `disk = [request: X.GB, type: 'pd-balanced']` (with `=`). The `disk X.GB, type: '...'` form (no `=`) is only valid inside `.nf` process definitions.

### Params to add alongside the GCP profile
```groovy
use_spot = false   // set true for spot/preemptible instances
use_gpu  = false   // set true to install GPU drivers (e.g. CellBender)
```

### Variation: spot=false (bclconvert)
BCLConvert sets `batch.spot = false` — conversion jobs are long-running and must not be preempted.

### Variation: bulk RNAseq (small files)
Small-file pipelines may omit `stageInMode/stageOutMode` and use a smaller disk.

## Error Strategy

### Standard (most pipelines)
```groovy
errorStrategy = { task.exitStatus in [1,127] ? 'finish' : task.exitStatus in [143,137,104,134,139,14,125,50001,5005] ? 'retry' : 'ignore' }
maxRetries = 5
```
- Exit codes 1, 127: hard failures → terminate immediately
- 125, 50001: spot preemption; 14, 5005: spot/resource codes → retry
- Everything else: `'ignore'` (skip and continue)

## Resource Configuration (conf/modules.config)

Always define per-process resources:
```groovy
process {
    withName: 'PROCESS_NAME' {
        cpus   = 4
        memory = { 16.GB * task.attempt }
        time   = { 4.h * task.attempt }
    }
}
```

Do NOT use generic `withLabel: process_low/medium/high` blocks. Resources are always defined per-process by name in `conf/modules.config`.

## Debugging GCP

```bash
# List jobs (use $GCP_PROJECT env var)
gcloud batch jobs list --project=$GCP_PROJECT

# View logs
gcloud logging read "resource.type=batch_job" --limit 50

# Check work directory (use $GCP_WORK_DIR env var)
gsutil ls -lh $GCP_WORK_DIR/

# Local debugging (check work directory)
cd work/ab/cd1234567890...
cat .command.log .command.err .exitcode
```