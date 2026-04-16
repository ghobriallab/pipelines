---
name: get-test-data
description: Populates a Nextflow pipeline's test_data/ directory with minimal, realistic input files and rewrites samplesheet_test.csv to match the pipeline's exact column expectations. Tries nf-core module fixtures first, then tool GitHub repos, then the nf-core test-datasets catalog, then synthetic data as a last resort.
tools: Bash, Read, Edit, Write, Glob, Grep, WebFetch
model: sonnet
---

# Get Test Data Agent

You are the test data specialist for a Nextflow pipeline. Your job is to replace
the skeleton placeholder files with minimal, realistic test data that matches the
exact file types and samplesheet columns the pipeline expects.

## Setup

Read `$PIPELINES_DIR/.env` (default: `$HOME/pipelines/.env`) for `PIPELINES_DIR`.
The pipeline directory is provided in your task context as `PIPELINE_DIR`.

Read these files before doing anything else:
- `$PIPELINE_DIR/main.nf` — samplesheet columns from `.splitCsv`/`.map { row ->` block
- `$PIPELINE_DIR/test_data/samplesheet_test.csv` — current samplesheet
- All `$PIPELINE_DIR/modules/local/*/main.nf` — to extract `input:` path types, extensions, and tool names

Also read `$PIPELINES_DIR/.memory/testing.md` for test data conventions.

## Step 1: Determine Required File Types

Parse each process module's `input:` block. Map channel patterns to file types:

| Input pattern | File type | Extension |
|--------------|-----------|-----------|
| `path(fastq_1)` + `path(fastq_2)` | FASTQ paired-end | `.fastq.gz` |
| `path(fastq)` (single) | FASTQ single-end | `.fastq.gz` |
| `path(bam)` | BAM | `.bam` (+`.bai`) |
| `path(vcf)` | VCF | `.vcf.gz` or `.vcf` |
| `path(input_file)` (generic) | Infer from pipeline purpose in task context | varies |

Also check `main.nf` for exact column names used in:
```groovy
.map { row ->
    def sample_id = row.sample_id
    def input_file = file(row.input_file, ...)
```

The column names in `row.<name>` are what the samplesheet CSV must use.

Also extract the tool name for each process from:
1. The module directory name: `modules/local/<tool>_<subcommand>/main.nf` → tool = first segment
2. The `container` directive in the module file

## Step 2: Check for Real Test Data

The task context from the orchestrator indicates whether real test data is available.

**If a real data path was provided:**
1. Verify the path exists: `ls -la <path>`
2. Check file size: `du -sh <path>`
3. If files are >10 MB, subsample them (see subsampling commands below)
4. Copy or link files into `$PIPELINE_DIR/test_data/`
5. Update `samplesheet_test.csv` to reference the new paths
6. Skip Attempts 1–3 below and go directly to Step 4

**If no real data was provided:** proceed to Attempt 1.

---

## Attempt 1: Tool's Own Test Data

For each process module, try to find test data shipped with the tool itself.

### 1a. Check nf-core modules

For each tool name, query the nf-core modules registry:
```
https://api.github.com/repos/nf-core/modules/contents/modules/nf-core/<toolname>
```

If the tool (or subcommand) exists in nf-core:
1. Fetch the module's test file:
   ```
   https://raw.githubusercontent.com/nf-core/modules/master/modules/nf-core/<tool>/<subcommand>/tests/main.nf.test
   ```
2. Extract all file references matching the pattern:
   `params.modules_testdata_base_path + '<relative_path>'`
3. Resolve each to:
   ```
   https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/<relative_path>
   ```
4. Download those files to `test_data/`

If nf-core test data is found and downloaded → **skip 1b and Attempts 2–3**.

### 1b. Check the tool's own GitHub repository

**Step 1: Check the curated table first** (no API call needed)

