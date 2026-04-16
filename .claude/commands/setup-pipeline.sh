#!/bin/bash
set -e

# Claude subcommand: setup-pipeline
# Creates a new Nextflow pipeline skeleton and sets up the development environment
# Usage: /setup-pipeline <pipeline-name>

PIPELINE_NAME="${1:-my-pipeline}"

# Load environment variables from .env if present
PIPELINES_DIR="${PIPELINES_DIR:-$HOME/pipelines}"
ENV_FILE="$PIPELINES_DIR/.env"
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

GCP_PROJECT="${GCP_PROJECT:?Error: GCP_PROJECT env var is not set (set in $ENV_FILE or shell)}"
GCP_REGION="${GCP_REGION:-us-east1}"
GCP_WORK_DIR="${GCP_WORK_DIR:?Error: GCP_WORK_DIR env var is not set}"
ARTIFACT_REGISTRY="${ARTIFACT_REGISTRY:-us-docker.pkg.dev}"
PIPELINE_DIR="$PIPELINES_DIR/nextflow-$PIPELINE_NAME"

# Check if pixi is installed
if ! command -v pixi &> /dev/null; then
    echo "pixi is not installed. Installing pixi..."
    curl -fsSL https://pixi.sh/install.sh | bash
    export PATH="$HOME/.pixi/bin:$PATH"
    echo "pixi installed"
fi

# Check if pipeline directory already exists
if [ -d "$PIPELINE_DIR" ]; then
    echo "Pipeline directory already exists: $PIPELINE_DIR"
    echo "Please choose a different name or remove the existing directory."
    exit 1
fi

echo "========================================="
echo "Setting up pipeline: nextflow-$PIPELINE_NAME"
echo "Location: $PIPELINE_DIR"
echo "========================================="
echo ""

# Step 1: Create pipeline skeleton
echo "Creating pipeline skeleton..."

# Create directory structure
mkdir -p "$PIPELINE_DIR"/{conf,modules/local,test_data,docker}
cd "$PIPELINE_DIR"

# Create main.nf
cat > main.nf <<'EOF'
#!/usr/bin/env nextflow

/*
========================================================================================
    PIPELINE_NAME
========================================================================================
    Brief description of what this pipeline does

    Author: Your Name
    Version: 0.1.0
========================================================================================
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    INCLUDE MODULES
========================================================================================
*/

// TODO: Add module includes here
// include { PROCESS_NAME } from './modules/local/process_name/main'

/*
========================================================================================
    MAIN WORKFLOW
========================================================================================
*/

workflow {
    log.info """
    ========================================
    PIPELINE_NAME
    ========================================
    Sample Sheet       : ${params.samplesheet}
    Output Directory   : ${params.outdir}
    ========================================
    """

    // Parse input samplesheet
    // Expected columns: sample_id, input_file
    ch_samplesheet = Channel.fromPath(params.samplesheet, checkIfExists: true)
        .splitCsv(header: true, sep: ',')
        .map { row ->
            if (!row.sample_id) error "Missing sample_id in samplesheet"
            if (!row.input_file) error "Missing input_file for ${row.sample_id}"

            def sample_id = row.sample_id
            def input_file = file(row.input_file, checkIfExists: true)
            return tuple(sample_id, input_file)
        }

    // Display what we found
    ch_samplesheet.view { sample_id, input_file ->
        "Sample: $sample_id -> $input_file"
    }

    // TODO: Add your processes here
    // Example:
    // PROCESS_ONE(ch_samplesheet)
}

/*
========================================================================================
    COMPLETION SUMMARY
========================================================================================
*/

workflow.onComplete {
    log.info """
    ========================================
    Pipeline completed!
    ========================================
    Status      : ${workflow.success ? 'SUCCESS' : 'FAILED'}
    Work Dir    : ${workflow.workDir}
    Results Dir : ${params.outdir}
    Duration    : ${workflow.duration}
    ========================================
    """.stripIndent()
}

workflow.onError {
    log.error """
    ========================================
    Pipeline execution stopped with error
    ========================================
    Error Message: ${workflow.errorMessage}
    ========================================
    """.stripIndent()
}
EOF

# Create nextflow.config
cat > nextflow.config <<'EOF'
// Global default params
params {
    // Input/Output options
    outdir                  = './results'
    samplesheet             = null

    // Publishing options
    publish_dir_mode        = 'copy'

    // Max resource options
    max_memory              = '64.GB'
    max_cpus                = 16
    max_time                = '48.h'
}

