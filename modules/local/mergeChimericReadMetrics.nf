process MERGE_CHIMERIC_READ_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics

    output:
    path "${output_file}"
    //tuple val("${task.process}"), val('MergeChimericReadMetrics'), eval("MergeChimericReadMetrics --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeChimericReadMetrics
    
    script:
    output_file = "${library}.chimeric_read_metrics"

    """
    MergeChimericReadMetrics \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file} \
        --DELETE_INPUTS false
    """
}