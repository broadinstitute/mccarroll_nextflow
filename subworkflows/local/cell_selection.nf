include {CALL_STAMPS_SVM_NUCLEI} from '../../modules/local/callSTAMPsSvmNuclei.nf'
include {sparseMatrixChannelHelper; noMetaChannelHelper} from '../../modules/local/workflowUtil.nf'

// TODO: support manual thresholds
workflow cell_selection_workflow {
    take:
    sparseDgeMatrix
    sparseDgeFeatures
    sparseDgeBarcodes
    cellFeatures
    cbrbNonEmpties
    cbrbNumTranscripts

    main:
    CALL_STAMPS_SVM_NUCLEI(sparseMatrixChannelHelper(sparseDgeMatrix, sparseDgeFeatures, sparseDgeBarcodes),
        noMetaChannelHelper(cellFeatures),
        noMetaChannelHelper(cbrbNonEmpties),
        noMetaChannelHelper(cbrbNumTranscripts)
    )

    emit:
    selectedCellBarcodes = CALL_STAMPS_SVM_NUCLEI.out.selectedCellBarcodes
    ambientCellBarcodes = CALL_STAMPS_SVM_NUCLEI.out.ambientCellBarcodes
    cellSelectionAssignmentsPdf = CALL_STAMPS_SVM_NUCLEI.out.cellSelectionAssignmentsPdf
    cellSelectionAssignmentsSummary = CALL_STAMPS_SVM_NUCLEI.out.cellSelectionAssignmentsSummary
    droppedNonEmpty = CALL_STAMPS_SVM_NUCLEI.out.droppedNonEmpty
}