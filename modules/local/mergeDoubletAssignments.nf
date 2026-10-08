process MERGE_DOUBLET_ASSIGNMENTS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    val library
    path doublets

    output:
    path "${output_file}", emit: doublets
    tuple val("${task.process}"), val('MergeDoubletAssignments'), eval("MergeDoubletAssignments --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeDoubletAssignments

    script:
    output_file = "${library}.doublets.txt"
    def javaMemMb = (task.memory.toMega() * 0.8) as int
    """
    MergeDoubletAssignments \
          -m ${javaMemMb}m \
          --INPUT ${doublets.join(' --INPUT ')} \
          --OUTPUT ${output_file}
    """
}
