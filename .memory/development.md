# Development Setup

## VS Code Setup with Nextflow LSP

**Install Nextflow Language Server Extension**:
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search "Nextflow" by nextflow-io
4. Install official **Nextflow** extension

**Extension settings** (`.vscode/settings.json`):
```json
{
    "nextflow.enable": true,
    "nextflow.formatting.harshilAlignment": true,
    "nextflow.linting.enabled": true,
    "files.associations": {
        "*.nf": "nextflow",
        "nextflow.config": "nextflow"
    }
}
```

## Pipeline Skeleton

Use `/setup-pipeline <name>` to create pipeline at `$PIPELINES_DIR/nextflow-<name>/`.

Skeleton includes:
- `main.nf` - Workflow reads samplesheet (no processes yet)
- `nextflow.config` - Local, GCP, test profiles with check_max()
- `conf/modules.config` - Empty process resource config
- `modules/local/` - Process modules dir
- `docker/Dockerfile` and `docker/build_and_push.sh`
- `pixi.toml` - Dev dependencies (nextflow only)
- `test_data/` - Example samplesheet + test files
- `README.md`, `CHANGELOG.md`, `.gitignore`

## Using nf-core Modules

```bash
pixi run nf-core modules list remote
pixi run nf-core modules install samtools/sort
```

```groovy
include { SAMTOOLS_SORT } from './modules/nf-core/samtools/sort/main'
```