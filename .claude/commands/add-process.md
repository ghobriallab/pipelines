# Add Process to Pipeline

You are helping the user add a new process/step to their existing Nextflow pipeline.

## Environment Setup

Before doing anything else, read `$PIPELINES_DIR/.env` (default: `$HOME/pipelines/.env`) to load GCP
configuration values (`GCP_PROJECT`, `GCP_REGION`, `GCP_WORK_DIR`, `ARTIFACT_REGISTRY`, `PIPELINES_DIR`).
Use these values when writing container image paths, registry URLs, or GCP config in generated files.

## Before You Begin

1. Confirm you are inside a pipeline directory by checking for `main.nf` and `nextflow.config` in the current working directory.
2. If not in a pipeline directory, tell the user to `cd` into one or use `/setup-pipeline` to create a new pipeline first.
3. Ask the user: **"What process/step do you want to add to this pipeline?"**
   Get a description of:
   - The tool or operation name (e.g., "samtools sort", "fastqc", "star alignment")
   - What input it takes (BAM files, FASTQ files, etc.)
   - What output it produces
   - What container image to use (or if one needs to be built)

## Learning from Existing Pipelines

Before creating the new process, study existing pipelines in `$PIPELINES_DIR` to learn the established patterns:

1. **Read 2-3 existing process modules** to understand conventions. Glob
   `$PIPELINES_DIR/nextflow-*/modules/local/*/main.nf` and pick a representative
   sample (prefer variety: one simple, one with multiple inputs, one with a custom container).

2. **Read the canonical process template** at `$PIPELINES_DIR/.memory/templates.md`

3. **Read the current pipeline's files** to understand the current state:
   - `main.nf` — existing includes, workflow chain, samplesheet structure
   - `conf/modules.config` — existing resource configurations

## Process Module Pattern

Every process module MUST follow this structure (learned from existing pipelines):

### File location

`modules/local/<process_name>/main.nf` — process_name is lowercase with underscores (e.g., `samtools_sort`, `fastqc`, `star_align`).

### Required elements

```groovy
process PROCESS_NAME {
    tag "$sample_id"
    label 'process_medium'                    // process_low, process_medium, or process_high
    publishDir "${params.outdir}/${sample_id}/process_name", mode: params.publish_dir_mode
    container '<container_url>'

    input:
    tuple val(sample_id), path(input_file)

    output:
    tuple val(sample_id), path("*.output"), emit: result
    path "versions.yml", emit: versions       // ALWAYS include versions.yml

    script:
    def args = task.ext.args ?: ''            // Configurable via modules.config
    """
    tool $args --input ${input_file} --output ${sample_id}.output

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tool: \$(tool --version)
    END_VERSIONS
    """

    stub:
    """
    touch ${sample_id}.output
    touch versions.yml
    """
}
```

### Container selection priority

1. **Seqera Wave** (preferred): `community.wave.seqera.io/library/<tool>:<version>`
2. **Existing custom image**: Check if the pipeline already has a Docker image with the tool
3. **New Dockerfile addition**: Add to `docker/Dockerfile` using `conda install -c conda-forge -c bioconda`

## Implementation Steps

For each new process, complete ALL of these steps in order:

### Step 1: Create the process module file

Create `modules/local/<process_name>/main.nf` following the pattern above.

Key decisions to make with the user:
- Process name (UPPERCASE in the process block, lowercase for the directory)
- Input/output tuple structure
- Container image
- Whether `stageInMode 'copy'` is needed (for tools that modify input files in-place)
- Whether `task.ext.args` should be used for configurable arguments

### Step 2: Add the include statement to main.nf

Add an include line in the `INCLUDE MODULES` section of `main.nf`:

```groovy
include { PROCESS_NAME } from './modules/local/process_name/main'
```

### Step 3: Wire the process into the workflow

**If this is the FIRST process** (no existing include statements besides TODO comments):
- Replace the TODO comment block with the process call
- Input comes from `ch_samplesheet`
- Example: `PROCESS_NAME(ch_samplesheet)`

**If processes already exist** (chaining onto existing workflow):
- Find the last process call in the workflow
- Use its output channel as input to the new process
- Example: `NEW_PROCESS(PREVIOUS_PROCESS.out.result)`
- If the new process needs additional inputs (e.g., a reference file), add channel declarations above the process call

### Step 4: Add resource configuration to conf/modules.config

Add a `withName` block inside the existing `process { }` block:

```groovy
    withName: 'PROCESS_NAME' {
        cpus   = { check_max( 4, 'cpus' ) }
        memory = { check_max( 16.GB * task.attempt, 'memory' ) }
        time   = { check_max( 4.h * task.attempt, 'time' ) }
        disk   = '100 GB'
    }
```

Use sensible defaults based on the tool's requirements. If the process needs `ext.args`:

```groovy
        ext.args = [
            params.some_flag ? "--flag value" : ''
        ].join(' ').trim()
```

### Step 5: Update Docker if needed

If a custom container is needed (no Seqera Wave container available):
- Add the tool installation to `docker/Dockerfile` using `conda install -c conda-forge -c bioconda <tool>`
- Remind the user to run `cd docker && ./build_and_push.sh` after editing
- Update the container directive in the process module to point to the Artifact Registry path: `$ARTIFACT_REGISTRY/$GCP_PROJECT/<repo>/<image>:<version>`

### Step 6: Update params if needed

If the new process introduces new parameters (e.g., a reference genome path):
- Add them to the `params { }` block in `nextflow.config`
- Add them to the `log.info` summary in the workflow block
- Document them in `README.md`

### Step 7: Suggest test approach

After creating the process:
- Verify the samplesheet has the right columns for the new process
- Suggest a stub test: `nextflow run main.nf -profile test -stub`
- Then a real test: `nextflow run main.nf -profile test`
- If test data needs updating, suggest what to add to `test_data/`

## After Adding the Process

Ask the user: **"Would you like to add another process/step to the pipeline?"**

If yes, repeat the process above. If no, suggest:
- Running a stub test to verify wiring: `nextflow run main.nf -profile test -stub`
- Reviewing the full workflow by reading `main.nf`
- Committing the changes