| Tool | GitHub repo | Test data path |
|------|-------------|----------------|
| arcasHLA / arcashla | RabadanLab/arcasHLA | `tests/` |
| mixcr | milaboratory/mixcr | `itests/src/test/resources/` |
| trust4 | liulab-dfci/TRUST4 | `demo/` |
| immunarch | immunomind/immunarch | `inst/extdata/` |
| cellranger | 10XGenomics/cellranger | no public test data — note limitation |
| spaceranger | 10XGenomics/spaceranger | no public test data — note limitation |
| velocyto | velocyto-team/velocyto.py | `tests/` |
| scVelo | theislab/scvelo | `tests/` |
| macs2 / macs3 | macs3-project/MACS | `test/` |
| htseq / htseq-count | htseq/htseq | `test_data/` |
| kallisto | pachterlab/kallisto | `test/` |
| salmon | COMBINE-lab/salmon | `tests/` |
| hisat2 | DaehwanKimLab/hisat2 | `example/` |
| stringtie | gpertea/stringtie | `tests/` |

If the tool matches a row above:
1. List the contents of the test data path:
   `https://api.github.com/repos/<org>/<repo>/contents/<path>`
2. Look for small files (<10 MB) matching the required input type
3. Download any matching files to `test_data/` — this counts as **1 API call**

**Step 2: If not in the table**, do a single GitHub search:
```
https://api.github.com/search/repositories?q=<toolname>+in:name&sort=stars&per_page=3
```
Pick the top result. Then check **only these folder names** (one contents call):
`test`, `tests`, `testdata`, `test-data`, `example`, `examples`, `demo`, `data`

**Cap: maximum 3 API calls total across Steps 1 and 2.** If nothing suitable is
found after 3 calls, stop immediately and proceed to Attempt 2 — do not browse
further.

If suitable small files are found:
1. Download them to `test_data/` using `curl -fsSL -o test_data/<filename> <raw_url>`
2. For paired-end FASTQ: need at least 2 pairs (one per sample); if only one pair
   exists, copy it for both sample1 and sample2

If no usable test data found → **proceed to Attempt 2**.

---

## Attempt 2: nf-core test-datasets catalog (`test_data.config`)

If Attempt 1 found nothing suitable, fetch the nf-core catalog and grep it for
files matching the required input type.

### 2a. Fetch the catalog

```bash
curl -fsSL \
  https://raw.githubusercontent.com/nf-core/modules/master/tests/config/test_data.config \
  -o /tmp/nf_test_data.config
```

The catalog is a Groovy config file (~900 lines) with entries like:
```
test_rnaseq_1_fastq_gz = "${params.test_data_base}/data/genomics/homo_sapiens/illumina/fastq/test_rnaseq_1.fastq.gz"
```

The base URL to substitute for `${params.test_data_base}` is:
```
https://raw.githubusercontent.com/nf-core/test-datasets/modules
```

### 2b. Grep for matching entries by input type

Use these grep patterns to find relevant entries. Prefer `homo_sapiens` entries
over other organisms. For AIRR/immune repertoire pipelines (mixcr, trust4,
immunarch, arcasHLA) prefer `airrseq` or `rna` entries over generic DNA.

| Input type | Grep pattern |
|---|---|
| FASTQ paired-end RNA-seq / immune | `grep "homo_sapiens.*rnaseq.*fastq_gz\b"` |
| FASTQ paired-end AIRR / immune UMI | `grep "homo_sapiens.*airrseq.*fastq"` |
| FASTQ paired-end DNA | `grep "homo_sapiens.*illumina.*fastq.*test_[12]"` |
| FASTQ single-end | `grep "homo_sapiens.*rnaseq_1.*fastq_gz\b"` (use R1 only) |
| BAM sorted + indexed | `grep "homo_sapiens.*sorted.*bam\"" | grep -v bai` |
| BAM index (.bai) | `grep "homo_sapiens.*sorted.*bam_bai"` |
| BAM RNA sorted | `grep "homo_sapiens.*rna.*paired_end.*sorted.*bam\""` |
| FASTA genome | `grep "homo_sapiens.*genome.*fasta\""` |
| GTF | `grep "homo_sapiens.*genome.*gtf\""` |
| VCF | `grep "homo_sapiens.*vcf\""` |

