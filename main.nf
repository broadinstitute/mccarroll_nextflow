#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    mccarroll/nextflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
nextflow.enable.strict = true

include { MapMyCells_fromSpecifiedMarkers_workflow } from './subworkflows/local/MapMyCells_fromSpecifiedMarkers.nf'
include { tag_and_split_bam_workflow } from './subworkflows/local/tag_and_split_bam.nf'
include { align_locus_function_workflow } from './subworkflows/local/align_locus_function.nf'
include { cbrb_workflow } from './subworkflows/local/cbrb.nf'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_nextflow_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_nextflow_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params {
    allowedBarcodes: Path
    project: String
    library: String
    experimentDate: String
    reference: Path
    cloudReference: Path
    fastq_read1: List
    fastq_read2: List
    rawBam: List
    version10X: String
    sampleType: String
    beadStructure: String
    useSvmParameterEstimation: Boolean
    forceTwoClusterSolution: Boolean
    cbrbArgs: String


    // defaults
    cellBarcodeTag: String
    molecularBarcodeTag: String
    targetBamSizeMBytes: Integer
    fivePrimeAdapter: String
    strandStrategy: String
    locusFunction: String
    minimumTranscriptsPerCell: Integer
    dgeMinReadMq: Integer
    dgeFunctionalStrategy: String

    // infrastructure parameters
    email: String
    help: Boolean
    help_full: Boolean
    show_hidden: Boolean
    version: Boolean
    validate_params: Boolean
}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.help,
        params.help_full,
        params.show_hidden
    )

    //
    // WORKFLOW: Run main workflow
    //
     tag_and_split_bam_workflow(
        params.fastq_read1,
        params.fastq_read2,
        params.rawBam,
        params.library,
        params.beadStructure,
        params.allowedBarcodes
    )
    align_locus_function_workflow(
            tag_and_split_bam_workflow.out.splitBams,
            params.beadStructure
    )
    cbrb_workflow(
        align_locus_function_workflow.out.sparseDgeMatrix,
        align_locus_function_workflow.out.sparseDgeFeatures,
        align_locus_function_workflow.out.sparseDgeBarcodes,
        align_locus_function_workflow.out.cellFeatures
    )
   //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
    )

    // TODO: Need to determine overall publishing strategy for the pipeline.  Currently rawBam is being double-published,
    // once in the main workflow and once in subdirectory because of modules.config.publishDir in the config file.
    publish:
    // suppressing publication of splitBams for now because they would duplicate the command-specific output directories.
    // We need to decide on a strategy for publishing these files.
    unmappedBam = tag_and_split_bam_workflow.out.splitBams
    splitBamManifest = tag_and_split_bam_workflow.out.splitBamManifest
    alignedBam = align_locus_function_workflow.out.alignedBam
    alignedBai = align_locus_function_workflow.out.alignedBai
    sizeSelectedCells = align_locus_function_workflow.out.sizeSelectedCells
    sizeSelectedCellsMetrics = align_locus_function_workflow.out.sizeSelectedCellsMetrics
    dgeSummary = align_locus_function_workflow.out.dgeSummary
    singleCellRnaSeqMetrics = align_locus_function_workflow.out.singleCellRnaSeqMetrics
    // 20-transcript DGE
    dge = align_locus_function_workflow.out.dge
    sparseDgeMatrix = align_locus_function_workflow.out.sparseDgeMatrix
    sparseDgeFeatures = align_locus_function_workflow.out.sparseDgeFeatures
    sparseDgeBarcodes = align_locus_function_workflow.out.sparseDgeBarcodes
    cellFeatures = align_locus_function_workflow.out.cellFeatures

    // CBRB outputs that we care about
    cbrbH5 = cbrb_workflow.out.h5
    cbrbBarcodes = cbrb_workflow.out.barcodes
    cbrbMetrics = cbrb_workflow.out.metrics
    cbrbReport = cbrb_workflow.out.report
    cbrbPdf = cbrb_workflow.out.pdf
    cbrbLog = cbrb_workflow.out.cbrbLog
    cbrbCheckpoint = cbrb_workflow.out.checkpoint
    svmCbrbParameters = cbrb_workflow.out.svmCbrbParameters
    svmCbrbParameterEstimationPdf = cbrb_workflow.out.svmCbrbParameterEstimationPdf

    // MapMyCells outputs -- these are not currently being generated, but I want to be able to publish them when they are
    json_report = null //NEXTFLOW.out.json_report
    csv_report = null //NEXTFLOW.out.csv_report
    converted_h5ad = null //NEXTFLOW.out.converted_h5ad
}

output {
    json_report{
    }
    csv_report{
    }
    converted_h5ad{
    }
    // unmapped outputs
    unmappedBam{
    }
    splitBamManifest{
    }
    // alignment, locus function outputs
    alignedBam{
        path {meta, _file -> meta.referenceName}
    }
    alignedBai{
        path {meta, _file -> meta.referenceName}
    }
    sizeSelectedCells {
        path {meta, _file -> meta.referenceName}
    }
    sizeSelectedCellsMetrics {
        path {meta, _file -> meta.referenceName}
    }
    dgeSummary {
        path {meta, _file -> meta.referenceName}
    }
    dge {
        path {meta, _file -> meta.referenceName}
    }
    singleCellRnaSeqMetrics {
        path {meta, _file -> meta.referenceName}
    }
    sparseDgeMatrix {
        path {meta, _file -> meta.referenceName}
    }
    sparseDgeFeatures {
        path {meta, _file -> meta.referenceName}
    }
    sparseDgeBarcodes {
        path {meta, _file -> meta.referenceName}
    }
    cellFeatures {
        path {meta, _file -> meta.referenceName}
    }

    // CBRB outputs
    // TODO: should these go into a subdirectory of <reference>/cbrb/ based on the CBRB options, like Zamboni workflow?
    cbrbH5 {
        path {meta, _file -> meta.referenceName + "/cbrb/"}
    }
    cbrbBarcodes {
        path {meta, _file -> meta.referenceName + "/cbrb/"}
    }
    cbrbMetrics {
        path {meta, _file -> meta.referenceName + "/cbrb/"}
    }
    cbrbReport {
        path {meta, _file -> meta.referenceName + "/cbrb/"}
    }
    cbrbPdf {
        path {meta, _file -> meta.referenceName + "/cbrb/"}
    }
    cbrbLog {
        path {meta, _file -> meta.referenceName + "/cbrb/"}
    }
    cbrbCheckpoint {
        path {meta, _file -> meta.referenceName + "/cbrb/"}
    }
    svmCbrbParameters {
        path {meta, _file -> meta.referenceName + "/cbrb/"}
    }
    svmCbrbParameterEstimationPdf {
        path {meta, _file -> meta.referenceName + "/cbrb/"}
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
