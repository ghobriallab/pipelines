# Process Templates & Samplesheet Parsing

## Canonical Process Template (from real pipelines)

Every process lives at `modules/local/<process_name>/main.nf`:

```groovy
process PROCESS_NAME {
    tag "$sample_id"
    label 'process_medium'                    // process_low, process_medium, or process_high
    publishDir "${params.outdir}/${sample_id}/process_name", mode: params.publish_dir_mode
    container '<container_url>'

    input:
    tuple val(sample_id), path(input_file)

    output:
    tuple val(sample_id), path("${sample_id}.output.txt"), emit: result
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    tool ${args} --input ${input_file} --output ${sample_id}.output.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tool: \$(tool --version)
    END_VERSIONS
    """

    stub:
    """
    touch ${sample_id}.output.txt
    touch versions.yml
    """
}
```

## Real-World Variations Seen

### Container per-process (most common)
```groovy
container 'community.wave.seqera.io/library/samtools:1.23--12d9384dd0649f36'  // Seqera Wave
container 'us-docker.pkg.dev/ghobrial-pipelines/cd45isoform/cd45isoform:0.1.0'  // Custom GCP
container 'ubuntu:22.04'  // Minimal for simple ops
container 'quay.io/nf-core/bclconvert:4.4.6'  // Official nf-core
```

### Container from param (global default)
In `nextflow.config`:
```groovy
process {
    container = params.arcashla_container
}
```
Then override per-process via container directive in the module when needed.

### stageInMode 'copy' (when tools modify inputs in-place)
Used in: cd45isoform (SAMTOOLS_INDEX, CD45_ISOFORM_QUANT)
```groovy
process SAMTOOLS_INDEX {
    tag "$sample_id"
    stageInMode 'copy'
    ...
}
```

### stageOutMode 'copy' (for cloud file staging)
Used in: bclconvert (BCLCONVERT)
```groovy
process BCLCONVERT {
    stageOutMode 'copy'
    ...
}
```

### Absolute path resolution (for tools that need it)
Used in: cellranger, cd45isoform
```bash
REF_PATH=$(readlink -f ${reference})
```

### Custom publishDir with saveAs (strip directory prefixes)
Used in: cellranger
```groovy
publishDir "${params.outdir}/${sample_id}", mode: params.publish_dir_mode, saveAs: { filename ->
    filename.replaceFirst(/^[^\/]+\/outs\//, '')
}
```

### Optional output
```groovy
tuple val(sample_id), path("${sample_id}.alignment.p"), emit: alignment, optional: true
```

### when clause (conditional execution)
Used in: cellranger (souporcell)
```groovy
when:
task.ext.when == null || task.ext.when
```

### No versions.yml (simple utility processes)
Some utility processes like SAMTOOLS_INDEX and PREP_FASTQS skip versions.yml.
Keep it for processes running the main bioinformatics tool.

## Samplesheet Parsing Patterns

### Standard CSV (most pipelines)
```groovy
ch_samplesheet = Channel.fromPath(params.samplesheet, checkIfExists: true)
    .splitCsv(header: true, sep: ',')
    .map { row ->
        if (!row.sample_id) error "Missing sample_id in samplesheet"
        if (!row.input_file) error "Missing input_file for ${row.sample_id}"
        tuple(row.sample_id, file(row.input_file, checkIfExists: true))
    }
```

### GroupTuple for multi-row samples (fastq-merge)
```groovy
ch_samplesheet
    .splitCsv(header: true, sep: ',')
    .map { row -> tuple(row.sample_id, row.fastq_files.split(';').collect { file(it.trim()) }) }
    .groupTuple()
    .map { sid, file_lists -> tuple(sid, file_lists.flatten()) }
```

### Value channel for non-sample inputs (bclconvert)
```groovy
ch_run_dir = Channel.value(file(params.run_dir))
ch_samplesheet = params.samplesheet ?
    Channel.value(file(params.samplesheet)) :
    Channel.value([])
```

### Branching by sample ID (cellranger)
```groovy
ch_samples
    .branch {
        gex: it[0] =~ /(?i).*GEX.*/
        vdj: it[0] =~ /(?i).*VDJ.*/
    }
    .set { ch_branched }
```

## ext.args Pattern (configurable arguments via modules.config)

In the process:
```groovy
def args = task.ext.args ?: ''
```

In conf/modules.config:
```groovy
withName: 'CELLRANGER_COUNT' {
    ext.args = [
        params.expected_cells ? "--expect-cells=${params.expected_cells}" : '',
        params.include_introns ? "--include-introns=true" : "--include-introns=false",
        params.cellranger_args ?: ''
    ].join(' ').trim()
}
```

For bclconvert (with empty-string filtering):
```groovy
ext.args = [
    "--bcl-input-directory=${params.run_dir}",
    params.bcl_num_parallel_tiles ? "--bcl-num-parallel-tiles=${params.bcl_num_parallel_tiles}" : "",
    params.bcl_args ?: ''
].findAll { it != "" }.join(' ').trim()
```