// Load module configurations
includeConfig 'conf/modules.config'

// Process settings
process {
    // Error strategy: retry on transient cloud/spot errors, ignore others
    errorStrategy = { task.exitStatus in [143,137,104,134,139,14,125,50001] ? 'retry' : 'ignore' }
    maxRetries = 2
}

// Execution profiles
profiles {
    local {
        params.config_profile_name = 'Local'
        params.config_profile_description = 'Local execution profile for testing'

        docker {
            enabled = true
            runOptions = '-u $(id -u):$(id -g)'
        }

        process {
            executor = 'local'
            cpus   = { check_max( 4, 'cpus' ) }
            memory = { check_max( 16.GB * task.attempt, 'memory' ) }
            time   = { check_max( 8.h * task.attempt, 'time' ) }
        }
    }

    gcp {
        params.config_profile_name = 'Google Cloud'
        params.config_profile_description = 'Google Cloud Platform execution profile'

        workDir = 'GCP_WORK_DIR_PLACEHOLDER'

        process {
            executor = 'google-batch'
            disk = '200 GB'
        }

        google {
            project = 'GCP_PROJECT_PLACEHOLDER'
            location = 'GCP_REGION_PLACEHOLDER'
            batch {
                spot = true
                maxSpotAttempts = 5
                bootDiskSize = '50 GB'
            }
        }

        docker {
            enabled = true
        }
    }

    test {
        params.config_profile_name = 'Test'
        params.config_profile_description = 'Minimal test profile'

        params.samplesheet = "${projectDir}/test_data/samplesheet_test.csv"
        params.outdir      = "${projectDir}/results_test"
        params.max_memory   = '8.GB'
        params.max_cpus     = 4
        params.max_time     = '2.h'

        docker {
            enabled = true
        }

        process {
            cpus   = 4
            memory = 8.GB
            time   = 2.h
        }
    }
}

// Function to ensure resource requirements don't exceed limits
def check_max(obj, type) {
    if (type == 'memory') {
        try {
            if (obj.compareTo(params.max_memory as nextflow.util.MemoryUnit) == 1)
                return params.max_memory as nextflow.util.MemoryUnit
            else
                return obj
        } catch (all) {
            println "   ### ERROR ###   Max memory '${params.max_memory}' is not valid! Using default value: $obj"
            return obj
        }
    } else if (type == 'time') {
        try {
            if (obj.compareTo(params.max_time as nextflow.util.Duration) == 1)
                return params.max_time as nextflow.util.Duration
            else
                return obj
        } catch (all) {
            println "   ### ERROR ###   Max time '${params.max_time}' is not valid! Using default value: $obj"
            return obj
        }
    } else if (type == 'cpus') {
        try {
            return Math.min( obj, params.max_cpus as int )
        } catch (all) {
            println "   ### ERROR ###   Max cpus '${params.max_cpus}' is not valid! Using default value: $obj"
            return obj
        }
    }
}

// Manifest
manifest {
    name            = 'PIPELINE_NAME'
    author          = 'Ghobrial Lab'
    homePage        = 'https://github.com/ghobriallab/PIPELINE_NAME'
    description     = 'Brief description of pipeline'
    mainScript      = 'main.nf'
    nextflowVersion = '>=23.04.0'
    version         = '0.1.0'
}

// Trace and report options
timeline {
    enabled   = true
    file      = "${params.outdir}/pipeline_info/execution_timeline.html"
    overwrite = true
}

report {
    enabled   = true
    file      = "${params.outdir}/pipeline_info/execution_report.html"
    overwrite = true
}

trace {
    enabled   = true
    file      = "${params.outdir}/pipeline_info/execution_trace.txt"
    overwrite = true
}
EOF

# Create conf/modules.config
cat > conf/modules.config <<'EOF'
/*
========================================================================================
    Module-specific Configuration
========================================================================================
*/

process {
    // Add per-process resource configurations here
    // Example:
    // withName: 'PROCESS_ONE' {
    //     cpus   = { check_max( 4, 'cpus' ) }
    //     memory = { check_max( 16.GB * task.attempt, 'memory' ) }
    //     time   = { check_max( 4.h * task.attempt, 'time' ) }
    //     disk   = '100 GB'
    // }
}
EOF

