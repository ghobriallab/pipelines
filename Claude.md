# Nextflow Pipeline Development Guide - Ghobrial Lab

**Version**: 2.0.0
**Last Updated**: 2026-01-27
**Target**: Lightweight (2-3 process) pipelines on Google Cloud Platform

---

## Documentation Index

This guide is organized into concept-based modules stored in the [.memory](./.memory/) folder. Reference these files as needed for specific topics.

### Getting Started

- **[Overview & Quick Start](./.memory/overview.md)** - Create new pipelines, core principles, and example pipelines
- **[Common Commands](./.memory/commands.md)** - Essential commands for testing, development, and deployment

### Pipeline Structure

- **[Directory Structure](./.memory/structure.md)** - Standard project layout, DSL2 syntax, and required elements
- **[Process Templates](./.memory/templates.md)** - Process templates and samplesheet parsing patterns

### Development

- **[Development Setup](./.memory/development.md)** - VS Code configuration, nf-core modules, and pipeline skeleton
- **[Input Patterns & Branching](./.memory/patterns.md)** - Input handling, branching workflows, and output management
- **[Development Workflow](./.memory/workflow.md)** - Step-by-step development process from design to production

### Testing

- **[Testing Guide](./.memory/testing.md)** - Module tests, full pipeline testing, test data sources, and checklists

### Cloud Deployment

- **[GCP Configuration](./.memory/gcp.md)** - Google Cloud Batch setup, resource configuration, and debugging
- **[Container Strategy](./.memory/containers.md)** - Docker images, custom containers, and build/push workflows

---

## Quick Reference

**Create a new pipeline:**
```bash
./.claude/commands/new-pipeline my-pipeline-name
cd my-pipeline-name && pixi install
```

**Test locally:**
```bash
nextflow run main.nf -profile test,docker --samplesheet test.csv
```

**Deploy to GCP:**
```bash
nextflow run main.nf -profile gcp --samplesheet gs://bucket/samples.csv
```

---

**For questions or updates**, contact the Ghobrial Lab bioinformatics team.
