#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
========================================================================================
    Standard Analysis Pipeline - Nextflow DSL2
========================================================================================
    Converted from WDL standard_analysis.wdl
    
    This pipeline performs comprehensive single-cell RNA-seq analysis including:
    - Digital expression subsetting
    - Molecular barcode gathering
    - Chimeric transcript collapsing
    - Transcript downsampling
    - Meta-gene discovery
    - Cell-to-sample assignment
    - Doublet detection
    - Sex genotyping
----------------------------------------------------------------------------------------
*/

// Include modules
include { SUBSET_DIGITAL_EXPRESSION } from './modules/local/subset_digital_expression'
include { GATHER_MOLECULE_BARCODES_BY_GENE } from './modules/local/gather_molecule_barcodes_by_gene'
include { CREATE_INTERVALS } from './modules/local/create_intervals'
include { COLLAPSE_BARCODE_CHIMERIC_TRANSCRIPTS } from './modules/local/collapse_barcode_chimeric_transcripts'
include { TRANSCRIPT_DOWNSAMPLING } from './modules/local/transcript_downsampling'
include { GATHER_TRANSCRIPT_DOWNSAMPLING_PLOTS } from './modules/local/gather_transcript_downsampling_plots'
include { DISCOVER_META_GENES } from './modules/local/discover_meta_genes'
include { ASSIGN_CELLS_TO_SAMPLES } from './modules/local/assign_cells_to_samples'
include { DROPULATION_PLOT } from './modules/local/dropulation_plot'
include { DETECT_DOUBLETS } from './modules/local/detect_doublets'
include { SEX_GENOTYPES } from './modules/local/sex_genotypes'

// Print help message
def helpMessage() {
    log.info"""
    Usage:
    nextflow run main.nf [options]
    
    Required parameters:
      --dge_loom                    Path to digital gene expression Loom file
      --sample_name                 Sample name for output files
      --individual_names            Path to file with individual names
      --annotation_gtf              Path to GTF annotation file
      --sex_gene_names              Path to file with sex-specific gene names
      --nref                        Number of reference cells
      --num_downsample              Number of downsampling iterations
      --output_dir                  Directory for output files
    
    Optional parameters:
      --bead_synthesis_error_rate  Bead synthesis error rate (default: 0.2)
      --bead_synthesis_size        Bead synthesis size (default: 2000000)
      --dge_loom_extra             Additional Loom files (comma-separated)
      --help                        Show this help message
    """.stripIndent()
}

// Show help message if requested
if (params.help) {
    helpMessage()
    exit 0
}

// Validate required parameters
if (!params.dge_loom) {
    error "Missing required parameter: --dge_loom"
}
if (!params.sample_name) {
    error "Missing required parameter: --sample_name"
}
if (!params.individual_names) {
    error "Missing required parameter: --individual_names"
}
if (!params.annotation_gtf) {
    error "Missing required parameter: --annotation_gtf"
}
if (!params.sex_gene_names) {
    error "Missing required parameter: --sex_gene_names"
}
if (!params.nref) {
    error "Missing required parameter: --nref"
}
if (!params.num_downsample) {
    error "Missing required parameter: --num_downsample"
}
if (!params.output_dir) {
    error "Missing required parameter: --output_dir"
}

// Main workflow
workflow {
    // Create input channels
    def dge_loom_ch = channel.fromPath(params.dge_loom, checkIfExists: true)
    def individual_names_ch = channel.fromPath(params.individual_names, checkIfExists: true)
    def annotation_gtf_ch = channel.fromPath(params.annotation_gtf, checkIfExists: true)
    def sex_gene_names_ch = channel.fromPath(params.sex_gene_names, checkIfExists: true)
    
    // Process extra Loom files if provided
    def dge_loom_extra_ch = params.dge_loom_extra ? 
        channel.fromPath(params.dge_loom_extra.split(',') as List, checkIfExists: true).collect() : 
        channel.empty()
    
    // Step 1: Subset digital expression
    SUBSET_DIGITAL_EXPRESSION(
        dge_loom_ch,
        params.sample_name
    )
    
    // Step 2: Gather molecule barcodes by gene
    GATHER_MOLECULE_BARCODES_BY_GENE(
        SUBSET_DIGITAL_EXPRESSION.out.dge_subset,
        params.sample_name
    )
    
    // Step 3: Create intervals for parallel processing
    CREATE_INTERVALS(
        GATHER_MOLECULE_BARCODES_BY_GENE.out.molbc_umis,
        params.sample_name
    )
    
    // Step 4: Collapse chimeric transcripts for each interval
    def intervals_ch = CREATE_INTERVALS.out.intervals
        .splitText()
        .map { line -> line.trim() }
    
    COLLAPSE_BARCODE_CHIMERIC_TRANSCRIPTS(
        intervals_ch,
        GATHER_MOLECULE_BARCODES_BY_GENE.out.molbc_umis,
        params.sample_name,
        params.bead_synthesis_error_rate,
        params.bead_synthesis_size
    )
    
    // Step 5: Transcript downsampling
    TRANSCRIPT_DOWNSAMPLING(
        COLLAPSE_BARCODE_CHIMERIC_TRANSCRIPTS.out.collapsed_umis.collect(),
        SUBSET_DIGITAL_EXPRESSION.out.dge_subset,
        params.sample_name,
        params.num_downsample
    )
    
    // Step 6: Gather downsampling plots
    GATHER_TRANSCRIPT_DOWNSAMPLING_PLOTS(
        TRANSCRIPT_DOWNSAMPLING.out.downsampling_plots.collect(),
        params.sample_name
    )
    
    // Step 7: Discover meta genes
    DISCOVER_META_GENES(
        SUBSET_DIGITAL_EXPRESSION.out.dge_subset,
        params.sample_name
    )
    
    // Step 8: Assign cells to samples
    ASSIGN_CELLS_TO_SAMPLES(
        SUBSET_DIGITAL_EXPRESSION.out.dge_subset,
        individual_names_ch,
        annotation_gtf_ch,
        params.sample_name,
        params.nref
    )
    
    // Step 9: Create dropulation plot
    DROPULATION_PLOT(
        ASSIGN_CELLS_TO_SAMPLES.out.assignments,
        params.sample_name
    )
    
    // Step 10: Detect doublets
    DETECT_DOUBLETS(
        SUBSET_DIGITAL_EXPRESSION.out.dge_subset,
        ASSIGN_CELLS_TO_SAMPLES.out.assignments,
        params.sample_name
    )
    
    // Step 11: Sex genotyping
    SEX_GENOTYPES(
        SUBSET_DIGITAL_EXPRESSION.out.dge_subset,
        sex_gene_names_ch,
        params.sample_name
    )
    
    // Publish workflow completion message
    workflow.onComplete {
        log.info "Pipeline completed at: ${workflow.complete}"
        log.info "Execution status: ${workflow.success ? 'OK' : 'failed'}"
        log.info "Execution duration: ${workflow.duration}"
    }
}

workflow.onError {
    log.info "Oops... Pipeline execution stopped with the following message: ${workflow.errorMessage}"
}
