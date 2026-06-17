process CALL_STAMPS_MANUAL_THRESHOLDS {
    label 'process_low'

    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_r:current'

    input:
    path sparseDge
    path cellFeatures
    path cbrbNonEmpties
    tuple val(meta), path(cbrbNumTranscripts) // CBRB output will have the most fulsome meta, so take it from there.
    val minUMIsPerCell
    val maxUMIsPerCell
    val minIntronicPerCell
    val maxIntronicPerCell

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
    def minUMIs     = minUMIsPerCell     != null ? minUMIsPerCell     : "NA"
    def maxUMIs     = maxUMIsPerCell     != null ? maxUMIsPerCell     : "NA"
    def minIntronic = minIntronicPerCell != null ? minIntronicPerCell : "NA"
    def maxIntronic = maxIntronicPerCell != null ? maxIntronicPerCell : "NA"

    """
    Rscript -e 'message(date(), " Start ", "CallSTAMPs")' \
    -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
    -e 'CallSTAMPs(dataset_name="${dataset_name}",cellFeaturesFile="${cellFeatures}",outCellFile="${output_file}",outPDF="${output_pdf}",outAmbientCellFile="${output_ambient}",outSummaryFile="${output_summary}",is_10x=TRUE,outDroppedNonEmptiesFile="${output_dropped_non_empty}",cbrbNonEmptiesFile="${cbrbNonEmpties}",cbrbRetainedUMIsFile="${cbrbNumTranscripts}",method_selected="manual_selection",minUMIsPerCell=${minUMIs},maxUMIsPerCell=${maxUMIs},minIntronicPerCell=${minIntronic},maxIntronicPerCell=${maxIntronic},sparseDgeDir=".")' \
    -e 'message(date(), " Done ", "CallSTAMPs")'
    """

}