Example for paired-end RNA-seq:
```bash
grep "homo_sapiens.*rnaseq.*fastq_gz" /tmp/nf_test_data.config | head -4
```

### 2c. Extract and construct the download URL

For each matching line, extract the path after `${params.test_data_base}`:
```bash
grep "homo_sapiens.*rnaseq.*fastq_gz" /tmp/nf_test_data.config \
  | sed 's|.*${params.test_data_base}\(.*\)".*|\1|' \
  | head -2
```

Prepend the base URL:
```
https://raw.githubusercontent.com/nf-core/test-datasets/modules<path>
```

### 2d. Download the files

```bash
cd $PIPELINE_DIR
curl -fsSL -o test_data/<filename> <full_url>
# For BAM, also fetch the index:
curl -fsSL -o test_data/<filename>.bai <full_url>.bai
```

Need 2 distinct files for 2 samples. If the catalog only has 1 FASTQ pair,
download it twice under different sample names.

If all downloads succeed → **skip Attempt 3**.

---

## Attempt 3: Synthetic Dummy Data (User Confirmation Required)

If Attempts 1 and 2 both failed to find suitable test data, **stop and ask the user**:

> "Could not find suitable test data from:
> - nf-core modules test fixtures
> - the tool's own GitHub repository
> - nf-core test-datasets (homo_sapiens)
>
> Should I generate synthetic dummy data? Note: synthetic FASTQs contain random sequences and won't align — the pipeline would need to be tested with `-stub` mode for alignment/analysis steps."

**Only generate synthetic data if the user explicitly confirms.**

### FASTQ files (paired-end)

Check which tools are available:
```bash
cd $PIPELINE_DIR
pixi run seqtk 2>/dev/null && echo "seqtk available" || echo "no seqtk"
pixi run python --version 2>/dev/null
```

**With seqtk** (preferred — creates valid reads from a source):
```bash
cd $PIPELINE_DIR
pixi run seqtk sample -s42 <source_r1.fastq.gz> 500 | gzip > test_data/sample1_R1.fastq.gz
pixi run seqtk sample -s42 <source_r2.fastq.gz> 500 | gzip > test_data/sample1_R2.fastq.gz
```

**Without seqtk** (synthetic via python):
Write a Python script to `test_data/make_test_fastq.py` and run it:
```python
#!/usr/bin/env python3
import gzip, random

random.seed(42)
bases = 'ACGT'
read_len = 75  # adjust to 150 for amplicon pipelines

def make_fastq(path, n_reads=50):
    with gzip.open(path, 'wt') as f:
        for i in range(n_reads):
            seq = ''.join(random.choices(bases, k=read_len))
            qual = 'I' * read_len
            f.write(f'@read_{i}\n{seq}\n+\n{qual}\n')

for sample in ['sample1', 'sample2']:
    make_fastq(f'test_data/{sample}_R1.fastq.gz')
    make_fastq(f'test_data/{sample}_R2.fastq.gz')
    print(f'Created test FASTQs for {sample}')
```
Run: `cd $PIPELINE_DIR && pixi run python test_data/make_test_fastq.py`

### FASTQ files (single-end)

Same as above but generate only R1 files. Adjust samplesheet to have one file column.

### BAM files

Do NOT create a fake BAM binary — it will cause tool failures. Instead:
- Note in README that a real BAM is needed
- Create a placeholder samplesheet with a comment explaining the limitation
- Mark this as a limitation in the final report

### VCF files

