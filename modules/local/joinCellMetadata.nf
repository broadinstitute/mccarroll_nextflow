process JOIN_CELL_METADATA {
   label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_python:current'

    input:
    val library
    path cell_metadata
    path donor_cell_map
    val donor
    path dge_summary

    output:
    path "${output_file}"

    script:
    output_file = "${library}.cmd.tsv"

    // if donor_cell_map is present, join to this file and rename bestSample to donor.
    // else if donor is provided, add a donor column with this value.
    def donor_args = donor_cell_map ? "--join ${donor_cell_map} cell_barcode cell --rename bestSample donor" : (donor ? "--set donor ${donor}" : "")
    // join dge_summary and drop NUM_TRANSCRIPTS column because it is redundant.
    """
    join_and_filter_tsv \
        --input ${cell_metadata} --output ${output_file} \
        ${donor_args} \
        --join ${dge_summary} cell_barcode CELL_BARCODE \
        --drop NUM_TRANSCRIPTS
    """
}