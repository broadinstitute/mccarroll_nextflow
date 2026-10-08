process FILTER_DGE {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    tuple val(meta), path(selectedCells)
    path dgeMatrix
    path dgeSummary

    output:
    tuple val(meta), path("${output_file}"), emit: filteredDge
    tuple val(meta), path("${output_summary}"), emit: filteredDgeSummary

    script:
    output_file = "${meta.id}.digital_expression.txt.gz"
    output_summary = "${meta.id}.digital_expression_summary.txt"
    def javaMemMb = (task.memory.toMega() * 0.8) as int
    """
    FilterDge \
        -m ${javaMemMb}m \
        --INPUT ${dgeMatrix} \
        --INPUT_SUMMARY ${dgeSummary} \
        --OUTPUT ${output_file} \
        --OUTPUT_SUMMARY ${output_summary} \
        --CELLS_RETAIN ${selectedCells} \
        --OUTPUT_HEADER true
    """
}
