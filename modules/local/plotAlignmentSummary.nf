process PLOT_ALIGNMENT_SUMMARY {
    tag "${library}"
    label 'process_low'
    container 'us.gcr.io/mccarroll-scrna-seq/drop-seq_private_r:current'

    input:
    val library
    path readQualityMetrics
    path rnaSeqMetrics

    output:
    path "${output_file}", emit: alignment_summary_pdf
    tuple val("${task.process}"), val('plotAlignmentSummary'), eval("cat /etc/dropseq-version"), topic: versions, emit: versions_plotAlignmentSummary

    script:
    output_file = "${library}.alignment_summary.pdf"
    """
     Rscript -e 'message(date(), " Start ", "plotAlignmentSummaryMetrics")' \
    -e 'suppressPackageStartupMessages(library(DropSeq.barnyard))' \
    -e 'plotAlignmentSummaryMetrics(outPlot="${output_file}",exonIntronFile="${rnaSeqMetrics}",alignmentQualityFile="${readQualityMetrics}")' \
    -e 'message(date(), " Done ", "plotAlignmentSummaryMetrics")' 
   """
}
