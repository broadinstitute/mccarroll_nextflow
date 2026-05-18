include {noMetaChannelHelper; collectInOrder; metaOnlyChannelHelper} from '../../modules/local/workflowUtil.nf'
include { buildReferenceMetadataLocator } from '../../modules/local/ReferenceMetadataLocator.nf'
include {FILTER_DGE} from '../../modules/local/filterDge.nf'
include {MAKE_TRIPLET_DGE} from '../../modules/local/makeTripletDge.nf'
include { GATHER_UMI_READ_INTERVALS } from '../../modules/local/gatherUmiReadIntervals.nf'
include { MERGE_UMI_READ_INTERVALS } from '../../modules/local/mergeUMIReadIntervals.nf'

workflow standard_analysis_workflow {
    take:
    selectedCells
    dgeMatrix
    dgeSummary
    bams

    main:
    functionalStrategy = params.metaGeneDgeFunctionalStrategy ?: params.dgeFunctionalStrategy
    FILTER_DGE(selectedCells, noMetaChannelHelper(dgeMatrix), noMetaChannelHelper(dgeSummary))
    referenceMetadataLocator = buildReferenceMetadataLocator(params.reference)
    MAKE_TRIPLET_DGE(FILTER_DGE.out.filteredDge, referenceMetadataLocator.reducedGtf)
    GATHER_UMI_READ_INTERVALS(bams, noMetaChannelHelper(selectedCells).collect(), params.locusFunction, params.strandStrategy, functionalStrategy)
    MERGE_UMI_READ_INTERVALS(metaOnlyChannelHelper(selectedCells), collectInOrder(GATHER_UMI_READ_INTERVALS.out.umiReadIntervals))
    emit:
    dge = FILTER_DGE.out.filteredDge
    dgeSummary = FILTER_DGE.out.filteredDgeSummary
    sparseDgeMatrix = MAKE_TRIPLET_DGE.out.matrix
    sparseDgeFeatures = MAKE_TRIPLET_DGE.out.features
    sparseDgeBarcodes = MAKE_TRIPLET_DGE.out.barcodes
    umiReadIntervals = MERGE_UMI_READ_INTERVALS.out.umiReadIntervals
}