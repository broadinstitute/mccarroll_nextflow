process MERGE_DGE {
    label 'process_low'
    memory '16 GB'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val output_prefix
    path dges

    output:
    path "$output_file", emit: dge

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