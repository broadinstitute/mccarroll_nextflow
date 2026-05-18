include {noMetaChannelHelper} from '../../modules/local/workflowUtil.nf'
include { buildReferenceMetadataLocator } from '../../modules/local/ReferenceMetadataLocator.nf'
include {FILTER_DGE} from '../../modules/local/filterDge.nf'
include {MAKE_TRIPLET_DGE} from '../../modules/local/makeTripletDge.nf'

workflow standard_analysis_workflow {
    take:
    selectedCells
    dgeMatrix
    dgeSummary

    main:
    FILTER_DGE(selectedCells, noMetaChannelHelper(dgeMatrix), noMetaChannelHelper(dgeSummary))
    referenceMetadataLocator = buildReferenceMetadataLocator(params.reference)
    MAKE_TRIPLET_DGE(FILTER_DGE.out.filteredDge, referenceMetadataLocator.reducedGtf)
    emit:
    dge = FILTER_DGE.out.filteredDge
    dgeSummary = FILTER_DGE.out.filteredDgeSummary
    sparseDgeMatrix = MAKE_TRIPLET_DGE.out.matrix
    sparseDgeFeatures = MAKE_TRIPLET_DGE.out.features
    sparseDgeBarcodes = MAKE_TRIPLET_DGE.out.barcodes
}