# Create Dockerfile
# Prefer Seqera Wave containers when available; fall back to custom build
cat > docker/Dockerfile <<'EOF'
FROM continuumio/miniconda3:latest

LABEL maintainer="Ghobrial Lab"
LABEL description="PIPELINE_NAME"

RUN conda install -y -c conda-forge -c bioconda \
        # Add your conda dependencies here
    && conda clean -afy

# COPY local_tool /opt/local_tool
# RUN cd /opt/local_tool && pip install --no-cache-dir .
EOF

# Create docker build_and_push.sh
# Ensure the Artifact Registry repository exists before pushing
cat > docker/build_and_push.sh <<'SCRIPT'
#!/bin/bash

# Build and push Docker image to Google Cloud Artifact Registry
# Usage: ./build_and_push.sh [ARTIFACT_REGISTRY] [REPOSITORY]
#
# ARTIFACT_REGISTRY already includes the project, e.g. us-docker.pkg.dev/my-project
# Image path: ${ARTIFACT_REGISTRY}/${REPOSITORY}/${IMAGE_NAME}:${VERSION}

set -e

# Default values — ARTIFACT_REGISTRY already includes the GCP project, never append PROJECT_ID
REGISTRY="${1:-ARTIFACT_REGISTRY_PLACEHOLDER}"
REPOSITORY="${2:-TOOL_NAME}"
IMAGE_NAME="TOOL_NAME"
VERSION="0.1.0"

# Full image path — no PROJECT_ID segment, REGISTRY already contains it
FULL_IMAGE_PATH="${REGISTRY}/${REPOSITORY}/${IMAGE_NAME}:${VERSION}"
LATEST_IMAGE_PATH="${REGISTRY}/${REPOSITORY}/${IMAGE_NAME}:latest"

echo "Building Docker image..."
docker build --platform linux/amd64 -t ${IMAGE_NAME}:${VERSION} -t ${IMAGE_NAME}:latest .

echo "Tagging image for Google Artifact Registry..."
docker tag ${IMAGE_NAME}:${VERSION} ${FULL_IMAGE_PATH}
docker tag ${IMAGE_NAME}:latest ${LATEST_IMAGE_PATH}

echo "Pushing image to Google Artifact Registry..."
docker push ${FULL_IMAGE_PATH}
docker push ${LATEST_IMAGE_PATH}

echo "Successfully pushed images:"
echo "  - ${FULL_IMAGE_PATH}"
echo "  - ${LATEST_IMAGE_PATH}"
SCRIPT
chmod +x docker/build_and_push.sh

# Create pixi.toml
cat > pixi.toml <<'EOF'
[project]
name = "PIPELINE_NAME"
version = "0.1.0"
description = "Brief description of pipeline"
channels = ["conda-forge", "bioconda"]
platforms = ["linux-64", "osx-64", "osx-arm64"]

[dependencies]
# Development and testing tools ONLY
nextflow = ">=23.04.0"
nf-test = ">=0.8.0"

# Python for development scripts
python = "3.11.*"

# DO NOT ADD PIPELINE TOOLS HERE
# Pipeline tools should be in Docker containers

EOF

# Create test samplesheet
cat > test_data/samplesheet_test.csv <<'EOF'
sample_id,input_file
sample1,test_data/sample1.txt
sample2,test_data/sample2.txt
EOF

# Create test input files
echo "Test data for sample 1" > test_data/sample1.txt
echo "Test data for sample 2" > test_data/sample2.txt

# Create test_data README
cat > test_data/README.md <<'EOF'
# Test Data

## Files

- `samplesheet_test.csv` - Example samplesheet with 2 samples
- `sample1.txt` - Test input for sample 1
- `sample2.txt` - Test input for sample 2

## Usage

```bash
nextflow run main.nf -profile local --samplesheet test_data/samplesheet_test.csv
```

## Regeneration

These are minimal test files. Replace with real test data as you develop your pipeline.
EOF

# Create .gitignore
cat > .gitignore <<'EOF'
# Pixi environment
.pixi/

# Nextflow
work/
results/
results_test/
.nextflow/
.nextflow.log*

# nf-test
.nf-test/
.nf-test.log

# OS
.DS_Store
EOF

# Create README.md
cat > README.md <<'EOF'
# PIPELINE_NAME

Brief description of what this pipeline does.

## Quick Start

### Install dependencies

