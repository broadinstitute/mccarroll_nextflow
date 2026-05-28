process MERGE_CELL_TO_SAMPLE_ASSIGNMENTS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'
    memory '8 GB'

    input:
    val library
    path donorAssignments
    output:
    path "${output_file}", emit: donorAssignments

    script:
    output_file = "${library}.donor_assignments.txt"
    """
    MergeCellToSampleAssignments \
          --INPUT ${donorAssignments.join(' --INPUT ')} \
          --OUTPUT ${output_file}
    """
}