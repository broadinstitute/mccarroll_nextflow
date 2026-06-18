process CALL_SEX_FROM_METACELLS {
    label 'process_low'
    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_r:current'

    input:
    val library
    path sexCallerConfigYaml
    path metacells
    path metacellMetrics

    output:
        path "$output_file", emit: sexCalls
        path "$output_pdf", emit: pdf
    script:
    output_file = "${library}.sex.txt"
    output_pdf = "${library}.sex.pdf"
    """
     Rscript -e 'message(date(), " Start ", "callSexFromMetacells")' \
    -e 'suppressPackageStartupMessages(library(DropSeq.xipher))' \
    -e 'callSexFromMetacells(outputSexCallFile="${output_file}",analysisIdentifier="${library}",sexCallerConfigYamlFile="${sexCallerConfigYaml}",inputMetacellFile="${metacells}",ouputHistPdfFile="${output_pdf}",inputMetacellMetricsFile="${metacellMetrics}")' \
    -e 'message(date(), " Done ", "callSexFromMetacells")' 
   """

}