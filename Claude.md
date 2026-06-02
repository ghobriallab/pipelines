# Nextflow Pipeline Development Guide - Ghobrial Lab

**Version**: 3.0.0
**Last Updated**: 2026-04-15
**Target**: Lightweight (2-3 process) pipelines on Google Cloud Platform

---

## Documentation Index

This guide is organized into concept-based modules stored in the [.memory](./.claude/memory/) folder. Reference these files as needed for specific topics.

Search always online nextflow documentation for nextflow 26* to know about the language. DO NOT work with knowledge in your model since it is outdated.

### Getting Started

- **[Overview & Quick Start](./.claude/memory/overview.md)** - Create new pipelines, core principles, and example pipelines
- **[Common Commands](./.claude/memory/commands.md)** - Essential commands for testing, development, and deployment

### Pipeline Structure

- **[Directory Structure](./.claude/memory/structure.md)** - Standard project layout, DSL2 syntax, and required elements
- **[Process Templates](./.claude/memory/templates.md)** - Process templates and samplesheet parsing patterns

### Development

- **[Development Setup](./.claude/memory/development.md)** - VS Code configuration, nf-core modules, and pipeline skeleton
- **[Input Patterns & Branching](./.claude/memory/patterns.md)** - Input handling, branching workflows, and output management
- **[Development Workflow](./.claude/memory/workflow.md)** - Step-by-step development process from design to production

### Testing

- **[Testing Guide](./.claude/memory/testing.md)** - Module tests, full pipeline testing, test data sources, and checklists

### Cloud Deployment

- **[GCP Configuration](./.claude/memory/gcp.md)** - Google Cloud Batch setup, resource configuration, and debugging
- **[Container Strategy](./.claude/memory/containers.md)** - Docker images, custom containers, and build/push workflows

---

## Agent Routing

When the user addresses **Trinity**, you MUST read
[.claude/agents/trinity.md](./.claude/agents/trinity.md) and follow its routing rules
**before taking any action**. The critical rule: always spawn Trinity via
`Agent(subagent_type: "trinity", ...)` — never handle pipeline creation inline.

### HARD RULES — do not break these even if a skill or tool appears available:

- **NEVER invoke the `docker-resolve` skill yourself** when handling a Trinity request.
  Even though the skill appears in your available skills list, it is Trinity's internal
  tool. Running it before spawning Trinity will cause Trinity to skip `get-test-data`,
  `run-local`, and `run-gcp` — breaking the entire pipeline.
- **Spawn Trinity exactly once** with the raw user message. Trinity handles all phases
  (skeleton → docker-resolve → get-test-data → run-local → run-gcp) internally.
- **Do not split Trinity across multiple `Agent(...)` calls.** One spawn = full end-to-end run.

Exceptions: you CAN and SHOULD use subagents and skills to build pipelines that are not directed by Trinity agent. If you are asked to build a pipeline without calling Trinity, then you can read Trinity agent to know best practices and use skills and subagents as needed.

---

## Launching Pipelines via Seqera Platform API

Use the REST API to submit pipeline runs programmatically to a specific workspace.

### Authentication

Generate a token at https://cloud.seqera.io/tokens and export it:

```bash
export SEQERA_TOKEN="your-access-token"
```

### Ghobrial Lab Workspace IDs

| Workspace | ID |
|---|---|
| Ghobrial-Production | `280069337967528` |
| singlecellRNA | `256692647471035` |

### Launch a Pipeline Run

```bash
export WORKSPACE_ID=280069337967528

curl -X POST "https://api.cloud.seqera.io/workflow/launch?workspaceId=${WORKSPACE_ID}" \
  -H "Authorization: Bearer ${SEQERA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "launch": {
      "computeEnvId": "<compute-env-id>",
      "pipeline": "https://github.com/ghobriallab/nextflow-genotyping",
      "revision": "main",
      "workDir": "gs://ghobrial-pipelines/scratch",
      "paramsText": "{\"samplesheet\": \"gs://my-bucket/samplesheet.csv\", \"outdir\": \"gs://my-bucket/results\", \"ref_fa\": \"gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta\"}"
    }
  }'
```

On success, the response contains `{"workflowId": "<id>"}`. Monitor at:
`https://cloud.seqera.io/orgs/GHOBRIAL-DFCI/workspaces/Ghobrial-Production/watch/<id>/v2/logs`

### Key `launch` Fields

| Field | Required | Description |
|---|---|---|
| `computeEnvId` | yes | Compute environment ID (see below) |
| `pipeline` | yes | GitHub URL of the pipeline |
| `workDir` | yes | GCS scratch path for Nextflow work dir |
| `revision` | no | Git branch, tag, or commit SHA |
| `paramsText` | no | JSON string of pipeline parameters |
| `configText` | no | Extra Nextflow config text |
| `resume` | no | `true` to resume from cached work |

### Look Up Compute Environment IDs

```bash
curl -s -H "Authorization: Bearer $SEQERA_TOKEN" \
  "https://api.cloud.seqera.io/compute-envs?workspaceId=${WORKSPACE_ID}" \
  | jq '.computeEnvs[] | {id, name, status}'
```

### Launch from a Saved Launchpad Pipeline (two-step)

If the pipeline is already on the Launchpad, fetch its pre-filled config first:

```bash
# Step 1 — get launch config (note the launchId in the response)
curl -s -H "Authorization: Bearer $SEQERA_TOKEN" \
  "https://api.cloud.seqera.io/pipelines/<pipelineId>/launch?workspaceId=${WORKSPACE_ID}"

# Step 2 — submit with optional overrides
curl -X POST "https://api.cloud.seqera.io/workflow/launch?workspaceId=${WORKSPACE_ID}" \
  -H "Authorization: Bearer ${SEQERA_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"launch": {"id": "<launchId>", "paramsText": "{\"samplesheet\": \"gs://...\"}"}}'
```

---


**For questions or updates**, contact the Ghobrial Lab bioinformatics team.
