# Claude Subcommands

This directory contains Claude Code commands for pipeline development workflows.

## Available Commands

### `/setup-pipeline`

Creates a new Nextflow pipeline skeleton with a fully configured development environment.

**Usage:**
```
/setup-pipeline <pipeline-name>
```

**What it does:**
1. Creates the complete pipeline skeleton at `/home/lpantano/pipelines/nextflow-<name>/`
2. Generates all scaffolding files:
   - `main.nf` - Workflow entry point with samplesheet parsing (no processes yet)
   - `nextflow.config` - Configuration with local, gcp, and test profiles
   - `conf/modules.config` - Empty process resource configuration
   - `docker/Dockerfile` and `docker/build_and_push.sh` - Container build setup
   - `pixi.toml` - Development dependency management (nextflow, nf-test)
   - `test_data/` - Sample test samplesheet and input files
   - `README.md`, `CHANGELOG.md`, `.gitignore`
3. Installs pixi (if not already installed)
4. Runs `pixi install` to set up development dependencies
5. Initializes a git repository with an initial commit

**Example:**
```
# Creates /home/lpantano/pipelines/nextflow-rnaseq
/setup-pipeline rnaseq
```

---

### `/add-process`

Interactive agent that helps you add process steps to an existing pipeline, one at a time.

**Usage:**
```
# First, cd into your pipeline directory
cd /home/lpantano/pipelines/nextflow-<name>

# Then invoke the command
/add-process
```

**What it does:**
1. Asks what process/step you want to add
2. Studies existing pipelines in `/home/lpantano/pipelines/` to learn conventions
3. For each new step, creates/modifies:
   - Process module file at `modules/local/<process_name>/main.nf`
   - Include statement in `main.nf`
   - Workflow wiring in `main.nf` (chains onto existing processes)
   - Resource configuration in `conf/modules.config`
   - Docker updates if a custom container is needed
   - Parameter additions to `nextflow.config` if needed
4. Suggests test approach after each step
5. Offers to add another step or finalize

**Typical workflow:**
```
/setup-pipeline my-tool        # Create skeleton
cd nextflow-my-tool
/add-process                   # Add first process (e.g., "samtools sort")
/add-process                   # Add second process (e.g., "custom analysis")
```

## Creating New Subcommands

To add a new subcommand:

1. Create a file in this directory (`.md` extension)
2. For bash scripts: include `#!/bin/bash` shebang
3. For agent prompts: write markdown instructions (no shebang)
4. Document it in this README