```bash
# Install pixi (if not already installed)
curl -fsSL https://pixi.sh/install.sh | bash

# Install pipeline dependencies
pixi install
```

### Run locally

```bash
# Run with test data
pixi run run-test

# Or run with your own samplesheet
nextflow run main.nf -profile local --samplesheet your_samples.csv
```

### Run on GCP

```bash
nextflow run main.nf \
    -profile gcp \
    --samplesheet gs://bucket/samples.csv \
    --outdir gs://bucket/results
```

## Input Format

The pipeline expects a CSV samplesheet with the following columns:

- `sample_id`: Unique sample identifier
- `input_file`: Path to input file

Example:
```csv
sample_id,input_file
sample1,/path/to/sample1.txt
sample2,/path/to/sample2.txt
```

## Docker

Build and push the container:

```bash
cd docker && ./build_and_push.sh
```

## Development

### Adding Processes

Use the `/add-process` Claude command from within this pipeline directory to interactively
add new process steps. It will create the module, wire it into the workflow, and configure
resources following the project conventions.

## Parameters

- `--samplesheet`: Path to CSV samplesheet (required)
- `--outdir`: Output directory (default: `./results`)
- `--publish_dir_mode`: How to publish outputs: 'copy', 'symlink', 'move' (default: 'copy')

## Output Structure

```
results/
├── sample1/
├── sample2/
└── pipeline_info/
    ├── execution_timeline.html
    ├── execution_report.html
    └── execution_trace.txt
```

## Citation

If you use this pipeline, please cite:

[Add citation here]

## Contact

For questions or issues, contact: [your-email@example.com]
EOF

# Create CHANGELOG.md
cat > CHANGELOG.md <<'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - YYYY-MM-DD

### Added
- Initial pipeline skeleton
- Basic samplesheet reading
- Local and GCP execution profiles
- Test data

### Changed
- N/A

### Fixed
- N/A
EOF

# sed -i syntax differs: BSD (macOS) requires '', GNU (Linux) does not
SED_INPLACE=(sed -i)
if sed --version 2>/dev/null | grep -q GNU; then
    SED_INPLACE=(sed -i)
else
    SED_INPLACE=(sed -i '')
fi

# Replace PIPELINE_NAME placeholder with actual name
FULL_NAME="nextflow-$PIPELINE_NAME"
"${SED_INPLACE[@]}" "s/PIPELINE_NAME/$FULL_NAME/g" main.nf nextflow.config pixi.toml README.md docker/Dockerfile docker/build_and_push.sh

# Replace GCP placeholders with values from environment variables
"${SED_INPLACE[@]}" \
    -e "s|GCP_WORK_DIR_PLACEHOLDER|${GCP_WORK_DIR}|g" \
    -e "s|GCP_PROJECT_PLACEHOLDER|${GCP_PROJECT}|g" \
    -e "s|GCP_REGION_PLACEHOLDER|${GCP_REGION}|g" \
    -e "s|ARTIFACT_REGISTRY_PLACEHOLDER|${ARTIFACT_REGISTRY}|g" \
    nextflow.config docker/build_and_push.sh

echo "Pipeline skeleton created"
echo ""

# Step 2: Install development dependencies with pixi
echo "Installing development dependencies with pixi..."
pixi install
echo "Development dependencies installed"
echo ""

# Step 3: Initialize git repository
echo "Initializing git repository..."
git init
git add .
git commit -m "Initial commit: Pipeline skeleton for nextflow-$PIPELINE_NAME

Generated with Claude Code /setup-pipeline command"
echo "Git repository initialized"
echo ""

# Step 4: Display environment info
echo "========================================="
echo "Pipeline setup complete!"
echo "========================================="
echo ""
echo "Pipeline location: $PIPELINE_DIR"
echo ""
echo "Development tools installed via pixi:"
pixi list | grep -E "(nextflow|nf-test)" || echo "  - nextflow (>= 23.04.0)"
echo ""
echo "Quick start:"
echo "  cd $PIPELINE_DIR"
echo "  pixi run nextflow run main.nf -profile test    # Run with test data"
echo ""
echo "To add processes to your pipeline:"
echo "  cd $PIPELINE_DIR"
echo "  /add-process                                    # Interactive process creation"
echo ""
echo "GCP deployment:"
echo "  nextflow run main.nf -profile gcp --samplesheet gs://bucket/samples.csv --outdir gs://bucket/results"
echo "========================================="
