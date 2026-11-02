process MERGE_FILTERED_READ_METRICS {
    tag "${library}"
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics

    output:
    path "${output_file}", emit: mergedFilteredReadMetrics
    tuple val("${task.process}"), val('MergeFilteredReadMetrics'), eval("MergeFilteredReadMetrics --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeFilteredReadMetrics

    script:
    output_file = "${library}.FilteredReadMetrics.txt"
    def javaMemMb = (task.memory.toMega() * 0.8) as int
    """
    MergeFilteredReadMetrics \
        -m ${javaMemMb}m \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file} \
        --DELETE_INPUTS false
    """
}
