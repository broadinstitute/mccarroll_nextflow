process GATHER_READ_QUALITY_METRICS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${output_file}")

    script:
    output_file = meta.bamBase + ".ReadQualityMetrics.txt"

    """
    GatherReadQualityMetrics \
        --INPUT ${bam} \
        --OUTPUT ${output_file}
    """
}