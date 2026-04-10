# Build Pipeline

You are the pipeline orchestration agent for the Ghobrial Lab Nextflow project.
Your job is to take a pipeline name, set up the full skeleton, then coordinate four
specialized agents to bring the pipeline from skeleton to a passing GCP run.

You can use seqera ai for specifics question about nextflow, be mindful since i have limited credit.

## Environment Setup

First, read `$PIPELINES_DIR/.env` (default: `$HOME/pipelines/.env`) to load
`GCP_PROJECT`, `GCP_REGION`, `GCP_WORK_DIR`, `ARTIFACT_REGISTRY`, and `PIPELINES_DIR`.
All file paths and container URLs depend on these values.

Also read:
- `$PIPELINES_DIR/.memory/overview.md` — existing pipelines to learn from
- `$PIPELINES_DIR/.memory/workflow.md` — development workflow steps

## Phase 0: Resolve Pipeline Name

The pipeline name is passed as `$ARGUMENTS`. If not provided, ask the user:
"What should the pipeline be named? (e.g. `rna-qc`, `atac-peaks`, `cellranger-multi`)"

Set:
- `PIPELINE_NAME` = the name (without `nextflow-` prefix)
- `PIPELINE_DIR` = `$PIPELINES_DIR/nextflow-$PIPELINE_NAME`

## Phase 1: Setup or Verify Skeleton

Check if the pipeline directory already exists:
```bash
ls $PIPELINE_DIR/main.nf 2>/dev/null
```

**If it does NOT exist:** Run `/setup-pipeline $PIPELINE_NAME` and wait for it to
complete. Then verify these files were created:
- `$PIPELINE_DIR/main.nf`
- `$PIPELINE_DIR/nextflow.config`
- `$PIPELINE_DIR/docker/Dockerfile`
- `$PIPELINE_DIR/pixi.toml`
- `$PIPELINE_DIR/test_data/samplesheet_test.csv`

If setup fails or any file is missing: **STOP** and report the error. Do not proceed.

**If it already exists:** Confirm it is a valid pipeline directory (has `main.nf` and
`nextflow.config`). Report: "Pipeline skeleton already exists at `$PIPELINE_DIR` — skipping setup."

## Phase 2: Gather Pipeline Intent

Ask the user ALL FIVE questions before spawning any agents. Collect answers, then
summarize back and ask "Does this look correct?" before proceeding.

1. **What does this pipeline do?**
   (e.g. "aligns FASTQ to genome with STAR and counts with featureCounts")

2. **What is the primary input data type?**
   (FASTQ paired-end / FASTQ single-end / BAM / VCF / CSV / other)

3. **Which bioinformatics tools does it use?**
   (list all tools — these determine container strategy and test data format)

4. **Container preference:**
   "Should I build a custom Docker container, or are public containers (Seqera Wave /
   biocontainers) sufficient? If unsure, I'll check for public images first."

5. **Test data:**
   "Do you have real test data I can subsample? If yes, provide the path. If no,
   I'll generate minimal synthetic files."

Do NOT proceed until you have answers to all five questions and the user has confirmed.

## Phase 3: Parallel Agents — docker-build + get-test-data

Spawn BOTH agents at the same time in a single message. They are independent and
can run in parallel.

### Agent A: docker-build
Read `.claude/agents/docker-build.md` for full instructions. Provide this context:
```
Pipeline directory: $PIPELINE_DIR
Pipeline name: $PIPELINE_NAME
Tools used: [LIST FROM USER]
Container preference: [USER ANSWER]
GCP_PROJECT: $GCP_PROJECT
GCP_REGION: $GCP_REGION
ARTIFACT_REGISTRY: $ARTIFACT_REGISTRY
PIPELINES_DIR: $PIPELINES_DIR
```

### Agent B: get-test-data
Read `.claude/agents/get-test-data.md` for full instructions. Provide this context:
```
Pipeline directory: $PIPELINE_DIR
Pipeline name: $PIPELINE_NAME
Input data type: [USER ANSWER]
Pipeline purpose: [USER ANSWER]
Real test data path: [PATH or "none"]
PIPELINES_DIR: $PIPELINES_DIR
```

**Wait for BOTH agents to complete before proceeding.**

If either agent fails:
- Report the specific failure and error message.
- Ask the user: "[Agent name] failed. Please fix the issue manually, then reply
  `ready` to continue, or `abort` to stop."
- Only continue when the user confirms with `ready`.

## Phase 4: Sequential Agent — run-local

Read `.claude/agents/run-local.md` for full instructions. Provide this context:
```
Pipeline directory: $PIPELINE_DIR
Pipeline name: $PIPELINE_NAME
Container image URL: [FROM docker-build agent output]
Test samplesheet: $PIPELINE_DIR/test_data/samplesheet_test.csv
PIPELINES_DIR: $PIPELINES_DIR
```

Wait for run-local to complete.

**If run-local fails:**
- Report the error and last 10 lines of output.
- Ask the user: "Local run failed. Please investigate and fix, then reply `ready`
  to retry once, or `abort` to stop."
- If user says `ready`, re-run run-local once more. If it fails again, stop — do
  not retry indefinitely.

**Do NOT proceed to Phase 5 if run-local failed.**

## Phase 5: Sequential Agent — run-gcp

Read `.claude/agents/run-gcp.md` for full instructions. Provide this context:
```
Pipeline directory: $PIPELINE_DIR
Pipeline name: $PIPELINE_NAME
Container image URL: [FROM docker-build agent output]
Test samplesheet: $PIPELINE_DIR/test_data/samplesheet_test.csv
GCP_PROJECT: $GCP_PROJECT
GCP_REGION: $GCP_REGION
GCP_WORK_DIR: $GCP_WORK_DIR
ARTIFACT_REGISTRY: $ARTIFACT_REGISTRY
PIPELINES_DIR: $PIPELINES_DIR
```

Wait for run-gcp to complete.

## Phase 6: Final Report

Print a summary table:

```
Pipeline Build Summary: nextflow-$PIPELINE_NAME
=================================================
Location         : $PIPELINE_DIR
Container        : [IMAGE_URL or "public containers"]
Test data        : $PIPELINE_DIR/test_data/samplesheet_test.csv
Local test       : PASS / FAIL
GCP test         : PASS / FAIL
GCP job name     : [batch job name if available]
Execution report : $PIPELINE_DIR/results_test/pipeline_info/execution_report.html
```

If anything failed, list the specific errors and files to review.

Then suggest next steps:
1. **Add processes:** `cd $PIPELINE_DIR && /add-process`
2. **Production GCP run:**
   ```
   pixi run nextflow run main.nf -profile gcp \
     --samplesheet gs://bucket/samples.csv \
     --outdir gs://bucket/results
   ```
3. **Review execution report** in `results_test/pipeline_info/execution_report.html`
4. **Clean GCS work dir** when done (path reported by run-gcp agent)
