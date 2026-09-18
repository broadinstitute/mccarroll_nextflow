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

include { tag_and_split_bam_workflow               } from './subworkflows/local/tag_and_split_bam.nf'
include { align_locus_function_workflow            } from './subworkflows/local/align_locus_function.nf'
include { cbrb_workflow                            } from './subworkflows/local/cbrb.nf'
include { cell_selection_workflow                  } from './subworkflows/local/cell_selection.nf'
include { standard_analysis_workflow               } from './subworkflows/local/standard_analysis.nf'
include { dropulation_workflow                     } from './subworkflows/local/dropulation.nf'
include { MapMyCells_fromSpecifiedMarkers_workflow } from './subworkflows/local/MapMyCells_fromSpecifiedMarkers.nf'
include { buildReferenceMetadataLocator            } from './modules/local/ReferenceMetadataLocator.nf'
include { buildRestartInputPaths ; makeCellSelectionLabel ; makeCbrbLabel } from './modules/local/WorkflowPathUtil.nf'
include { PIPELINE_INITIALISATION                  } from './subworkflows/local/utils_nfcore_nextflow_pipeline'
include { PIPELINE_COMPLETION                      } from './subworkflows/local/utils_nfcore_nextflow_pipeline'
include { alignmentDir ; cbrbDir ; cellSelectionDir ; standardAnalysisDir ; dropulationDir ; mapMyCellsDir } from './modules/local/DirectoryUtil.nf'
include { hasExtension; withoutExtension } from './modules/local/FileUtil.nf'
params {
    allowedBarcodes: Path?
    library: String
    experimentDate: String?
    reference: Path?
    cloudReference: Path?
    fastq_read1: List<String> = []
    fastq_read2: List<String> = []
    rawBam: List<String> = []
    version10X: String?
    beadStructure: String?

    // cbrb parameters
    useSvmParameterEstimation: Boolean = true
    forceTwoClusterSolution: Boolean = false
    cbrbArgs: String = ''

    // cell selection parameters
    minUMIsPerCell: Integer?
    maxUMIsPerCell: Integer?
    minIntronicPerCell: Float?
    maxIntronicPerCell: Float?

    // standard analysis parameters
    vcf: Path?
    cloudVcf: Path?
    donorFile: Path?
    donor: String?
    assignCellsToSamplesOptions: List<String> = []
    detectDoubletsOptions: List<String> = []
    computeCBRBAdjustedLikelihoods: Boolean = true
    // if null, set to value of dgeFunctionalStrategy
    metaGeneDgeFunctionalStrategy: String?
    

    // MapMyCells parameters 
    mapMyCellsQueryMarkers: Path?
    mapMyCellsArgs: String = ''

    // defaults
    cellBarcodeTag: String = 'XC'
    molecularBarcodeTag: String = 'XM'
    targetBamSizeMBytes: Integer = 2048
    fivePrimeAdapter: String = 'AAGCAGTGGTATCAACGCAGAGTACATGGG'
    strandStrategy: String = 'SENSE'
    locusFunction: String = 'EXONIC_INTRONIC'
    minimumTranscriptsPerCell: Integer = 20
    dgeMinReadMq: Integer = 10
    dgeFunctionalStrategy: String = 'DROPSEQ'

    // infrastructure parameters
    start_at: String = 'beginning'

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
    PIPELINE_INITIALISATION(
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.help,
        params.help_full,
        params.show_hidden,
    )

    validateDropulationParams()
    validateStartAtParam()

    def startAt = params.start_at
    def referenceMetadataLocator = buildReferenceMetadataLocator(params.reference)
    def referenceName = referenceMetadataLocator.referenceName
    def cbrbLabel = makeCbrbLabel(params)
    def cellSelectionLabel = makeCellSelectionLabel(params)
    def finalMeta = [id: params.library, library: params.library, referenceName: referenceName]
    def cbrbMeta = finalMeta + [cbrb_label: cbrbLabel]
    def selectedCellsMeta = cbrbMeta + [cell_selection_label: cellSelectionLabel]
    def restartInputs = startAt == 'beginning'
        ? null
        : buildRestartInputPaths(
            params.outdir,
            referenceName,
            params.library,
            cbrbLabel,
            cellSelectionLabel,
        )



    //
    // WORKFLOW: Run main workflow
    //
    if (shouldRunStage(startAt, 'beginning')) {
        tag_and_split_bam_workflow(
            params.fastq_read1,
            params.fastq_read2,
            params.rawBam,
            params.library,
            params.beadStructure,
            params.allowedBarcodes,
        )
        unmappedBam = tag_and_split_bam_workflow.out.splitBams
        splitBamManifest = tag_and_split_bam_workflow.out.splitBamManifest
        correctedBarcodeMetrics = tag_and_split_bam_workflow.out.correctedBarcodeMetrics
        barcodeCounts = tag_and_split_bam_workflow.out.barcodeCounts
        unmappedProperties = tag_and_split_bam_workflow.out.properties
    } else {
        unmappedBam = restartPathChannel(restartInputs.unmappedBamPattern)
        // don't populate because not needed downstream
        splitBamManifest = channel.empty()
        unmappedProperties = channel.empty()
        correctedBarcodeMetrics = channel.empty()
        barcodeCounts = channel.empty()
    }
    if (shouldRunStage(startAt, 'alignment')) {
        align_locus_function_workflow(
            unmappedBam,
            params.beadStructure,
        )
        alignedBam = align_locus_function_workflow.out.alignedBam
        alignedBai = align_locus_function_workflow.out.alignedBai
        sizeSelectedCells = align_locus_function_workflow.out.sizeSelectedCells
        sizeSelectedCellsMetrics = align_locus_function_workflow.out.sizeSelectedCellsMetrics
        dgeSummary = align_locus_function_workflow.out.dgeSummary
        chimericTranscripts = align_locus_function_workflow.out.chimericTranscripts
        chimericReadMetrics = align_locus_function_workflow.out.chimericReadMetrics
        readsPerCell = align_locus_function_workflow.out.readsPerCell
        singleCellRnaSeqMetrics = align_locus_function_workflow.out.singleCellRnaSeqMetrics
        dge = align_locus_function_workflow.out.dge
        sparseDgeMatrix = align_locus_function_workflow.out.sparseDgeMatrix
        sparseDgeFeatures = align_locus_function_workflow.out.sparseDgeFeatures
        sparseDgeBarcodes = align_locus_function_workflow.out.sparseDgeBarcodes
        cellFeatures = align_locus_function_workflow.out.cellFeatures
        readQualityMetrics = align_locus_function_workflow.out.readQualityMetrics
        rnaSeqMetrics = align_locus_function_workflow.out.rnaSeqMetrics
        alignmentSummaryPdf = align_locus_function_workflow.out.alignmentSummaryPdf
        alignmentProperties = align_locus_function_workflow.out.properties
    } else {
        alignedBam = restartAlignedBamChannel(restartInputs.alignedBamPattern, referenceName)
        alignedBai = channel.empty()
        sizeSelectedCells = channel.empty()
        sizeSelectedCellsMetrics = channel.empty()
        dgeSummary = restartTupleChannel(restartInputs.dgeSummary, finalMeta)
        chimericTranscripts = restartTupleChannel(restartInputs.chimericTranscripts, finalMeta)
        chimericReadMetrics = channel.empty()
        readsPerCell = restartTupleChannel(restartInputs.readsPerCell, finalMeta)
        singleCellRnaSeqMetrics = channel.empty()
        dge = restartTupleChannel(restartInputs.dge, finalMeta)
        sparseDgeMatrix = restartTupleChannel(restartInputs.sparseDgeMatrix, finalMeta)
        sparseDgeFeatures = restartTupleChannel(restartInputs.sparseDgeFeatures, finalMeta)
        sparseDgeBarcodes = restartTupleChannel(restartInputs.sparseDgeBarcodes, finalMeta)
        cellFeatures = restartTupleChannel(restartInputs.cellFeatures, finalMeta)
        readQualityMetrics = restartTupleChannel(restartInputs.readQualityMetrics, finalMeta)
        rnaSeqMetrics = channel.empty()
        alignmentSummaryPdf = channel.empty()
        alignmentProperties = channel.empty()
    }
    if (shouldRunStage(startAt, 'cbrb')) {
        cbrb_workflow(
            sparseDgeMatrix,
            sparseDgeFeatures,
            sparseDgeBarcodes,
            cellFeatures,
            dge,
            readQualityMetrics,
        )


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
        cbrbProperties = cbrb_workflow.out.properties
        cbrbTearSheet = cbrb_workflow.out.cbrbTearSheet
    } else {
        cbrbBarcodes = restartTupleChannel(restartInputs.cbrbBarcodes, cbrbMeta)
        cbrbNumTranscripts = restartTupleChannel(restartInputs.cbrbNumTranscripts, cbrbMeta)
        cbrbDge = restartTupleChannel(restartInputs.cbrbDge, cbrbMeta)
        cbrbCellFeatures = restartTupleChannel(restartInputs.cbrbCellFeatures, cbrbMeta)
        cbrbH5 = channel.empty()
        cbrbMetrics = channel.empty()
        cbrbReport = channel.empty()
        cbrbPdf = channel.empty()
        cbrbLog = channel.empty()
        cbrbCheckpoint = channel.empty()
        svmCbrbParameters = channel.empty()
        svmCbrbParameterEstimationPdf = channel.empty()
        cbrbProperties = channel.empty()
        cbrbTearSheet = channel.empty()
    }

    // Stage boundary: prepare cell-selection inputs.
    // Input source is either the canonical upstream channels or reconstructed files.
    if (shouldRunStage(startAt, 'cell_selection')) {
        // Stage execution: run cell selection as soon as its inputs are wired.
        cell_selection_workflow(
            sparseDgeMatrix,
            sparseDgeFeatures,
            sparseDgeBarcodes,
            cellFeatures,
            cbrbBarcodes,
            cbrbNumTranscripts,
        )

        selectedCellBarcodes = cell_selection_workflow.out.selectedCellBarcodes
        ambientCellBarcodes = cell_selection_workflow.out.ambientCellBarcodes
        cellSelectionAssignmentsPdf = cell_selection_workflow.out.cellSelectionAssignmentsPdf
        cellSelectionAssignmentsSummary = cell_selection_workflow.out.cellSelectionAssignmentsSummary
        droppedNonEmpty = cell_selection_workflow.out.droppedNonEmpty
        cellSelectionProperties = cell_selection_workflow.out.properties
    } else {
        selectedCellBarcodes = restartTupleChannel(restartInputs.selectedCellBarcodes, selectedCellsMeta)
        ambientCellBarcodes = channel.empty()
        cellSelectionAssignmentsPdf = channel.empty()
        cellSelectionAssignmentsSummary = channel.empty()
        droppedNonEmpty = channel.empty()
        cellSelectionProperties = channel.empty()
    }

    if (shouldRunStage(startAt, 'standard_analysis')) {
        standard_analysis_workflow(
            selectedCellBarcodes,
            cbrbDge,
            dgeSummary,
            alignedBam,
            chimericTranscripts,
            cbrbCellFeatures,
        )
        selectedDge                     = standard_analysis_workflow.out.dge
        selectedDgeSummary              = standard_analysis_workflow.out.dgeSummary
        selectedSparseDgeMatrix         = standard_analysis_workflow.out.sparseDgeMatrix
        selectedSparseDgeFeatures       = standard_analysis_workflow.out.sparseDgeFeatures
        selectedSparseDgeBarcodes       = standard_analysis_workflow.out.sparseDgeBarcodes
        umiReadIntervals                = standard_analysis_workflow.out.umiReadIntervals
        molBc                           = standard_analysis_workflow.out.molBc
        doubletCalls                    = standard_analysis_workflow.out.doubletCalls
        standardAnalysisCellMetadata    = standard_analysis_workflow.out.cellMetadata
        metacells                       = standard_analysis_workflow.out.metacells
        metacellMetrics                 = standard_analysis_workflow.out.metacellMetrics
        metageneReport                  = standard_analysis_workflow.out.metageneReport
        metageneDge                     = standard_analysis_workflow.out.metageneDge
        metageneDgeSummary              = standard_analysis_workflow.out.metageneDgeSummary
        gmgDge                          = standard_analysis_workflow.out.gmgDge
        gmgDgeSummary                   = standard_analysis_workflow.out.gmgDgeSummary
        standardAnalysisProperties      = standard_analysis_workflow.out.properties
        standardAnalysisPdf             = standard_analysis_workflow.out.standardAnalysisPdf
        umiSaturationMetrics            = standard_analysis_workflow.out.umiSaturationMetrics
        sexCalls                        = standard_analysis_workflow.out.sexCalls
        sexPdf                          = standard_analysis_workflow.out.sexPdf

    } else {
        selectedDge = restartTupleChannel(restartInputs.selectedDge, selectedCellsMeta)
        selectedDgeSummary = restartTupleChannel(restartInputs.selectedDgeSummary, selectedCellsMeta)
        doubletCalls = restartTupleChannel(restartInputs.doubletCalls, selectedCellsMeta)
        selectedSparseDgeMatrix = restartTupleChannel(restartInputs.selectedSparseDgeMatrix, selectedCellsMeta)
        selectedSparseDgeFeatures = restartTupleChannel(restartInputs.selectedSparseDgeFeatures, selectedCellsMeta)
        selectedSparseDgeBarcodes = restartTupleChannel(restartInputs.selectedSparseDgeBarcodes, selectedCellsMeta)
        umiReadIntervals                = channel.empty()
        molBc                           = channel.empty()
        standardAnalysisCellMetadata    = channel.empty()
        metacells                       = channel.empty()
        metacellMetrics                 = channel.empty()
        metageneReport                  = channel.empty()
        metageneDge                     = channel.empty()
        metageneDgeSummary              = channel.empty()
        gmgDge                          = channel.empty()
        gmgDgeSummary                   = channel.empty()
        standardAnalysisProperties      = channel.empty()
        standardAnalysisPdf             = channel.empty()
        umiSaturationMetrics            = channel.empty()
        sexCalls                        = channel.empty()
        sexPdf                          = channel.empty()
    }
    if (params.vcf && shouldRunStage(startAt, 'dropulation')) {
        dropulation_workflow(
            selectedCellBarcodes,
            alignedBam,
            cbrbCellFeatures,
            selectedDge,
            selectedDgeSummary,
            dgeSummary,
            readsPerCell,
            doubletCalls,
        )
        // dropulation outputs
        dropulationProperties = dropulation_workflow.out.dropulationProperties
        digitalAlleleFrequencies = dropulation_workflow.out.digitalAlleleFrequencies
        donorAssignments = dropulation_workflow.out.donorAssignments
        doubletAssignments = dropulation_workflow.out.doubletAssignments
        donorList = dropulation_workflow.out.donorList
        donorCellMap = dropulation_workflow.out.donorCellMap
        donorAssignmentSummaryStats = dropulation_workflow.out.donorAssignmentSummaryStats
        donorAssignmentTearSheet = dropulation_workflow.out.donorAssignmentTearSheet
        donorCellBarcodes = dropulation_workflow.out.donorCellBarcodes
        donorAssignmentPdf = dropulation_workflow.out.donorAssignmentPdf
        donorDge = dropulation_workflow.out.donorDge
        donorDgeSummary = dropulation_workflow.out.donorDgeSummary
        donorCellMetadata = dropulation_workflow.out.cellMetadata
        donorMetacells = dropulation_workflow.out.metacells
        donorMetacellMetrics = dropulation_workflow.out.metacellMetrics
        donorSexCalls = dropulation_workflow.out.donorSexCalls
        donorSexPdf = dropulation_workflow.out.donorSexPdf
    }
    else {
        dropulationProperties = channel.empty()
        digitalAlleleFrequencies = channel.empty()
        donorAssignments = channel.empty()
        doubletAssignments = channel.empty()
        donorList = channel.empty()
        donorCellMap = channel.empty()
        donorAssignmentSummaryStats = channel.empty()
        donorAssignmentTearSheet = channel.empty()
        donorCellBarcodes = channel.empty()
        donorAssignmentPdf = channel.empty()
        donorDge = channel.empty()
        donorDgeSummary = channel.empty()
        donorCellMetadata = channel.empty()
        donorMetacells = channel.empty()
        donorMetacellMetrics = channel.empty()
        donorSexCalls = channel.empty()
        donorSexPdf = channel.empty()
    }
    if (params.mapMyCellsQueryMarkers && shouldRunStage(startAt, 'mmc')) {
        MapMyCells_fromSpecifiedMarkers_workflow(
            selectedSparseDgeMatrix,
            selectedSparseDgeFeatures,
            selectedSparseDgeBarcodes,
        )
        mapMyCellsJsonReport = MapMyCells_fromSpecifiedMarkers_workflow.out.json_report
        mapMyCellsCsvReport = MapMyCells_fromSpecifiedMarkers_workflow.out.csv_report
        mapMyCellsProperties = MapMyCells_fromSpecifiedMarkers_workflow.out.properties
        mapMyCellsCellTypeCounts = MapMyCells_fromSpecifiedMarkers_workflow.out.cellTypeCounts
    }
    else {
        mapMyCellsJsonReport = channel.empty()
        mapMyCellsCsvReport = channel.empty()
        mapMyCellsProperties = channel.empty()
        mapMyCellsCellTypeCounts = channel.empty()
    }
    channel.topic('versions')
        .map { _process, name, version -> "${name}: ${version}" }
        .unique()
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: "software_versions_${params.trace_report_suffix}.yml",
            newLine: true,
            sort: true,
        )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION(
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
    )

    publish:
    // unmapped BAM outputs
    unmappedBam                     = unmappedBam
    splitBamManifest                = splitBamManifest
    correctedBarcodeMetrics         = correctedBarcodeMetrics
    barcodeCounts                   = barcodeCounts
    unmappedProperties              = unmappedProperties

    // aligned BAM outputs
    alignedBam                      = alignedBam
    alignedBai                      = alignedBai
    sizeSelectedCells               = sizeSelectedCells
    sizeSelectedCellsMetrics        = sizeSelectedCellsMetrics
    dgeSummary                      = dgeSummary
    chimericTranscripts             = chimericTranscripts
    chimericReadMetrics             = chimericReadMetrics
    // These two are published only for the purpose of start_at != beginning
    readsPerCell                    = readsPerCell
    dge                             = dge
    singleCellRnaSeqMetrics         = singleCellRnaSeqMetrics
    sparseDgeMatrix                 = sparseDgeMatrix
    sparseDgeFeatures               = sparseDgeFeatures
    sparseDgeBarcodes               = sparseDgeBarcodes
    cellFeatures                    = cellFeatures
    alignmentProperties             = alignmentProperties
    readQualityMetrics              = readQualityMetrics
    rnaSeqMetrics                   = rnaSeqMetrics
    alignmentSummaryPdf             = alignmentSummaryPdf
    cbrbH5                          = cbrbH5
    cbrbBarcodes                    = cbrbBarcodes
    cbrbMetrics                     = cbrbMetrics
    cbrbReport                      = cbrbReport
    cbrbPdf                         = cbrbPdf
    cbrbLog                         = cbrbLog
    cbrbCheckpoint                  = cbrbCheckpoint
    svmCbrbParameters               = svmCbrbParameters
    svmCbrbParameterEstimationPdf   = svmCbrbParameterEstimationPdf
    cbrbDge                         = cbrbDge
    cbrbNumTranscripts              = cbrbNumTranscripts
    cbrbCellFeatures                = cbrbCellFeatures
    cbrbTearSheet                   = cbrbTearSheet
    cbrbProperties                  = cbrbProperties
    selectedCellBarcodes            = selectedCellBarcodes
    ambientCellBarcodes             = ambientCellBarcodes
    cellSelectionAssignmentsPdf     = cellSelectionAssignmentsPdf
    cellSelectionAssignmentsSummary = cellSelectionAssignmentsSummary
    droppedNonEmpty                 = droppedNonEmpty
    cellSelectionProperties         = cellSelectionProperties

    // standrd analysis outputs that we care about
    selectedDge                     = selectedDge
    selectedDgeSummary              = selectedDgeSummary
    selectedSparseDgeMatrix         = selectedSparseDgeMatrix
    selectedSparseDgeFeatures       = selectedSparseDgeFeatures
    selectedSparseDgeBarcodes       = selectedSparseDgeBarcodes
    umiReadIntervals                = umiReadIntervals
    molBc                           = molBc
    doubletCalls                     = doubletCalls
    // don't care about umi saturation histogram
    //umiSaturationHistogram = standard_analysis_workflow.out.umiSaturationHistogram
    standardAnalysisCellMetadata    = standardAnalysisCellMetadata
    metacells                       = metacells
    metacellMetrics                 = metacellMetrics
    metageneReport                  = metageneReport
    metageneDge                     = metageneDge
    metageneDgeSummary              = metageneDgeSummary
    gmgDge                          = gmgDge
    gmgDgeSummary                   = gmgDgeSummary
    standardAnalysisProperties      = standardAnalysisProperties
    standardAnalysisPdf             = standardAnalysisPdf
    umiSaturationMetrics            = umiSaturationMetrics
    sexCalls                        = sexCalls
    sexPdf                          = sexPdf

    // dropulation outputs
    dropulationProperties           = dropulationProperties
    digitalAlleleFrequencies        = digitalAlleleFrequencies
    donorAssignments                = donorAssignments
    doubletAssignments              = doubletAssignments
    donorList                       = donorList
    donorCellMap                    = donorCellMap
    donorAssignmentSummaryStats     = donorAssignmentSummaryStats
    donorAssignmentTearSheet        = donorAssignmentTearSheet
    donorCellBarcodes               = donorCellBarcodes
    donorAssignmentPdf              = donorAssignmentPdf
    donorDge                        = donorDge
    donorDgeSummary                 = donorDgeSummary
    donorCellMetadata               = donorCellMetadata
    donorSexCalls                   = donorSexCalls
    donorSexPdf                     = donorSexPdf
    donorMetacells                  = donorMetacells
    donorMetacellMetrics            = donorMetacellMetrics
 
    // MapMyCells outputs
    mapMyCellsJsonReport            = mapMyCellsJsonReport
    mapMyCellsCsvReport             = mapMyCellsCsvReport
    mapMyCellsProperties            = mapMyCellsProperties
    mapMyCellsCellTypeCounts          = mapMyCellsCellTypeCounts
}

