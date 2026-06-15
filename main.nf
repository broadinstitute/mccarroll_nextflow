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

include { tag_and_split_bam_workflow } from './subworkflows/local/tag_and_split_bam.nf'
include { align_locus_function_workflow } from './subworkflows/local/align_locus_function.nf'
include { cbrb_workflow } from './subworkflows/local/cbrb.nf'
include { cell_selection_workflow } from './subworkflows/local/cell_selection.nf'
include { standard_analysis_workflow } from './subworkflows/local/standard_analysis.nf'
include { MapMyCells_fromSpecifiedMarkers_workflow } from './subworkflows/local/MapMyCells_fromSpecifiedMarkers.nf'
include { buildReferenceMetadataLocator } from './modules/local/ReferenceMetadataLocator.nf'
include { buildRestartInputPaths; makeCellSelectionLabel; makeCbrbLabel } from './modules/local/WorkflowPathUtil.nf'
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
    def (meta, _file) = tuple
    return cbrbDir(tuple) + "cell_selection/" + meta.cell_selection_label + "/"
}

def standardAnalysisDir(tuple) {
    // Since there should be no user choices for standard analysis, outputs could just go into cell_selection
    // directory, but put them in a subdir to reduce clutter.
    return cellSelectionDir(tuple) + "standard_analysis/"
}

def mapMyCellsDir(tuple) {
    def (meta, _file) = tuple
    return standardAnalysisDir(tuple) + "map_my_cells/" + meta.mmcModel + "/"
}

def alignmentDirFromParams() {
    return buildReferenceMetadataLocator(params.reference).referenceName + "/"
}

def validateDropulationParams() {
    if (params.vcf && !params.donorFile) {
        log.error "If providing a VCF file for demultiplexing, you must also provide a donor file with sample-to-donor mappings."
        exit 1
    }
    if (!params.vcf && params.donorFile) {
        log.error "If providing a donor file for demultiplexing, you must also provide a VCF file with genotypes."
        exit 1
    }
    if (params.donorFile && params.donor) {
        log.error "It does not make sense to provide both a donor file and a donor."
        exit 1
    }
}

def validateStartAtParam() {
    def validStages = validStartAtStages()

    if (!validStages.contains(params.start_at)) {
        log.error "--start_at must be one of: ${validStages.join(', ')}"
        exit 1
    }
}

def validStartAtStages() {
    ['beginning', 'cell_selection', 'standard_analysis']
}

def stageRank(String stageName) {
    validStartAtStages().indexOf(stageName)
}

// A stage should run when execution starts at that stage or any earlier stage.
def shouldRunStage(String startAt, String stageName) {
    stageRank(startAt) <= stageRank(stageName)
}

def restartTupleChannel(pathPattern, meta) {
    channel.fromPath(pathPattern.toString(), checkIfExists: true)
        .map { inputFile -> tuple(meta, inputFile) }
}

def restartPathChannel(pathPattern) {
    channel.fromPath(pathPattern.toString(), checkIfExists: true)
}

