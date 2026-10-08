process MERGE_BARCODE_CORRECTION_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics

    output:
    path "${output_file}", emit: mergedMetrics
    tuple val("${task.process}"), val('MergeBarcodeCorrectionMetrics'), eval("MergeBarcodeCorrectionMetrics --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeBarcodeCorrectionMetrics

    script:
    output_file = "${library}.corrected_barcode_metrics"
    def javaMemMb = (task.memory.toMega() * 0.8) as int
    """
    MergeBarcodeCorrectionMetrics \
        -m ${javaMemMb}m \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file} \
        --DELETE_INPUTS false
    """
}
