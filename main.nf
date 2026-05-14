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
include { cell_selection_workflow } from './subworkflows/local/cell_selection.nf'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_nextflow_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_nextflow_pipeline'

// Centralize output subdirectory naming.
def alignmentDir(tuple) {
    def (meta, _file) = tuple
    return meta.referenceName + "/"
}

def cbrbDir(tuple) {
    def (meta, _file) = tuple
    return alignmentDir(tuple) + "cbrb/" + meta.cbrb_label + "/"
}

def cellSelectionDir(tuple) {
    return cbrbDir(tuple) + "cell_selection/"
}

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
    // cbrb parameters
    useSvmParameterEstimation: Boolean
    forceTwoClusterSolution: Boolean
    cbrbArgs: String
    // cell selection parameters
    minUmisPerCell: Integer
    maxUmisPerCell: Integer
    minIntronicPerCell: Float
    maxIntronicPerCell: Float

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
        align_locus_function_workflow.out.cellFeatures,
        align_locus_function_workflow.out.dge
    )
    cell_selection_workflow(
        align_locus_function_workflow.out.sparseDgeMatrix,
        align_locus_function_workflow.out.sparseDgeFeatures,
        align_locus_function_workflow.out.sparseDgeBarcodes,
        align_locus_function_workflow.out.cellFeatures,
        cbrb_workflow.out.barcodes,
        cbrb_workflow.out.numTranscripts
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

    publish:
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
    cbrbDge = cbrb_workflow.out.dge
    cbrbNumTranscripts = cbrb_workflow.out.numTranscripts
    cbrbCellFeatures = cbrb_workflow.out.cellFeatures

    // cell selection outputs that we care about
    selectedCellBarcodes = cell_selection_workflow.out.selectedCellBarcodes
    ambientCellBarcodes = cell_selection_workflow.out.ambientCellBarcodes
    cellSelectionAssignmentsPdf = cell_selection_workflow.out.cellSelectionAssignmentsPdf
    cellSelectionAssignmentsSummary = cell_selection_workflow.out.cellSelectionAssignmentsSummary
    droppedNonEmpty = cell_selection_workflow.out.droppedNonEmpty

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
        path {x -> alignmentDir(x)}
    }
    alignedBai{
        path {x -> alignmentDir(x)}
    }
    sizeSelectedCells {
        path {x -> alignmentDir(x)}
    }
    sizeSelectedCellsMetrics {
        path {x -> alignmentDir(x)}
    }
    dgeSummary {
        path {x -> alignmentDir(x)}
    }
    dge {
        path {x -> alignmentDir(x)}
    }
    singleCellRnaSeqMetrics {
        path {x -> alignmentDir(x)}
    }
    sparseDgeMatrix {
        path {x -> alignmentDir(x)}
    }
    sparseDgeFeatures {
        path {x -> alignmentDir(x)}
    }
    sparseDgeBarcodes {
        path {x -> alignmentDir(x)}
    }
    cellFeatures {
        path {x -> alignmentDir(x)}
    }

    // CBRB outputs
    // TODO: should these go into a subdirectory of <reference>/cbrb/ based on the CBRB options, like Zamboni workflow?
    cbrbH5 {
        path {x -> cbrbDir(x)}
    }
    cbrbBarcodes {
        path {x -> cbrbDir(x)}
    }
    cbrbMetrics {
        path {x -> cbrbDir(x)}
    }
    cbrbReport {
        path {x -> cbrbDir(x)}
    }
    cbrbPdf {
        path {x -> cbrbDir(x)}
    }
    cbrbLog {
        path {x -> cbrbDir(x)}
    }
    cbrbCheckpoint {
        path {x -> cbrbDir(x)}
    }
    svmCbrbParameters {
        path {x -> cbrbDir(x)}
    }
    svmCbrbParameterEstimationPdf {
        path {x -> cbrbDir(x)}
    }
    cbrbDge {
        path {x -> cbrbDir(x)}
    }
    cbrbNumTranscripts {
        path {x -> cbrbDir(x)}
    }
    cbrbCellFeatures {
        path {x -> cbrbDir(x)}
    }
    selectedCellBarcodes {
        path {x -> cellSelectionDir(x)}
    }
    ambientCellBarcodes {
        path {x -> cellSelectionDir(x)}
    }
    cellSelectionAssignmentsPdf {
        path {x -> cellSelectionDir(x)}
    }
    cellSelectionAssignmentsSummary {
        path {x -> cellSelectionDir(x)}
    }
    droppedNonEmpty {
        path {x -> cellSelectionDir(x)}
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