def restartAlignedBamChannel(pathPattern, boolean doBQSR, String referenceName) {
    channel.fromPath(pathPattern.toString(), checkIfExists: true)
        .map { bam ->
            def bamBase = doBQSR ?
                bam.getName().replaceFirst(/\.bam$/, '') :
                bam.getName().replaceFirst(/\.chimeric_marked\.bam$/, '')
            def collectIndex = bamBase.replaceFirst(/.*\./, '') as Integer
            tuple([id: bamBase, bamBase: bamBase, collectIndex: collectIndex, referenceName: referenceName], bam)
        }
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
    minUMIsPerCell: Integer
    maxUMIsPerCell: Integer
    minIntronicPerCell: Float
    maxIntronicPerCell: Float

    // standard analysis parameters
    vcf: Path
    cloudVcf: Path
    donorFile: Path
    donor: String
    assignCellsToSamplesOptions: List
    detectDoubletsOptions: List
    computeCBRBAdjustedLikelihoods: Boolean
    metaGeneDgeFunctionalStrategy: String

    // MapMyCells parameters 
    mapMyCellsQueryMarkers: Path
    mapMyCellsArgs: String

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
    start_at: String

    // nf-core infrastructure parameters
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

    validateDropulationParams()
    validateStartAtParam()

    def startAt = params.start_at
    def referenceMetadataLocator = buildReferenceMetadataLocator(params.reference)
    def referenceName = referenceMetadataLocator.referenceName
    def cbrbLabel = makeCbrbLabel(params)
    def cellSelectionLabel = makeCellSelectionLabel(params)
    def doBQSR = referenceMetadataLocator.dbSnp.exists()
    def finalMeta = [id: params.library, library: params.library, referenceName: referenceName]
    def cbrbMeta = finalMeta + [cbrb_label: cbrbLabel]
    def selectedCellsMeta = cbrbMeta + [cell_selection_label: cellSelectionLabel]
    def restartInputs = startAt == 'beginning' ? null : buildRestartInputPaths(
        params.outdir,
        referenceName,
        params.library,
        cbrbLabel,
        cellSelectionLabel,
        doBQSR
    )

    unmappedBam = channel.empty()
    splitBamManifest = channel.empty()
    alignedBam = channel.empty()
    alignedBai = channel.empty()
    sizeSelectedCells = channel.empty()
    sizeSelectedCellsMetrics = channel.empty()
    dgeSummary = channel.empty()
    chimericTranscripts = channel.empty()
    readsPerCell = channel.empty()
    singleCellRnaSeqMetrics = channel.empty()
    dge = channel.empty()
    sparseDgeMatrix = channel.empty()
    sparseDgeFeatures = channel.empty()
    sparseDgeBarcodes = channel.empty()
    cellFeatures = channel.empty()
    cbrbH5 = channel.empty()
    cbrbBarcodes = channel.empty()
    cbrbMetrics = channel.empty()
    cbrbReport = channel.empty()
    cbrbPdf = channel.empty()
    cbrbLog = channel.empty()
    cbrbCheckpoint = channel.empty()
    svmCbrbParameters = channel.empty()
    svmCbrbParameterEstimationPdf = channel.empty()
    cbrbDge = channel.empty()
    cbrbNumTranscripts = channel.empty()
    cbrbCellFeatures = channel.empty()
    selectedCellBarcodes = channel.empty()
    ambientCellBarcodes = channel.empty()
    cellSelectionAssignmentsPdf = channel.empty()
    cellSelectionAssignmentsSummary = channel.empty()
    droppedNonEmpty = channel.empty()

    //
    // WORKFLOW: Run main workflow
    //
    if (startAt == 'beginning') {
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

        unmappedBam = tag_and_split_bam_workflow.out.splitBams
        splitBamManifest = tag_and_split_bam_workflow.out.splitBamManifest
        alignedBam = align_locus_function_workflow.out.alignedBam
        alignedBai = align_locus_function_workflow.out.alignedBai
        sizeSelectedCells = align_locus_function_workflow.out.sizeSelectedCells
        sizeSelectedCellsMetrics = align_locus_function_workflow.out.sizeSelectedCellsMetrics
        dgeSummary = align_locus_function_workflow.out.dgeSummary
        chimericTranscripts = align_locus_function_workflow.out.chimericTranscripts
        readsPerCell = align_locus_function_workflow.out.readsPerCell
        singleCellRnaSeqMetrics = align_locus_function_workflow.out.singleCellRnaSeqMetrics
        dge = align_locus_function_workflow.out.dge
        sparseDgeMatrix = align_locus_function_workflow.out.sparseDgeMatrix
        sparseDgeFeatures = align_locus_function_workflow.out.sparseDgeFeatures
        sparseDgeBarcodes = align_locus_function_workflow.out.sparseDgeBarcodes
        cellFeatures = align_locus_function_workflow.out.cellFeatures

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

    }

    // Stage boundary: prepare cell-selection inputs.
    // Input source is either the canonical upstream channels or reconstructed files.
    if (shouldRunStage(startAt, 'cell_selection')) {
        if (startAt == 'cell_selection') {
            sparseDgeMatrix = restartTupleChannel(restartInputs.sparseDgeMatrix, finalMeta)
            sparseDgeFeatures = restartTupleChannel(restartInputs.sparseDgeFeatures, finalMeta)
            sparseDgeBarcodes = restartTupleChannel(restartInputs.sparseDgeBarcodes, finalMeta)
            cellFeatures = restartTupleChannel(restartInputs.cellFeatures, finalMeta)
            cbrbBarcodes = restartTupleChannel(restartInputs.cbrbBarcodes, cbrbMeta)
            cbrbNumTranscripts = restartTupleChannel(restartInputs.cbrbNumTranscripts, cbrbMeta)
            cbrbDge = restartTupleChannel(restartInputs.cbrbDge, cbrbMeta)
            cbrbCellFeatures = restartTupleChannel(restartInputs.cbrbCellFeatures, cbrbMeta)
            dgeSummary = restartTupleChannel(restartInputs.dgeSummary, finalMeta)
            chimericTranscripts = restartTupleChannel(restartInputs.chimericTranscripts, finalMeta)
            readsPerCell = restartPathChannel(restartInputs.readsPerCell)
            alignedBam = restartAlignedBamChannel(restartInputs.alignedBamPattern, doBQSR, referenceName)
        }

        // Stage execution: run cell selection as soon as its inputs are wired.
        cell_selection_workflow(
            sparseDgeMatrix,
            sparseDgeFeatures,
            sparseDgeBarcodes,
            cellFeatures,
            cbrbBarcodes,
            cbrbNumTranscripts
        )

        selectedCellBarcodes = cell_selection_workflow.out.selectedCellBarcodes
        ambientCellBarcodes = cell_selection_workflow.out.ambientCellBarcodes
        cellSelectionAssignmentsPdf = cell_selection_workflow.out.cellSelectionAssignmentsPdf
        cellSelectionAssignmentsSummary = cell_selection_workflow.out.cellSelectionAssignmentsSummary
        droppedNonEmpty = cell_selection_workflow.out.droppedNonEmpty

        // The standard-analysis handoff stays on the canonical channels already assigned above.
    }

    // Stage boundary: prepare standard-analysis inputs.
    // Input source is either the canonical handoff channels or reconstructed files.
    if (shouldRunStage(startAt, 'standard_analysis')) {
        if (startAt == 'standard_analysis') {
            selectedCellBarcodes = restartTupleChannel(restartInputs.selectedCellBarcodes, selectedCellsMeta)
            cbrbDge = restartTupleChannel(restartInputs.cbrbDge, cbrbMeta)
            cbrbCellFeatures = restartTupleChannel(restartInputs.cbrbCellFeatures, cbrbMeta)
            dgeSummary = restartTupleChannel(restartInputs.dgeSummary, finalMeta)
            chimericTranscripts = restartTupleChannel(restartInputs.chimericTranscripts, finalMeta)
            readsPerCell = restartPathChannel(restartInputs.readsPerCell)
            alignedBam = restartAlignedBamChannel(restartInputs.alignedBamPattern, doBQSR, referenceName)
        }

        // Input: either post-cell-selection handoff channels or reconstructed restart files at the standard-analysis boundary.
        // Emits: standard-analysis outputs and remains the single linear continuation point for later stages.
        standard_analysis_workflow(
            selectedCellBarcodes,
            cbrbDge,
            dgeSummary,
            alignedBam,
            chimericTranscripts,
            cbrbCellFeatures,
            readsPerCell
        )
    }
    if (params.mapMyCellsQueryMarkers) {
        MapMyCells_fromSpecifiedMarkers_workflow(
            standard_analysis_workflow.out.sparseDgeMatrix,
            standard_analysis_workflow.out.sparseDgeFeatures,
            standard_analysis_workflow.out.sparseDgeBarcodes
        )
        mapMyCellsJsonReport = MapMyCells_fromSpecifiedMarkers_workflow.out.json_report
        mapMyCellsCsvReport = MapMyCells_fromSpecifiedMarkers_workflow.out.csv_report
    } else {
        mapMyCellsJsonReport = channel.empty()
        mapMyCellsCsvReport = channel.empty()
    }

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
    unmappedBam = unmappedBam
    splitBamManifest = splitBamManifest
    unmappedProperties = tag_and_split_bam_workflow.out.properties
    alignedBam = alignedBam
    alignedBai = alignedBai
    sizeSelectedCells = sizeSelectedCells
    sizeSelectedCellsMetrics = sizeSelectedCellsMetrics
    dgeSummary = dgeSummary
    chimericTranscripts = chimericTranscripts
    readsPerCell = readsPerCell
    singleCellRnaSeqMetrics = singleCellRnaSeqMetrics
    dge = dge
    sparseDgeMatrix = sparseDgeMatrix
    sparseDgeFeatures = sparseDgeFeatures
    sparseDgeBarcodes = sparseDgeBarcodes
    cellFeatures = cellFeatures
    alignmentProperties = align_locus_function_workflow.out.properties

    cbrbH5 = cbrbH5
    cbrbBarcodes = cbrbBarcodes
    cbrbMetrics = cbrbMetrics
    cbrbReport = cbrbReport
    cbrbPdf = cbrbPdf
    cbrbLog = cbrbLog
    cbrbCheckpoint = cbrbCheckpoint
    svmCbrbParameters = svmCbrbParameters
    svmCbrbParameterEstimationPdf = svmCbrbParameterEstimationPdf
    cbrbDge = cbrbDge
    cbrbNumTranscripts = cbrbNumTranscripts
    cbrbCellFeatures = cbrbCellFeatures
    cbrbProperties = cbrb_workflow.out.properties

    selectedCellBarcodes = selectedCellBarcodes
    ambientCellBarcodes = ambientCellBarcodes
    cellSelectionAssignmentsPdf = cellSelectionAssignmentsPdf
    cellSelectionAssignmentsSummary = cellSelectionAssignmentsSummary
    droppedNonEmpty = droppedNonEmpty

    // standrd analysis outputs that we care about
    selectedDge = standard_analysis_workflow.out.dge
    selectedDgeSummary = standard_analysis_workflow.out.dgeSummary
    selectedSparseDgeMatrix = standard_analysis_workflow.out.sparseDgeMatrix
    selectedSparseDgeFeatures = standard_analysis_workflow.out.sparseDgeFeatures
    selectedSparseDgeBarcodes = standard_analysis_workflow.out.sparseDgeBarcodes
    umiReadIntervals = standard_analysis_workflow.out.umiReadIntervals
    molBc = standard_analysis_workflow.out.molBc
    umiSaturationHistogram = standard_analysis_workflow.out.umiSaturationHistogram
    digitalAlleleFrequencies = standard_analysis_workflow.out.digitalAlleleFrequencies
    donorAssignments = standard_analysis_workflow.out.donorAssignments
    doubletAssignments = standard_analysis_workflow.out.doubletAssignments
    donorList = standard_analysis_workflow.out.donorList
    donorCellMap = standard_analysis_workflow.out.donorCellMap
    donorAssignmentSummaryStats = standard_analysis_workflow.out.donorAssignmentSummaryStats
    donorAssignmentTearSheet = standard_analysis_workflow.out.donorAssignmentTearSheet
    donorCellBarcodes = standard_analysis_workflow.out.donorCellBarcodes
    donorAssignmentPdf = standard_analysis_workflow.out.donorAssignmentPdf
    donorDge = standard_analysis_workflow.out.donorDge
    donorDgeSummary = standard_analysis_workflow.out.donorDgeSummary
    metacells = standard_analysis_workflow.out.metacells
    metacellMetrics = standard_analysis_workflow.out.metacellMetrics
    metageneReport = standard_analysis_workflow.out.metageneReport
    metageneDge = standard_analysis_workflow.out.metageneDge
    metageneDgeSummary = standard_analysis_workflow.out.metageneDgeSummary
    gmgDge = standard_analysis_workflow.out.gmgDge
    gmgDgeSummary = standard_analysis_workflow.out.gmgDgeSummary

    // MapMyCells outputs -- these are not currently being generated, but I want to be able to publish them when they are
    mapMyCellsJsonReport = mapMyCellsJsonReport
    mapMyCellsCsvReport = mapMyCellsCsvReport
}

