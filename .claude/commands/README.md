# Claude Subcommands

This directory contains Claude Code commands for pipeline development workflows.

## Available Commands

### `/build-pipeline` ← start here for new pipelines

Orchestrates the full pipeline lifecycle: skeleton → Docker → test data → local run → GCP run.

**Usage:**
```
/build-pipeline <pipeline-name>
```

**What it does:**
1. Runs `/setup-pipeline` to create the skeleton (or skips if it already exists)
2. Asks 5 questions about the pipeline's purpose, tools, input data, and container strategy
3. Spawns two agents **in parallel**:
   - `docker-build` — resolves the container (public image or custom build + push)
   - `get-test-data` — generates realistic minimal test data matched to the pipeline
4. Runs `run-local` — stub test + full local test with auto-fix for common errors
5. Runs `run-gcp` — verifies GCP setup, submits to Google Batch, monitors job
6. Prints a final summary table with pass/fail for each stage

**Example:**
```
/build-pipeline rnaseq
```

**Agents used** (in `.claude/agents/`):
- `docker-build.md` — container specialist
- `get-test-data.md` — test data specialist
- `run-local.md` — local execution specialist
- `run-gcp.md` — GCP execution specialist

---

### `/setup-pipeline`

Creates a new Nextflow pipeline skeleton with a fully configured development environment.

**Usage:**
```
/setup-pipeline <pipeline-name>
```

**What it does:**
1. Creates the complete pipeline skeleton at `$PIPELINES_DIR/nextflow-<name>/`
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
# Creates $PIPELINES_DIR/nextflow-rnaseq
/setup-pipeline rnaseq
```

---

### `/add-process`

Interactive agent that helps you add process steps to an existing pipeline, one at a time.

**Usage:**
```
# First, cd into your pipeline directory
cd $PIPELINES_DIR/nextflow-<name>

# Then invoke the command
/add-process
```

**What it does:**
1. Asks what process/step you want to add
2. Studies existing pipelines in `$PIPELINES_DIR/` to learn conventions
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

## Agents (`.claude/agents/`)

Agents are prompt files spawned by the orchestrator — they are NOT slash commands
and cannot be invoked directly by the user. Each agent receives pipeline context
from the orchestrator in its task prompt.

| Agent | Purpose |
|-------|---------|
| `docker-build.md` | Verifies or builds container images; pushes to Artifact Registry |
| `get-test-data.md` | Creates minimal valid test data matched to the pipeline's input types |
| `run-local.md` | Runs the pipeline locally; auto-fixes common config/container errors |
| `run-gcp.md` | Verifies GCP environment; runs on Google Batch; monitors and diagnoses |

---

## Creating New Subcommands

To add a new subcommand:

1. Create a file in this directory (`.md` extension)
2. For bash scripts: include `#!/bin/bash` shebang
3. For agent prompts: write markdown instructions (no shebang)
4. Document it in this README
