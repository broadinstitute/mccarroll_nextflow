process MERGE_CELL_TO_SAMPLE_ASSIGNMENTS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path donorAssignments
    output:
    path "${output_file}", emit: donorAssignments
    //tuple val("${task.process}"), val('MergeCellToSampleAssignments'), eval("MergeCellToSampleAssignments --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeCellToSampleAssignments
    
    script:
    output_file = "${library}.donor_assignments.txt"
    """
    MergeCellToSampleAssignments \
          --INPUT ${donorAssignments.join(' --INPUT ')} \
          --OUTPUT ${output_file}
    """
}