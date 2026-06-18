process MERGE_READ_QUALITY_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics

    output:
    path "${output_file}"

    script:
    output_file = "${library}.ReadQualityMetrics.txt"

    """
    MergeReadQualityMetrics \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file}
    """
}