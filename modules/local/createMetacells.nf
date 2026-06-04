// This CLP has many more options.  Add as needed.

process CREATE_METACELLS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'
    memory '16 GB'

    input:
    tuple val(meta), path(assignments)
    path dgeMatrix

    output:
    path "${output_file}", emit: metacells
    path "${output_metrics}", emit: metacellMetrics

    script:
    output_file = "${meta.id}.metacells.txt"
    output_metrics = "${meta.id}.metacell_metrics"
    """
    CreateMetaCells \
        --INPUT ${dgeMatrix} \
        --OUTPUT ${output_file} \
        --DONOR_MAP ${assignments} \
        --METRICS ${output_metrics}
    """
}