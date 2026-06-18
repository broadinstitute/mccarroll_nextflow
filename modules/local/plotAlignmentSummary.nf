process PLOT_ALIGNMENT_SUMMARY {
    label 'process_low'
    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_r:current'
    input:
    val library
        path readQualityMetrics
        path rnaSeqMetrics


    output:
        path "$output_file"
    script:
    output_file = "${library}.alignment_summary.pdf"
    """
     Rscript -e 'message(date(), " Start ", "plotAlignmentSummaryMetrics")' \
    -e 'suppressPackageStartupMessages(library(DropSeq.barnyard))' \
    -e 'plotAlignmentSummaryMetrics(outPlot="${output_file}",exonIntronFile="${rnaSeqMetrics}",alignmentQualityFile="${readQualityMetrics}")' \
    -e 'message(date(), " Done ", "plotAlignmentSummaryMetrics")' 
   """
}