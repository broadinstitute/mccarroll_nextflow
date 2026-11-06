# Standard Analysis Pipeline - Nextflow DSL2

This pipeline performs comprehensive single-cell RNA-seq analysis, converted from the original WDL implementation.

## Pipeline Overview

The standard analysis pipeline includes the following steps:

1. **Digital Expression Subsetting** - Subsets the digital gene expression (DGE) Loom file
2. **Molecular Barcode Gathering** - Gathers molecule barcodes by gene
3. **Interval Creation** - Creates intervals for parallel processing
4. **Chimeric Transcript Collapsing** - Collapses chimeric transcripts using molecular barcodes
5. **Transcript Downsampling** - Performs downsampling analysis
6. **Downsampling Plot Gathering** - Collects and summarizes downsampling results
7. **Meta-Gene Discovery** - Discovers meta-genes in the dataset
8. **Cell-to-Sample Assignment** - Assigns cells to individual samples
9. **Dropulation Plotting** - Creates dropulation plots
10. **Doublet Detection** - Detects potential doublets
11. **Sex Genotyping** - Determines sex genotypes based on gene expression

## Requirements

- Nextflow >= 23.04.0
- Python 3.x with required analysis scripts
- Input data in Loom format

## Quick Start

### Basic Usage

```bash
nextflow run main.nf \\
    --dge_loom /path/to/input.loom \\
    --sample_name MySample \\
    --individual_names /path/to/individuals.txt \\
    --annotation_gtf /path/to/annotation.gtf \\
    --sex_gene_names /path/to/sex_genes.txt \\
    --nref 5000 \\
    --num_downsample 10 \\
    --output_dir ./results
```

### With Optional Parameters

```bash
nextflow run main.nf \\
    --dge_loom /path/to/input.loom \\
    --sample_name MySample \\
    --individual_names /path/to/individuals.txt \\
    --annotation_gtf /path/to/annotation.gtf \\
    --sex_gene_names /path/to/sex_genes.txt \\
    --nref 5000 \\
    --num_downsample 10 \\
    --bead_synthesis_error_rate 0.2 \\
    --bead_synthesis_size 2000000 \\
    --dge_loom_extra /path/to/extra1.loom,/path/to/extra2.loom \\
    --output_dir ./results
```

### Using Different Execution Profiles

```bash
# Run with Docker
nextflow run main.nf -profile docker --dge_loom ...

# Run with Singularity
nextflow run main.nf -profile singularity --dge_loom ...

# Run on AWS Batch
nextflow run main.nf -profile awsbatch --dge_loom ...

# Run on Slurm
nextflow run main.nf -profile slurm --dge_loom ...
```

## Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `--dge_loom` | file | Path to digital gene expression Loom file |
| `--sample_name` | string | Sample name for output files |
| `--individual_names` | file | Path to file with individual names |
| `--annotation_gtf` | file | Path to GTF annotation file |
| `--sex_gene_names` | file | Path to file with sex-specific gene names |
| `--nref` | integer | Number of reference cells |
| `--num_downsample` | integer | Number of downsampling iterations |
| `--output_dir` | path | Directory for output files |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `--bead_synthesis_error_rate` | float | 0.2 | Bead synthesis error rate |
| `--bead_synthesis_size` | integer | 2000000 | Bead synthesis size |
| `--dge_loom_extra` | string | null | Additional Loom files (comma-separated) |

## Output Structure

```
results/
├── subset_dge/              # Subset digital expression files
├── molecule_barcodes/       # Molecular barcode files
├── intervals/               # Interval files for parallel processing
├── collapsed_umis/          # Collapsed UMI files
├── downsampling/            # Downsampling analysis plots
├── downsampling_summary/    # Summary of downsampling results
├── meta_genes/              # Meta-gene discovery results
├── assignments/             # Cell-to-sample assignments
├── dropulation/             # Dropulation plots
├── doublets/                # Doublet detection results
├── sex_genotypes/           # Sex genotype results
└── reports/                 # Execution reports and traces
    ├── execution_report.html
    ├── timeline.html
    ├── trace.txt
    └── pipeline_dag.html
```

## Resource Configuration

Default resource allocations can be adjusted in `nextflow.config`:

- **SUBSET_DIGITAL_EXPRESSION**: 2 CPUs, 8 GB RAM, 2h
- **GATHER_MOLECULE_BARCODES_BY_GENE**: 4 CPUs, 16 GB RAM, 4h
- **CREATE_INTERVALS**: 2 CPUs, 4 GB RAM, 1h
- **COLLAPSE_BARCODE_CHIMERIC_TRANSCRIPTS**: 2 CPUs, 8 GB RAM, 2h
- **TRANSCRIPT_DOWNSAMPLING**: 2 CPUs, 12 GB RAM, 4h
- **DISCOVER_META_GENES**: 4 CPUs, 32 GB RAM, 8h
- **ASSIGN_CELLS_TO_SAMPLES**: 4 CPUs, 24 GB RAM, 8h
- **DETECT_DOUBLETS**: 4 CPUs, 24 GB RAM, 8h

## Execution Profiles

The pipeline includes several pre-configured profiles:

- **standard**: Local execution (default)
- **docker**: Docker container execution
- **singularity**: Singularity container execution
- **awsbatch**: AWS Batch execution
- **gcp**: Google Cloud Batch execution
- **slurm**: Slurm cluster execution

## Troubleshooting

### Common Issues

1. **Memory errors**: Increase memory allocation in `nextflow.config` for specific processes
2. **Timeout errors**: Increase time allocation for long-running processes
3. **Missing files**: Ensure all input paths are absolute or relative to the launch directory

### Checking Execution

View execution reports:
```bash
# Timeline
firefox results/reports/timeline.html

# Execution report
firefox results/reports/execution_report.html

# Pipeline DAG
firefox results/reports/pipeline_dag.html
```

View process logs:
```bash
# Check work directory for specific task
cat work/<hash>/hash/.command.log
```

## Citation

If you use this pipeline, please cite:
- Nextflow: Di Tommaso, P. et al. (2017). Nextflow enables reproducible computational workflows. Nature Biotechnology.

## Support

For issues or questions, please open an issue on the GitHub repository.
