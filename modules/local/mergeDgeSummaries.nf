process MERGE_DGE_SUMMARIES {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path dgeSummaries
    val otherArgs

    output:
    path "${output_file}", emit: mergedDgeSummaries
    tuple val("${task.process}"), val('MergeDgeSummaries'), eval("MergeDgeSummaries --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeDgeSummaries
    
    script:
    output_file = "${library}.digital_expression_summary.txt"
    """
    MergeDgeSummaries \
        --INPUT ${dgeSummaries.join(' --INPUT ')} \
        --OUTPUT ${output_file} \
        ${otherArgs ?: ''}
    """
}