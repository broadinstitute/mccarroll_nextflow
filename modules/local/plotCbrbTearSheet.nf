process PLOT_CBRB_TEAR_SHEET {
    label 'process_low'
    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_r:current'

    input:
    val library
    val cbrbLabel
    path elbo
    path cbrbRetainedUMIs
    path readQualityMetrics
    path appendPdfs
    path cbrbMetrics
    path cbrbSelectedCells
    path cellFeatures

    output:
    path "${output_file}"

    script:
    output_file = "${library}.cbrb_tearsheet.pdf"

    """
    Rscript -e 'message(date(), " Start ", "plotCbrbTearSheet")' \
    -e 'suppressPackageStartupMessages(library(Dropseq.cellselection))' \
    -e 'cbrb_0.3.0_TearSheet(elboFile="${elbo}",outFile="${output_file}",cbrbRetainedUMIsFile="${cbrbRetainedUMIs}",readQualityMetricsFile="${readQualityMetrics}",appendPdfs=c("${appendPdfs.join(",")}"),cbrbMetricsCsv="${cbrbMetrics}",title="${library}.${cbrbLabel}",rbSelectedCellsFile="${cbrbSelectedCells}",cellFeaturesFile="${cellFeatures}")' \
    -e 'message(date(), " Done ", "plotCbrbTearSheet")' 
    """
}