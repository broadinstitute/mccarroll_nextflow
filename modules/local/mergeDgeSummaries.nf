process MERGE_DGE_SUMMARIES {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path dgeSummaries

    output:
    path "${output_file}"

    script:
    output_file = "${library}.digital_expression_summary.txt"
    """
    MergeDgeSummaries \
        --INPUT ${dgeSummaries.join(' --INPUT ')} \
        --OUTPUT ${output_file}
    """
}