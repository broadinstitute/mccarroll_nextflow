// This CLP has many more options.  Add as needed.

process CREATE_METACELLS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'
    memory '16 GB'

    input:
    tuple val(meta), path(assignments), val(donor)
    path dgeMatrix

    output:
    path "${output_file}", emit: metacells
    path "${output_metrics}", emit: metacellMetrics

    script:
    if (donor.size() > 0) {
        donor_arg = "--SINGLE_METACELL_LABEL ${donor}"
        if (assignments.size() > 0) {
            throw new IllegalArgumentException("Multiple donor assignment files provided for a single donor ${donor}")
        }
    } else if (assignments.size() > 0) {
        donor_arg = "--DONOR_MAP ${assignments}"
    } else {
            throw new IllegalArgumentException("Either single donor or donor assignment file must be provided")
    }
    output_file = "${meta.id}.metacells.txt"
    output_metrics = "${meta.id}.metacell_metrics"
    """
    CreateMetaCells \
        --INPUT ${dgeMatrix} \
        --OUTPUT ${output_file} \
        --METRICS ${output_metrics} \
        ${donor_arg}
    """
}