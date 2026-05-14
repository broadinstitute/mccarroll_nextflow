include {CALL_STAMPS_SVM_NUCLEI} from '../../modules/local/callSTAMPsSvmNuclei.nf'
include {CALL_STAMPS_MANUAL_THRESHOLDS} from '../../modules/local/callSTAMPsManualThresholds.nf'
include {sparseMatrixChannelHelper; noMetaChannelHelper} from '../../modules/local/workflowUtil.nf'

def hasManualThresholds(params) {
    return params.minUMIsPerCell != null ||
        params.maxUMIsPerCell != null ||
        params.minIntronicPerCell != null ||
        params.maxIntronicPerCell != null
}

// This should be handled in CALL_STAMPS_MANUAL_THRESHOLDS but I can't figure out how to pass nulls to a process so handle it here for now.
// I tried a typed process but I couldn't figure how to do it and it's beta anyway.
def valueOrNA(val) {
    return val != null ? val : "NA"
}


/**
 * Create label for manual-threshold cell selection.
 */
def makeManualThresholdLabel(params) {
    def labelComponents = []

        if (params.minUMIsPerCell != null ||
            params.maxUMIsPerCell != null) {

            def minUmi = params.minUMIsPerCell ?: 1
            def maxUmi = params.maxUMIsPerCell != null ?
                params.maxUMIsPerCell.toString() :
                'Inf'

            labelComponents << "umi_${minUmi}-${maxUmi}"
        }

        if (params.minIntronicPerCell != null ||
            params.maxIntronicPerCell != null) {

            def minIntronic = params.minIntronicPerCell ?: 0.0
            def maxIntronic = params.maxIntronicPerCell ?: 1.0
            labelComponents << String.format(
                'intronic_%.3f-%.3f',
                minIntronic as Float,
                maxIntronic as Float
            )
        }
    return labelComponents.join('_')
}

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
    if (hasManualThresholds(params)) {
        cell_selection_label = makeManualThresholdLabel(params)
        CALL_STAMPS_MANUAL_THRESHOLDS(noMetaChannelHelper(sparseMatrixChannelHelper(sparseDgeMatrix, sparseDgeFeatures, sparseDgeBarcodes)),
            noMetaChannelHelper(cellFeatures),
            noMetaChannelHelper(cbrbNonEmpties),
            cbrbNumTranscripts.map { m, f -> tuple(m + [cell_selection_label: cell_selection_label], f) },
            valueOrNA(params.minUMIsPerCell),
            valueOrNA(params.maxUMIsPerCell),
            valueOrNA(params.minIntronicPerCell),
            valueOrNA(params.maxIntronicPerCell)
        )
        selectedCellBarcodes = CALL_STAMPS_MANUAL_THRESHOLDS.out.selectedCellBarcodes
        ambientCellBarcodes = CALL_STAMPS_MANUAL_THRESHOLDS.out.ambientCellBarcodes
        cellSelectionAssignmentsPdf = CALL_STAMPS_MANUAL_THRESHOLDS.out.cellSelectionAssignmentsPdf
        cellSelectionAssignmentsSummary = CALL_STAMPS_MANUAL_THRESHOLDS.out.cellSelectionAssignmentsSummary
        droppedNonEmpty = CALL_STAMPS_MANUAL_THRESHOLDS.out.droppedNonEmpty
    } else {
    CALL_STAMPS_SVM_NUCLEI(noMetaChannelHelper(sparseMatrixChannelHelper(sparseDgeMatrix, sparseDgeFeatures, sparseDgeBarcodes)),
        noMetaChannelHelper(cellFeatures),
        noMetaChannelHelper(cbrbNonEmpties),
        cbrbNumTranscripts.map { m, f -> tuple(m + [cell_selection_label: "auto"], f) }
        )
        selectedCellBarcodes = CALL_STAMPS_SVM_NUCLEI.out.selectedCellBarcodes
        ambientCellBarcodes = CALL_STAMPS_SVM_NUCLEI.out.ambientCellBarcodes
        cellSelectionAssignmentsPdf = CALL_STAMPS_SVM_NUCLEI.out.cellSelectionAssignmentsPdf
        cellSelectionAssignmentsSummary = CALL_STAMPS_SVM_NUCLEI.out.cellSelectionAssignmentsSummary
        droppedNonEmpty = CALL_STAMPS_SVM_NUCLEI.out.droppedNonEmpty
    }

    emit:
    selectedCellBarcodes = selectedCellBarcodes
    ambientCellBarcodes = ambientCellBarcodes
    cellSelectionAssignmentsPdf = cellSelectionAssignmentsPdf
    cellSelectionAssignmentsSummary = cellSelectionAssignmentsSummary
    droppedNonEmpty = droppedNonEmpty
}