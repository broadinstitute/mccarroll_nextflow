process MERGE_BAM_TAG_HISTOGRAMS {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path metrics
    val extension

    output:
    path "${output_file}", emit: mergedBamTagHistograms
    tuple val("${task.process}"), val('MergeBamTagHistograms'), eval("MergeBamTagHistograms --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeBamTagHistograms
    
    script:
    output_file = "${library}.${extension}"

    """
    MergeBamTagHistograms \
        --INPUT ${metrics.join(' --INPUT ')} \
        --OUTPUT ${output_file}
    """
}