# Common Commands

You may need to run `pixi run` before the commands below if the user is using pixi for development tools.

```bash
# Pipeline creation
/setup-pipeline <name>            # Create new pipeline skeleton
/add-process                      # Add a process interactively (from inside pipeline dir)

# Testing
nextflow run main.nf -profile test -stub    # Stub test (no real data)
nextflow run main.nf -profile test          # Test with test data
nf-test test                                # Run nf-test module tests

# Development
nf-core modules list remote                 # Browse nf-core modules
nf-core modules install <name>              # Install nf-core module
nextflow config -validate                   # Validate config

# Docker
cd docker && ./build_and_push.sh            # Build and push container

# GCP execution
nextflow run main.nf -profile gcp \
    --samplesheet gs://bucket/samples.csv \
    --outdir gs://bucket/results

# GCP monitoring
gcloud batch jobs list --project=ghobrial-pipelines
gcloud logging read "resource.type=batch_job" --limit 50
```
