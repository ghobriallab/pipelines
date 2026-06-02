# Directory Structure

## Standard Pipeline Layout

```
nextflow-<pipeline>/
├── main.nf                          # Workflow entry point (includes + workflow block)
├── nextflow.config                  # Configuration, profiles, check_max(), manifest
├── pixi.toml                        # Dev tools only (nextflow). NOT pipeline deps
├── conf/
│   └── modules.config              # Per-process resources (withName blocks)
├── modules/
│   └── local/
│       ├── process_one/
│       │   └── main.nf             # Process definition
│       └── process_two/
│           └── main.nf             # Process definition
├── docker/                          # Only if custom container needed
│   ├── Dockerfile
│   ├── build_and_push.sh
│   └── README.md                    # Optional build instructions
├── reference/                       # Only if pipeline bundles reference files
│   └── *.txt
├── test_data/
│   ├── samplesheet_test.csv
│   └── <test input files>
├── README.md
├── CHANGELOG.md
└── .gitignore
```

## Key Conventions

- `nextflow.enable.dsl = 2` at top of main.nf
- Named outputs with `emit: output_name`
- Include statements: `include { PROCESS_NAME } from './modules/local/process_name/main'`
- Process names: UPPERCASE (e.g., `CELLRANGER_COUNT`)
- Directory names: lowercase with underscores (e.g., `cellranger_count/`)
- versions.yml in main bioinformatics processes (skip for utility processes)
- Docker container support always required
- Stub implementations for testing workflow structure

## What Goes Where

| Component | Location | Notes |
|-----------|----------|-------|
| Pipeline params | `nextflow.config` params block | Including container URLs |
| Per-process resources | `conf/modules.config` | cpus, memory, time, disk, ext.args |
| Per-process resources | `conf/modules.config` only | Always `withName`, never generic `withLabel` |
| Process logic | `modules/local/<name>/main.nf` | One process per file |
| Workflow wiring | `main.nf` | Channel ops + process calls |
| Container images | `docker/Dockerfile` + `docker/build_and_push.sh` | Custom builds only |
| Reference data | `reference/` | Small refs bundled here |

## pixi.toml Pattern

```toml
[workspace]
channels = ["conda-forge", "bioconda"]
name = "nextflow-<pipeline>"
platforms = ["linux-64"]

[dependencies]
nextflow = ">=25.10.2,<26"
```

- **Dev tools only** in pixi.toml (nextflow, nf-test)
- Pipeline tools → Docker containers
- Platform: `linux-64` (some add `osx-64`, `osx-arm64`)

## Versioning
- Semantic versioning (MAJOR.MINOR.PATCH)
- Min Nextflow `>=23.04.0`
- Use `publishDir` with configurable mode (`params.publish_dir_mode`)