output {
    // unmapped outputs
    unmappedBam {
    }
    splitBamManifest {
    }
    correctedBarcodeMetrics {
    }
    barcodeCounts {
    }
    unmappedProperties {
    }
    // alignment, locus function outputs
    alignedBam {
        path { x -> alignmentDir(x) }
    }
    alignedBai {
        path { x -> alignmentDir(x) }
    }
    sizeSelectedCells {
        path { x -> alignmentDir(x) }
    }
    sizeSelectedCellsMetrics {
        path { x -> alignmentDir(x) }
    }
    dgeSummary {
        path { x -> alignmentDir(x) }
    }
    chimericTranscripts {
        path { x -> alignmentDir(x) }
    }
    chimericReadMetrics {
        path { x -> alignmentDir(x) }
    }
    /*
     * published so that can start_at > beginning
    */
    readsPerCell {
        path { x -> alignmentDir(x) }
    }
    /* 
     * published so that can start_at > beginning
    */
    dge {
        path { x -> alignmentDir(x) }
    }
    singleCellRnaSeqMetrics {
        path { x -> alignmentDir(x) }
    }
    sparseDgeMatrix {
        path { x -> alignmentDir(x) }
    }
    sparseDgeFeatures {
        path { x -> alignmentDir(x) }
    }
    sparseDgeBarcodes {
        path { x -> alignmentDir(x) }
    }
    cellFeatures {
        path { x -> alignmentDir(x) }
    }
    alignmentProperties {
        path { x -> alignmentDir(x) }
    }
    readQualityMetrics {
        path { x -> alignmentDir(x) }
    }
    rnaSeqMetrics {
        path { x -> alignmentDir(x) }
    }
    alignmentSummaryPdf {
        path { x -> alignmentDir(x) }
    }

    // CBRB outputs
    cbrbH5 {
        path { x -> cbrbDir(x) }
    }
    cbrbBarcodes {
        path { x -> cbrbDir(x) }
    }
    cbrbMetrics {
        path { x -> cbrbDir(x) }
    }
    cbrbReport {
        path { x -> cbrbDir(x) }
    }
    cbrbPdf {
        path { x -> cbrbDir(x) }
    }
    cbrbLog {
        path { x -> cbrbDir(x) }
    }
    cbrbCheckpoint {
        path { x -> cbrbDir(x) }
    }
    svmCbrbParameters {
        path { x -> cbrbDir(x) }
    }
    svmCbrbParameterEstimationPdf {
        path { x -> cbrbDir(x) }
    }
    cbrbDge {
        path { x -> cbrbDir(x) }
    }
    cbrbNumTranscripts {
        path { x -> cbrbDir(x) }
    }
    cbrbCellFeatures {
        path { x -> cbrbDir(x) }
    }
    cbrbTearSheet {
        path { x -> cbrbDir(x) }
    }
    cbrbProperties {
        path { x -> cbrbDir(x) }
    }

    // cell selection outputs
    selectedCellBarcodes {
        path { x -> cellSelectionDir(x) }
    }
    ambientCellBarcodes {
        path { x -> cellSelectionDir(x) }
    }
    cellSelectionAssignmentsPdf {
        path { x -> cellSelectionDir(x) }
    }
    cellSelectionAssignmentsSummary {
        path { x -> cellSelectionDir(x) }
    }
    droppedNonEmpty {
        path { x -> cellSelectionDir(x) }
    }
    cellSelectionProperties {
        path { x -> cellSelectionDir(x) }
    }

    // standard analysis outputs
    selectedDge {
        path { x -> standardAnalysisDir(x) }
    }
    selectedDgeSummary {
        path { x -> standardAnalysisDir(x) }
    }
    selectedSparseDgeMatrix {
        path { x -> standardAnalysisDir(x) }
    }
    selectedSparseDgeFeatures {
        path { x -> standardAnalysisDir(x) }
    }
    selectedSparseDgeBarcodes {
        path { x -> standardAnalysisDir(x) }
    }
    umiReadIntervals {
        path { x -> standardAnalysisDir(x) }
    }
    molBc {
        path { x -> standardAnalysisDir(x) }
    }
    doubletCalls {
        // only published because needed for downstream analysis
        path { x -> standardAnalysisDir(x) }
    }
    metacells {
        path { x -> standardAnalysisDir(x) }
    }
    metacellMetrics {
        path { x -> standardAnalysisDir(x) }
    }
    metageneReport {
        path { x -> standardAnalysisDir(x) }
    }
    metageneDge {
        path { x -> standardAnalysisDir(x) }
    }
    metageneDgeSummary {
        path { x -> standardAnalysisDir(x) }
    }
    gmgDge {
        path { x -> standardAnalysisDir(x) }
    }
    gmgDgeSummary {
        path { x -> standardAnalysisDir(x) }
    }
    standardAnalysisProperties {
        path { x -> standardAnalysisDir(x) }
    }
    standardAnalysisPdf {
        path { x -> standardAnalysisDir(x) }
    }
    umiSaturationMetrics {
        path { x -> standardAnalysisDir(x) }
    }
    sexCalls {
        path { x -> standardAnalysisDir(x) }
    }
    sexPdf {
        path { x -> standardAnalysisDir(x) }
    }
    standardAnalysisCellMetadata {
        path { x -> standardAnalysisDir(x) }
    }
    // don't care about umi saturation histogram
    /*
    umiSaturationHistogram {
        path {x -> standardAnalysisDir(x)}
    }
    */
    digitalAlleleFrequencies {
        path { x -> dropulationDir(x) }
    }
    donorMetacells {
        path { x -> dropulationDir(x) }
    }
    donorMetacellMetrics {
        path { x -> dropulationDir(x) }
    }
    donorAssignments {
        path { x -> dropulationDir(x) }
    }
    doubletAssignments {
        path { x -> dropulationDir(x) }
    }
    donorList {
        path { x -> dropulationDir(x) }
    }
    donorCellMap {
        path { x -> dropulationDir(x) }
    }
    donorAssignmentSummaryStats {
        path { x -> dropulationDir(x) }
    }
    donorAssignmentTearSheet {
        path { x -> dropulationDir(x) }
    }
    donorCellBarcodes {
        path { x -> dropulationDir(x) }
    }
    donorAssignmentPdf {
        path { x -> dropulationDir(x) }
    }
    donorDge {
        path { x -> dropulationDir(x) }
    }
    donorDgeSummary {
        path { x -> dropulationDir(x) }
    }
    donorCellMetadata {
        path { x -> dropulationDir(x) }
    }
    donorSexCalls {
        path { x -> dropulationDir(x) }
    }
    donorSexPdf {
        path { x -> dropulationDir(x) }
    }
    dropulationProperties {
        path { x -> dropulationDir(x) }
    }
    mapMyCellsJsonReport {
        path { x -> mapMyCellsDir(x) }
    }
    mapMyCellsCsvReport {
        path { x -> mapMyCellsDir(x) }
    }
    mapMyCellsProperties {
        path { x -> mapMyCellsDir(x) }
    }
    mapMyCellsCellTypeCounts {
        path { x -> mapMyCellsDir(x) }
    }
}

