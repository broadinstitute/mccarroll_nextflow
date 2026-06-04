process DONOR_ASSIGNMENT_QC {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_r:current'
    memory '8 GB'

    input:
    val library
    path donorAssignments
    path doublets
    path dgeSummary
    path dgeRawSummary
    path dgeFile
    path readsPerCellFile
    path donorFile
    output:
    path "${output_donor_list}", emit: donorList
    path "${output_donor_cell_map}", emit: donorCellMap
    path "${output_pdf}", emit: pdf
    path "${output_summary_stats}", emit: summaryStats
    path "${output_cell_barcodes}", emit: cellBarcodes
    path "${output_tearsheet_pdf}", emit: tearSheetPdf

    script:
    output_donor_list = "${library}.donor_list.txt"
    output_donor_cell_map = "${library}.donor_cell_map.txt"
    output_pdf = "${library}.dropulation_report.pdf"
    output_summary_stats = "${library}.dropulation_summary_stats.txt"
    output_cell_barcodes = "${library}.donorCellBarcodes.txt"
    output_tearsheet_pdf = "${library}.dropulation_tearsheet.pdf"
    """
Rscript \
    -e 'message(date(), " Start ", "donorAssignmentQC")' \
    -e 'suppressPackageStartupMessages(library(DropSeq.dropulation))' \
    -e 'donorAssignmentQC(
        expName="${library}",
        likelihoodSummaryFile="${donorAssignments}",
        doubletLikelihoodFile="${doublets}",
        dgeSummaryFile="${dgeSummary}",
        dgeRawSummaryFile="${dgeRawSummary}",
        dgeFile="${dgeFile}",
        readsPerCellFile="${readsPerCellFile}",
        outFileLikelyDonors="${output_donor_list}",
        outDonorToCellMap="${output_donor_cell_map}",
        outPDF="${output_pdf}",
        outSummaryStatsFile="${output_summary_stats}",
        expectedSamplesFile="${donorFile}",
        outCellBarcodesFile="${output_cell_barcodes}",
        outTearSheetPDF="${output_tearsheet_pdf}"
    )' \
    -e 'message(date(), " Done ", "donorAssignmentQC")'
    """
}