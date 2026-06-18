process PLOT_STANDARD_ANALYSIS {
    label 'process_low'
    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_r:current'

    input:
    val library
        path umiSaturationHistogram
        path molecularBarcodeDistributionByGene
        path digitalExpressionSummary


    output:
        path "$output_file", emit: pdf
        path "$output_umi_saturation_metrics", emit: umi_saturation_metrics
    script:
    output_file = "${library}.standard_analysis.pdf"
    output_umi_saturation_metrics = "${library}.umi_saturation_metrics.txt"
    """
     Rscript -e 'message(date(), " Start ", "plotStandardAnalysis")' \
    -e 'suppressPackageStartupMessages(library(DropSeq.barnyard))' \
    -e 'plotStandardAnalysisSingleOrganism(umiSaturationHistogramFile="${umiSaturationHistogram}",experimentName="${library}",outUmiSaturationMetricsFile="${output_umi_saturation_metrics}",molecularBarcodeDistributionByGeneFile="${molecularBarcodeDistributionByGene}",digitalExpressionSummaryFile="${digitalExpressionSummary}",outPlot="${output_file}")' \
    -e 'message(date(), " Done ", "plotStandardAnalysis")' 
   """
}