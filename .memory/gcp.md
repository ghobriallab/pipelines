# GCP Configuration

## Environment Variables (Claude reads these when generating configs)

When generating or updating pipeline configs, Claude reads these shell env vars
to fill in the correct values instead of hardcoding them:

| Env Var            | Purpose                          | Example                        |
|--------------------|----------------------------------|--------------------------------|
| `GCP_PROJECT`      | GCP project ID                   | `my-project`                   |
| `GCP_REGION`       | GCP region                       | `us-east1`                     |
| `GCP_WORK_DIR`     | Nextflow work dir (GCS bucket)   | `gs://my-bucket/scratch`       |
| `ARTIFACT_REGISTRY`| Docker registry host             | `us-docker.pkg.dev`            |
| `PIPELINES_DIR`    | Local pipelines root dir         | `/home/user/pipelines`         |

Set these in your shell profile (`~/.bashrc` or `~/.zshrc`).

## Core GCP Profile (consistent across all pipelines)

Values below are placeholders — Claude substitutes from env vars when creating files:

```groovy
profiles {
    gcp {
        workDir = 'GCP_WORK_DIR_VALUE'

        process {
            executor = 'google-batch'
            disk = '100 GB'                       // Default; override per-process in modules.config
        }

        google {
            project = 'GCP_PROJECT_VALUE'
            location = 'GCP_REGION_VALUE'
            batch {
                spot = true                       // 60-91% cost savings
                maxSpotAttempts = 5
                bootDiskSize = '50 GB'
            }
        }

        docker {
            enabled = true
        }
    }
}
```

### Variation: spot=false (bclconvert)
BCLConvert sets `batch.spot = false` because conversion jobs are long-running and should not be preempted.

## Error Strategy (varies across pipelines)

### With spot instance codes (most pipelines)
```groovy
errorStrategy = { task.exitStatus in [143,137,104,134,139,14,125,50001,50005] ? 'retry' : 'ignore' }
maxRetries = 2
```
- 125 and 50001 are spot preemption codes
- 14 is also a spot/resource code

### Without spot codes (older pipelines)
```groovy
errorStrategy = { task.exitStatus in [143,137,104,134,139] ? 'retry' : 'finish' }
```

### Error strategy values observed
- `'ignore'` - cd45isoform template, cellranger (skip failures, continue pipeline)
- `'finish'` - arcashla, bclconvert (finish running tasks, then stop)

## Resource Configuration (conf/modules.config)

Always define per-process resources:
```groovy
process {
    withName: 'PROCESS_NAME' {
        cpus   = { check_max( 4, 'cpus' ) }
        memory = { check_max( 16.GB * task.attempt, 'memory' ) }
        time   = { check_max( 4.h * task.attempt, 'time' ) }
        disk   = '100 GB'
    }
}
```

### Resource label system (cellranger)
Define labels in nextflow.config for reuse:
```groovy
process {
    withLabel: process_low {
        cpus = { check_max( 2, 'cpus' ) }
        memory = { check_max( 8.GB * task.attempt, 'memory' ) }
        time = { check_max( 4.h * task.attempt, 'time' ) }
    }
    withLabel: process_medium {
        cpus = { check_max( 6, 'cpus' ) }
        memory = { check_max( 32.GB * task.attempt, 'memory' ) }
        time = { check_max( 8.h * task.attempt, 'time' ) }
    }
    withLabel: process_high {
        cpus = { check_max( 12, 'cpus' ) }
        memory = { check_max( 64.GB * task.attempt, 'memory' ) }
        time = { check_max( 16.h * task.attempt, 'time' ) }
    }
}
```

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
