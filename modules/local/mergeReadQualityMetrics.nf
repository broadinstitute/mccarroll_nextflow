process MERGE_READ_QUALITY_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics

    output:
    path "${output_file}"
    //tuple val("${task.process}"), val('MergeReadQualityMetrics'), eval("MergeReadQualityMetrics --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeReadQualityMetrics
    
    script:
    output_file = "${library}.ReadQualityMetrics.txt"

    """
    MergeReadQualityMetrics \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file}
    """
}