process BUILD_CELL_FEATURES_SIMPLE {
    label 'process_low'
    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_r:current'

    input:
    val library
    val minTranscriptsPerCell
    path dgeSummary
    path singleCellRnaSeqMetrics
    path numReadsPerCell

    output:
    path "${output_file}"

    script:
    output_file = "${library}.cell_features.txt"

    """
    Rscript -e 'message(date(), " Start ", "buildCellFeaturesSimple")' \
    -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
    -e 'buildCellFeaturesSimple(readsFile="${numReadsPerCell}",functionFile="${singleCellRnaSeqMetrics}",outFile="${output_file}",dgeSummaryFile="${dgeSummary}",minNumTranscripts=${minTranscriptsPerCell})' \
    -e 'message(date(), " Done ", "buildCellFeaturesSimple")' 
    """
}