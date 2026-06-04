include {noMetaChannelHelper; collectInOrder; metaOnlyChannelHelper; combineIntoTupleChannel} from '../../modules/local/workflowUtil.nf'
include { buildReferenceMetadataLocator; loadNonAutosomes } from '../../modules/local/ReferenceMetadataLocator.nf'
include {FILTER_DGE} from '../../modules/local/filterDge.nf'
include {MAKE_TRIPLET_DGE} from '../../modules/local/makeTripletDge.nf'
include { GATHER_UMI_READ_INTERVALS } from '../../modules/local/gatherUmiReadIntervals.nf'
include { MERGE_UMI_READ_INTERVALS } from '../../modules/local/mergeUMIReadIntervals.nf'
include { CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE } from '../../modules/local/chimericReportEditDistanceCollapse.nf'
include { DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES } from '../../modules/local/downsampleTranscriptsAndQuantiles.nf'
include { GATHER_DIGITAL_ALLELE_COUNTS } from '../../modules/local/gatherDigitalAlleleCounts.nf'
include { MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES } from '../../modules/local/mergeGatherDigitalAlleleFrequencies.nf'
include { ASSIGN_CELLS_TO_SAMPLES } from '../../modules/local/assignCellsToSamples.nf'
include { DETECT_DOUBLETS } from '../../modules/local/detectDoublets.nf'
include { withExtension } from '../../modules/local/FileUtil.nf'
include { MERGE_CELL_TO_SAMPLE_ASSIGNMENTS } from '../../modules/local/mergeCellToSampleAssignments.nf'
include { MERGE_DOUBLET_ASSIGNMENTS } from '../../modules/local/mergeDoubletAssignments.nf'
include { DONOR_ASSIGNMENT_QC } from '../../modules/local/donorAssignmentQC.nf'
workflow standard_analysis_workflow {
    take:
    selectedCells
    dgeMatrix
    dgeSummary
    bams
    chimericTranscripts
    cbrbCellFeatures
    readsPerCell

    main    :
    functionalStrategy = params.metaGeneDgeFunctionalStrategy ?: params.dgeFunctionalStrategy
    FILTER_DGE(selectedCells, noMetaChannelHelper(dgeMatrix), noMetaChannelHelper(dgeSummary))
    referenceMetadataLocator = buildReferenceMetadataLocator(params.reference)
    MAKE_TRIPLET_DGE(FILTER_DGE.out.filteredDge, referenceMetadataLocator.reducedGtf)
    GATHER_UMI_READ_INTERVALS(bams, noMetaChannelHelper(selectedCells).collect(), params.locusFunction, params.strandStrategy, functionalStrategy)
    meta = metaOnlyChannelHelper(selectedCells)
    MERGE_UMI_READ_INTERVALS(meta, collectInOrder(GATHER_UMI_READ_INTERVALS.out.umiReadIntervals))
    CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE(selectedCells, noMetaChannelHelper(chimericTranscripts).collect())
    DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES(selectedCells, noMetaChannelHelper(CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE.out.molBc).collect())

    if (params.vcf) {
        bcf = params.cloudVcf ?: params.vcf
        nonAutosomes = loadNonAutosomes(referenceMetadataLocator.contigGroups)
        GATHER_DIGITAL_ALLELE_COUNTS(bams, noMetaChannelHelper(selectedCells).collect(), 
        params.donorFile, params.vcf, params.locusFunction, params.strandStrategy, nonAutosomes)
        MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES(params.library, collectInOrder(GATHER_DIGITAL_ALLELE_COUNTS.out.digitalAlleleFrequencies))
        digitalAlleleFrequencies = combineIntoTupleChannel(meta, MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES.out.digitalAlleleFrequencies)
        ASSIGN_CELLS_TO_SAMPLES(
            bams, 
            bcf, 
            withExtension(bcf, 'idx'),
            noMetaChannelHelper(selectedCells).collect(), 
            noMetaChannelHelper(cbrbCellFeatures).collect(), 
            MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES.out.digitalAlleleFrequencies.collect(),
            params.strandStrategy, functionalStrategy, params.cellBarcodeTag, params.molecularBarcodeTag, params.locusFunction, nonAutosomes
        )
        dd_channel = bams.join(ASSIGN_CELLS_TO_SAMPLES.out.vcf).join(ASSIGN_CELLS_TO_SAMPLES.out.vcfIndex).join(ASSIGN_CELLS_TO_SAMPLES.out.donorAssignments)
        DETECT_DOUBLETS(
            dd_channel, 
            noMetaChannelHelper(selectedCells).collect(), 
            params.donorFile, 
            noMetaChannelHelper(cbrbCellFeatures).collect(), 
            MERGE_GATHER_DIGITAL_ALLELE_FREQUENCIES.out.digitalAlleleFrequencies.collect(),
            params.strandStrategy, params.locusFunction, nonAutosomes
        )
        MERGE_CELL_TO_SAMPLE_ASSIGNMENTS(params.library, collectInOrder(ASSIGN_CELLS_TO_SAMPLES.out.donorAssignments))
        donorAssignments = combineIntoTupleChannel(meta, MERGE_CELL_TO_SAMPLE_ASSIGNMENTS.out.donorAssignments)
        MERGE_DOUBLET_ASSIGNMENTS(params.library, collectInOrder(DETECT_DOUBLETS.out.doublets))
        doubletAssignments = combineIntoTupleChannel(meta, MERGE_DOUBLET_ASSIGNMENTS.out.doublets)
        DONOR_ASSIGNMENT_QC(
            params.library, 
            MERGE_CELL_TO_SAMPLE_ASSIGNMENTS.out.donorAssignments.collect(),
            MERGE_DOUBLET_ASSIGNMENTS.out.doublets.collect(),
            noMetaChannelHelper(FILTER_DGE.out.filteredDgeSummary).collect(), 
            noMetaChannelHelper(dgeSummary).collect(), 
            noMetaChannelHelper(FILTER_DGE.out.filteredDge).collect(), 
            readsPerCell.collect(),
            params.donorFile)
        donorList = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.donorList)
        donorCellMap = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.donorCellMap)
        donorAssignmentSummaryStats = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.summaryStats)
        donorAssignmentTearSheet = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.tearSheetPdf)
        donorCellBarcodes = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.cellBarcodes) 
        donorAssignmentPdf = combineIntoTupleChannel(meta, DONOR_ASSIGNMENT_QC.out.pdf) 
    } else {
        digitalAlleleFrequencies = channel.empty()
        donorAssignments = channel.empty()
        doubletAssignments = channel.empty()
    }

    emit:
    dge = FILTER_DGE.out.filteredDge
    dgeSummary = FILTER_DGE.out.filteredDgeSummary
    sparseDgeMatrix = MAKE_TRIPLET_DGE.out.matrix
    sparseDgeFeatures = MAKE_TRIPLET_DGE.out.features
    sparseDgeBarcodes = MAKE_TRIPLET_DGE.out.barcodes
    umiReadIntervals = MERGE_UMI_READ_INTERVALS.out.umiReadIntervals
    molBc = CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE.out.molBc
    umiSaturationHistogram = DOWNSAMPLE_TRANSCRIPTS_AND_QUANTILES.out.umiSaturationHistogram
    digitalAlleleFrequencies = digitalAlleleFrequencies
    donorAssignments = donorAssignments
    doubletAssignments = doubletAssignments
    donorList = donorList
    donorCellMap = donorCellMap
    donorAssignmentSummaryStats = donorAssignmentSummaryStats
    donorAssignmentTearSheet = donorAssignmentTearSheet
    donorCellBarcodes = donorCellBarcodes
    donorAssignmentPdf = donorAssignmentPdf
}