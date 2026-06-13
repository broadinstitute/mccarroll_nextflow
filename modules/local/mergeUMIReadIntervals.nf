process MERGE_UMI_READ_INTERVALS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val meta // the perBamUMIReadIntervals have a less-complete meta, so pass it separately
    path perBamUMIReadIntervals

    output:
    tuple val(meta), path("${output_file}"), emit: umiReadIntervals

    script:
    output_file = meta.id + ".umi_read_intervals.tsv.gz"

    """
    MergeUMIReadIntervals \
        --INPUT ${perBamUMIReadIntervals.join(' --INPUT ')} \
        --OUTPUT ${output_file}
    """
}