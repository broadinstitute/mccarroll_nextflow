include {noMetaChannelHelper} from '../../modules/local/workflowUtil.nf'
include {FILTER_DGE} from '../../modules/local/filterDge.nf'

workflow standard_analysis_workflow {
    take:
    selectedCells
    dgeMatrix
    dgeSummary

    main:
    FILTER_DGE(selectedCells, noMetaChannelHelper(dgeMatrix), noMetaChannelHelper(dgeSummary))
    emit:
    dge = FILTER_DGE.out.filteredDge
    dgeSummary = FILTER_DGE.out.filteredDgeSummary

}