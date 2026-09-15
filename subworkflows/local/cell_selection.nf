include { CALL_STAMPS_SVM_NUCLEI           } from '../../modules/local/callSTAMPsSvmNuclei.nf'
include { CALL_STAMPS_MANUAL_THRESHOLDS    } from '../../modules/local/callSTAMPsManualThresholds.nf'
include { sparseMatrixChannelHelper ; noMetaChannelHelper ; metaOnlyChannelHelper ; combineIntoTupleChannel ; naIfNull ; getUserName } from '../../modules/local/workflowUtil.nf'
include { hasManualCellSelectionThresholds ; makeManualCellSelectionLabel } from '../../modules/local/WorkflowPathUtil.nf'
include { WRITE_PROPERTIES                 } from '../../modules/local/writeProperties.nf'
include { cellSelectionDir                 } from '../../modules/local/DirectoryUtil.nf'
include { subpath                          } from '../../modules/local/FileUtil.nf'

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
        CALL_STAMPS_MANUAL_THRESHOLDS(
            noMetaChannelHelper(sparseMatrixChannelHelper(sparseDgeMatrix, sparseDgeFeatures, sparseDgeBarcodes)),
            noMetaChannelHelper(cellFeatures),
            noMetaChannelHelper(cbrbNonEmpties),
            cbrbNumTranscripts.map { m, f -> tuple(m + [cell_selection_label: cell_selection_label], f) },
            naIfNull(params.minUMIsPerCell),
            naIfNull(params.maxUMIsPerCell),
            naIfNull(params.minIntronicPerCell),
            naIfNull(params.maxIntronicPerCell),
        )
        selectionOutputs = CALL_STAMPS_MANUAL_THRESHOLDS.out

    }
    else {
        CALL_STAMPS_SVM_NUCLEI(
            noMetaChannelHelper(sparseMatrixChannelHelper(sparseDgeMatrix, sparseDgeFeatures, sparseDgeBarcodes)),
            noMetaChannelHelper(cellFeatures),
            noMetaChannelHelper(cbrbNonEmpties),
            cbrbNumTranscripts.map { m, f -> tuple(m + [cell_selection_label: "auto"], f) },
        )
        selectionOutputs = CALL_STAMPS_SVM_NUCLEI.out
    }
    selectedCellBarcodes = selectionOutputs.selectedCellBarcodes
    ambientCellBarcodes = selectionOutputs.ambientCellBarcodes
    cellSelectionAssignmentsPdf = selectionOutputs.cellSelectionAssignmentsPdf
    cellSelectionAssignmentsSummary = selectionOutputs.cellSelectionAssignmentsSummary
    droppedNonEmpty = selectionOutputs.droppedNonEmpty

    workflowProperties = [
        submitter: getUserName(),
        minUMIsPerCell: params.minUMIsPerCell,
        maxUMIsPerCell: params.maxUMIsPerCell,
        minIntronicPerCell: params.minIntronicPerCell,
        maxIntronicPerCell: params.maxIntronicPerCell
    ]
    WRITE_PROPERTIES(workflowProperties)
    cellSelectionProperties = combineIntoTupleChannel(metaOnlyChannelHelper(selectedCellBarcodes), WRITE_PROPERTIES.out)
    fullCellSelectionDir = cellSelectionAssignmentsPdf.map { tup -> subpath(params.outdir, cellSelectionDir(tup)) }
    cellSelectionAssignmentsPdf.combine(fullCellSelectionDir).subscribe { file, dir ->
        if (params.email) {
            sendMail(
                subject: "Cell selection summary for ${params.library}",
                body: "Cell selection summary for ${params.library} in ${dir}",
                to: params.email,
                attach: file,
            )
        }
    }

    emit:
    selectedCellBarcodes            = selectedCellBarcodes
    ambientCellBarcodes             = ambientCellBarcodes
    cellSelectionAssignmentsPdf     = cellSelectionAssignmentsPdf
    cellSelectionAssignmentsSummary = cellSelectionAssignmentsSummary
    droppedNonEmpty                 = droppedNonEmpty
    properties                      = cellSelectionProperties
}