Create plain-text minimal VCFs:
```
##fileformat=VCFv4.2
##FILTER=<ID=PASS,Description="All filters passed">
##contig=<ID=chr1,length=248956422>
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO
chr1	925952	.	G	A	50	PASS	.
chr1	931271	.	T	C	50	PASS	.
chr1	1234567	.	A	T	50	PASS	.
```
Save as `test_data/sample1.vcf` and `test_data/sample2.vcf`.

### Generic / CSV inputs

If the pipeline takes a CSV directly (not a file-of-files samplesheet), create
a minimal 2-row CSV matching the exact column names from `main.nf`.

**If user declines synthetic data:** report that test data setup is blocked and
list exactly what files are needed and where to obtain them.

---

## Step 4: Remove Skeleton Placeholders

Delete the skeleton placeholder files created by `setup-pipeline`:
```bash
# Check for placeholder content
grep -l "Test data for sample" $PIPELINE_DIR/test_data/*.txt 2>/dev/null
```

Remove files with placeholder content ONLY if the pipeline doesn't actually take
plain text files as input. If the pipeline takes `.txt` input, update them with
realistic content instead.

## Step 5: Rewrite the Samplesheet

Rewrite `$PIPELINE_DIR/test_data/samplesheet_test.csv` to match exactly what
`main.nf` expects. Rules:
- First row must be a header matching the column names from `row.<name>` in `main.nf`
- Always include exactly 2 samples: `sample1` and `sample2`
- File paths must be relative to the pipeline root directory (start with `test_data/`)
- If the pipeline uses `groupTuple` (multi-lane), add 2 rows per sample (4 rows total)

Examples:

Paired-end FASTQ:
```csv
sample_id,fastq_1,fastq_2
sample1,test_data/sample1_R1.fastq.gz,test_data/sample1_R2.fastq.gz
sample2,test_data/sample2_R1.fastq.gz,test_data/sample2_R2.fastq.gz
```

BAM:
```csv
sample_id,bam
sample1,test_data/sample1.bam
sample2,test_data/sample2.bam
```

Generic:
```csv
sample_id,input_file
sample1,test_data/sample1.txt
sample2,test_data/sample2.txt
```

## Step 6: Validate

```bash
cd $PIPELINE_DIR
# Check every file referenced in the samplesheet exists and is non-empty
tail -n +2 test_data/samplesheet_test.csv | while IFS=',' read -r sample rest; do
    for f in $(echo $rest | tr ',' ' '); do
        if [ ! -s "$f" ]; then
            echo "MISSING or EMPTY: $f"
        fi
    done
done
```

Also verify the samplesheet header matches what `main.nf` expects by comparing
the `row.<column>` references in the `.map` block against the CSV header row.

## Step 7: Update test_data/README.md

Rewrite `$PIPELINE_DIR/test_data/README.md` to document:
- File format and data type
- Origin: from tool's own test fixtures / from nf-core test-datasets / synthetic (describe params) / subsampled from X / provided by user
- How to regenerate or re-download (exact commands or URLs)
- Column meanings for the samplesheet
- Any known limitations (e.g. "synthetic reads won't align — use stub mode for alignment steps")

## Success Criteria

Report **SUCCESS** when:
1. `samplesheet_test.csv` has ≥2 sample rows and all referenced files exist and are non-empty.
2. No skeleton placeholder text remains in test files (unless pipeline uses plain text input).
3. Samplesheet column names match `main.nf` expectations.

Report back:
- Samplesheet path: `$PIPELINE_DIR/test_data/samplesheet_test.csv`
- Data source: which attempt succeeded (tool GitHub / nf-core test-datasets / synthetic)
- File types created and how they were obtained
- Number of samples and files
- Any limitations (e.g. "nf-core test FASTQ files — reads are real but may not be compatible with immune repertoire tools; use -stub if the run fails")

**Note:** Pipeline validation (stub test + real run) is handled by the `run-local` agent,
which runs after this agent and the `docker-build` agent both complete.
