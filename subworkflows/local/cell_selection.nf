include {CALL_STAMPS_SVM_NUCLEI} from '../../modules/local/callSTAMPsSvmNuclei.nf'
include {CALL_STAMPS_MANUAL_THRESHOLDS} from '../../modules/local/callSTAMPsManualThresholds.nf'
include {sparseMatrixChannelHelper; noMetaChannelHelper; metaOnlyChannelHelper; combineIntoTupleChannel} from '../../modules/local/workflowUtil.nf'
include { hasManualCellSelectionThresholds; makeManualCellSelectionLabel } from '../../modules/local/WorkflowPathUtil.nf'
include { WRITE_PROPERTIES } from '../../modules/local/writeProperties.nf'

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
    if (hasManualCellSelectionThresholds(params)) {
        cell_selection_label = makeManualCellSelectionLabel(params)
        CALL_STAMPS_MANUAL_THRESHOLDS(noMetaChannelHelper(sparseMatrixChannelHelper(sparseDgeMatrix, sparseDgeFeatures, sparseDgeBarcodes)),
            noMetaChannelHelper(cellFeatures),
            noMetaChannelHelper(cbrbNonEmpties),
            cbrbNumTranscripts.map { m, f -> tuple(m + [cell_selection_label: cell_selection_label], f) },
            params.minUMIsPerCell,
            params.maxUMIsPerCell,
            params.minIntronicPerCell,
            params.maxIntronicPerCell
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

    workflowProperties = [
        minUMIsPerCell: params.minUMIsPerCell,
        maxUMIsPerCell: params.maxUMIsPerCell,
        minIntronicPerCell: params.minIntronicPerCell,
        maxIntronicPerCell: params.maxIntronicPerCell
    ]
    WRITE_PROPERTIES(workflowProperties)
    cellSelectionProperties = combineIntoTupleChannel(metaOnlyChannelHelper(selectedCellBarcodes), WRITE_PROPERTIES.out)

    emit:
    selectedCellBarcodes = selectedCellBarcodes
    ambientCellBarcodes = ambientCellBarcodes
    cellSelectionAssignmentsPdf = cellSelectionAssignmentsPdf
    cellSelectionAssignmentsSummary = cellSelectionAssignmentsSummary
    droppedNonEmpty = droppedNonEmpty
    properties = cellSelectionProperties
}