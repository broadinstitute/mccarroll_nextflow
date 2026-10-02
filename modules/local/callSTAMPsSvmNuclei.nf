process CALL_STAMPS_SVM_NUCLEI {
    label 'process_low'

    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_r:current'

    input:
    path sparseDge
    path cellFeatures
    tuple val(meta), path(cbrbNonEmpties) // most complete meta comes from here
    val useCBRBInitialization
    path cbrbNumTranscripts

    output:
    tuple val(meta), path("${output_file}"), emit: selectedCellBarcodes
    tuple val(meta), path("${output_ambient}"), emit: ambientCellBarcodes
    tuple val(meta), path("${output_pdf}"), emit: cellSelectionAssignmentsPdf
    tuple val(meta), path("${output_summary}"), emit: cellSelectionAssignmentsSummary
    tuple val(meta), path("${output_dropped_non_empty}"), emit: droppedNonEmpty

    script:
    dataset_name = meta.id
    output_file = "${dataset_name}.selectedCellBarcodes.txt"
    output_ambient = "${dataset_name}.ambientCellBarcodes.txt"
    output_pdf = "${dataset_name}.cell_selection_assignments.pdf"
    output_summary = "${dataset_name}.cell_selection_assignments_summary.txt"
    output_dropped_non_empty = "${dataset_name}.not_cell_not_empty.txt"
    useCBRBInitializationStr = useCBRBInitialization ? "TRUE" : "FALSE"
    cbrbNumTranscriptsStr = cbrbNumTranscripts ? "\"${cbrbNumTranscripts}\"" : "NULL"

    """
    Rscript -e 'message(date(), " Start ", "CallSTAMPsSvmNuclei")' \
    -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
    -e 'CallSTAMPsSvmNuclei(dataset_name="${dataset_name}",cbrbNonEmptiesFile="${cbrbNonEmpties}",outCellFile="${output_file}",sparseDgeDir=".",cbrbRetainedUMIsFile=${cbrbNumTranscriptsStr},outAmbientCellFile="${output_ambient}",outPDF="${output_pdf}",outSummaryFile="${output_summary}",is_10x=TRUE,outDroppedNonEmptiesFile="${output_dropped_non_empty}",cellProbabilityThreshold=NULL,cellFeaturesFile="${cellFeatures}",useCBRBInitialization=${useCBRBInitializationStr})' \
    -e 'message(date(), " Done ", "CallSTAMPsSvmNuclei")' 
    """
}
