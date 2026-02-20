# Input Patterns, Branching & Output Management

## Input Patterns

### Simple CSV samplesheet (arcashla, cd45isoform)
```groovy
ch_samplesheet = Channel.fromPath(params.samplesheet, checkIfExists: true)
    .splitCsv(header: true, sep: ',')
    .map { row ->
        if (!row.sample_id) error "Missing sample_id"
        tuple(row.sample_id, file(row.input_file, checkIfExists: true))
    }
```

### Multi-row grouping (fastq-merge)
Same sample_id on multiple rows gets grouped:
```groovy
.groupTuple()
.map { sid, file_lists -> tuple(sid, file_lists.flatten()) }
```

### Glob pattern expansion (cellranger)
```groovy
.map { row ->
    def files = file(row.fastq_file)  // Nextflow expands globs
    return tuple(row.sample_id, files)
}
.groupTuple()
.map { sid, file_lists -> tuple(sid, file_lists.flatten()) }
```

### Value channels for non-per-sample inputs (bclconvert)
```groovy
ch_run_dir = Channel.value(file(params.run_dir))
```

### Reference files as extra channel (cd45isoform, cellranger)
```groovy
ch_reference = Channel.fromPath(ref_file, checkIfExists: true)

// Use .collect() for reference to avoid consuming the channel
CD45_ISOFORM_QUANT(SAMTOOLS_INDEX.out.bam_bai, ch_reference.collect())

// Or file() directly for single-value
CELLRANGER_COUNT(ch_branched.gex, file(params.reference))
```

## Branching Workflows

### By sample ID pattern (cellranger)
```groovy
ch_samples
    .branch {
        gex: it[0] =~ /(?i).*GEX.*/
        vdj: it[0] =~ /(?i).*VDJ.*/
    }
    .set { ch_branched }

CELLRANGER_COUNT(ch_branched.gex, file(params.reference))
CELLRANGER_VDJ(ch_branched.vdj, file(params.vdj_reference))
```

### By param value (cellranger data_type)
```groovy
if (params.data_type == 'GEX') {
    // GEX workflow
} else if (params.data_type == 'FLEX') {
    // FLEX workflow
} else {
    error "Invalid data_type: ${params.data_type}"
}
```

## Output Management

### Per-sample directories (most common)
```groovy
publishDir "${params.outdir}/${sample_id}/process_name", mode: params.publish_dir_mode
```

### Per-sample, stripped prefix (cellranger)
```groovy
publishDir "${params.outdir}/${sample_id}", mode: params.publish_dir_mode, saveAs: { filename ->
    filename.replaceFirst(/^[^\/]+\/outs\//, '')
}
```

### Global output (bclconvert, fastq-merge manifest)
```groovy
publishDir "${params.outdir}", mode: params.publish_dir_mode
```

### Pattern filtering
```groovy
publishDir "${params.outdir}/${sample_id}/process_name",
    mode: params.publish_dir_mode,
    pattern: "*.{json,log,txt}"
```

## Process Chaining Patterns

### Linear (most pipelines)
```groovy
PROCESS_A(ch_samplesheet)
PROCESS_B(PROCESS_A.out.result)
```

### With extra inputs
```groovy
SAMTOOLS_INDEX(ch_samplesheet)
CD45_ISOFORM_QUANT(SAMTOOLS_INDEX.out.bam_bai, ch_reference.collect())
```

### Conditional downstream (cellranger + souporcell)
```groovy
CELLRANGER_COUNT(ch_branched.gex, file(params.reference))

if (params.run_souporcell) {
    SOUPORCELL(
        CELLRANGER_COUNT.out.souporcell_input.map { ... },
        file(params.souporcell_fasta)
    )
}
```

## Pattern Selection

| Pattern | Use Case | Example |
|---------|----------|---------|
| Single process | Format conversion | bclconvert |
| Linear (A → B) | Sequential processing | arcashla, cd45isoform |
| Linear + aggregation | Process per-sample then combine | fastq-merge |
| Branching by ID | Multiple data types in one pipeline | cellranger (GEX/VDJ) |
| Branching by param | Different workflows per data type | cellranger (GEX/FLEX/SOUPORCELL) |
| Conditional downstream | Optional extra analysis | cellranger + souporcell |