output {
    // unmapped outputs
    unmappedBam{
    }
    splitBamManifest{
    }
    unmappedProperties {
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
    chimericTranscripts {
        path {x -> alignmentDir(x)}
    }
    readsPerCell {
        path { alignmentDirFromParams() }
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
    alignmentProperties {
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
    cbrbProperties {
        path {x -> cbrbDir(x)}
    }

    // cell selection outputs
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

    // standard analysis outputs
    selectedDge {
        path {x -> standardAnalysisDir(x)}
    }
    selectedDgeSummary {
        path {x -> standardAnalysisDir(x)}
    }
    selectedSparseDgeMatrix {
        path {x -> standardAnalysisDir(x)}
    }
    selectedSparseDgeFeatures {
        path {x -> standardAnalysisDir(x)}  
    }
    selectedSparseDgeBarcodes {
        path {x -> standardAnalysisDir(x)}
    }
    umiReadIntervals {
        path {x -> standardAnalysisDir(x)}
    }
    molBc {
        path {x -> standardAnalysisDir(x)}
    }
    umiSaturationHistogram {
        path {x -> standardAnalysisDir(x)}
    }
    digitalAlleleFrequencies {
        path {x -> standardAnalysisDir(x)}
    }
    donorAssignments {
        path {x -> standardAnalysisDir(x)}
    }
    doubletAssignments {
        path {x -> standardAnalysisDir(x)}
    }
    donorList {
        path {x -> standardAnalysisDir(x)}
    }
    donorCellMap {
        path {x -> standardAnalysisDir(x)}
    }
    donorAssignmentSummaryStats {
        path {x -> standardAnalysisDir(x)}
    }
    donorAssignmentTearSheet {
        path {x -> standardAnalysisDir(x)}
    }
    donorCellBarcodes {
        path {x -> standardAnalysisDir(x)}
    }
    donorAssignmentPdf {
        path {x -> standardAnalysisDir(x)}
    }
    donorDge {
        path {x -> standardAnalysisDir(x)}
    }
    donorDgeSummary {
        path {x -> standardAnalysisDir(x)}
    }
    metacells {
        path {x -> standardAnalysisDir(x)}
    }
    metacellMetrics {
        path {x -> standardAnalysisDir(x)}
    }
    metageneReport {
        path {x -> standardAnalysisDir(x)}
    }
    metageneDge {
        path {x -> standardAnalysisDir(x)}
    }
    metageneDgeSummary {
        path {x -> standardAnalysisDir(x)}
    }
    gmgDge {
        path {x -> standardAnalysisDir(x)}
    }
    gmgDgeSummary {
        path {x -> standardAnalysisDir(x)}
    }
    mapMyCellsJsonReport {
        path {x -> mapMyCellsDir(x)}
    }
    mapMyCellsCsvReport {
        path {x -> mapMyCellsDir(x)}
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