def alignmentDirFromParams() {
    return buildReferenceMetadataLocator(params.reference).referenceName + "/"
}

def validateDropulationParams() {
    if (params.vcf && !params.donorFile) {
        error("If providing a VCF file for demultiplexing, you must also provide a donor file with sample-to-donor mappings.")
    }
    if (!params.vcf && params.donorFile) {
        error("If providing a donor file for demultiplexing, you must also provide a VCF file with genotypes.")
    }
    if (params.donorFile && params.donor) {
        error("It does not make sense to provide both a donor file and a donor.")
    }
}

def validateStartAtParam() {
    def validStages = validStartAtStages()

    if (!validStages.contains(params.start_at)) {
        error("--start_at must be one of: ${validStages.join(', ')}")
    }
}

def validStartAtStages() {
    ['beginning', 'alignment', 'cbrb', 'cell_selection', 'standard_analysis', 'dropulation', 'mmc']
}

def stageRank(stageName: String) {
    validStartAtStages().indexOf(stageName)
}

// A stage should run when execution starts at that stage or any earlier stage.
def shouldRunStage(startAt: String, stageName: String) {
    stageRank(startAt) <= stageRank(stageName)
}

def restartTupleChannel(pathPattern, meta) {
    channel.fromPath(file(pathPattern).toUriString(), checkIfExists: true)
        .map { inputFile -> tuple(meta, inputFile) }
}

def restartPathChannel(pathPattern) {
    channel.fromPath(files(pathPattern), checkIfExists: true)
}

def restartAlignedBamChannel(pathPattern, referenceName: String) {
    channel.fromPath(files(pathPattern), checkIfExists: true)
        .map { bam ->
            def bamBase = bam.getName()
            if (hasExtension(bamBase, 'bam')) {
                bamBase = withoutExtension(bamBase, 'bam')
            }
            if (hasExtension(bamBase, 'bai')) {
                bamBase = withoutExtension(bamBase, 'bai')
            }
            if (hasExtension(bamBase, 'chimeric_marked')) {
                bamBase = withoutExtension(bamBase, 'chimeric_marked')
            }
            def indexStr = bamBase.toString().replaceFirst(/.*\./, '')
            if (!indexStr.isInteger()) {
                error("Cannot parse numeric collectIndex from BAM/BAI filename '${bam.getName()}'. Expected format: <name>.<index>[.chimeric_marked].ba[im]")
            }
            def collectIndex = indexStr as Integer
            tuple([id: bamBase, bamBase: bamBase, collectIndex: collectIndex, referenceName: referenceName], bam)
        }
}

