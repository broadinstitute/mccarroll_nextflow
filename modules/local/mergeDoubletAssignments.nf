process MERGE_DOUBLET_ASSIGNMENTS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'
    memory '8 GB'

    input:
    val library
    path doublets
    output:
    path "${output_file}", emit: doublets

    script:
    output_file = "${library}.doublets.txt"
    """
    MergeDoubletAssignments \
          --INPUT ${doublets.join(' --INPUT ')} \
          --OUTPUT ${output_file}
    """
}   