process MERGE_CHIMERIC_READ_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics

    output:
    path "${output_file}"

    script:
    output_file = "${library}.chimeric_read_metrics"

    """
    MergeChimericReadMetrics \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file} \
        --DELETE_INPUTS false
    """
}