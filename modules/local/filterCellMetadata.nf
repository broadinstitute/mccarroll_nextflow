process FILTER_CELL_METADATA {
    tag "${library}"
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_python:current'

    input:
    val library
    path cell_metadata
    path selected_cells

    output:
    path "${output_file}", emit: filteredCellMetadata
    tuple val("${task.process}"), val('filterCellMetadata'), eval("cat /etc/dropseq-version"), topic: versions, emit: versions_filterCellMetadata

    script:
    output_file = "${library}.filtered_cmd.tsv"

    // Filter based on values in selected_cells.  Test against cell_barcode column of cell_metadata
    """
    join_and_filter_tsv \
        --input ${cell_metadata} --output ${output_file} \
        --include-file cell_barcode ${selected_cells}
    """
}
