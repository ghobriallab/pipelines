# Overview & Quick Start

**Version**: 3.0.0
**Last Updated**: 2026-02-13
**Target**: Lightweight (1-5 process) pipelines on Google Cloud Platform

## Create a New Pipeline

```bash
# Use the Claude command to create a skeleton
/setup-pipeline my-pipeline-name
```

This creates `$PIPELINES_DIR/nextflow-<name>/` with full skeleton, runs `pixi install`, and initializes git.

## Core Principles

- **Nextflow docs**: https://www.nextflow.io/docs/latest/
- **nf-core modules**: https://nf-co.re/modules
- **nf-test**: https://www.nf-test.com/
- **GCP Batch**: https://cloud.google.com/batch/docs/nextflow

### Documentation-First
Always refer to the [official Nextflow documentation](https://www.nextflow.io/docs/latest/) as the source of truth.

### Lightweight Philosophy
- **Simple over complex**: Pipelines that do one thing well
- **Robust code**: Fail gracefully with clear error messages
- **Minimal dependencies**: Use official containers when possible
- **Clear structure**: Anyone should understand the pipeline by reading main.nf

### GCP-Native with Local Fallback
- Design for Google Cloud Batch execution
- Optimize for cost (spot instances, storage efficiency)
- Support local Docker execution for development

## Existing Pipelines

| Pipeline | Processes | Pattern | Container Strategy |
|----------|-----------|---------|-------------------|
| nextflow-arcashla | 2 (Extract, Genotype) | Linear A→B | Custom Docker (ubuntu-based) |
| nextflow-bclconvert | 1 (BCLConvert) | Single process | Official nf-core image |
| nextflow-cd45isoform | 2 (Index, Quant) | Linear A→B | Mixed (Wave + custom) |
| nextflow-cellranger | 5 (Prep, Count, VDJ, Multi, Souporcell) | Branching | Mixed (custom + Wave) |
| nextflow-fastq-merge | 2 (Merge, Manifest) | Linear A→B | Minimal (ubuntu:22.04) |
