process GATHER_READ_QUALITY_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${output_file}"), emit: readQualityMetrics
    tuple val("${task.process}"), val('GatherReadQualityMetrics'), eval("GatherReadQualityMetrics --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_GatherReadQualityMetrics
    
    script:
    output_file = meta.bamBase + ".ReadQualityMetrics.txt"

    """
    GatherReadQualityMetrics \
        --INPUT ${bam} \
        --OUTPUT ${output_file}
    """
}