process MERGE_DGE {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val output_prefix
    path dges

    output:
    path "$output_file", emit: dge
    tuple val("${task.process}"), val('MergeDge'), eval("MergeDge --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeDge
    
    script:
    output_file = "${output_prefix}.digital_expression.txt.gz"

    """
    MergeDge \
        --INPUT ${dges.join(' --INPUT ')} \
        --OUTPUT ${output_file} \
        --HEADER_STRINGENCY LENIENT \
        --OUTPUT_HEADER true \
        --INTEGER_FORMAT true
    """
}   