process CHIMERIC_REPORT_EDIT_DISTANCE_COLLAPSE {
        label 'process_low'
    memory '16 GB'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    tuple val(meta), path(selectedCells)
    path chimericTranscripts

    output:
    tuple val(meta), path("${output_file}"), emit: molBc

    script:
    output_file = meta.id + ".molBC.txt.gz"

    """
    ChimericReportEditDistanceCollapse \
        --INPUT ${chimericTranscripts} \
        --OUTPUT ${output_file} \
        --CELL_BC_FILE ${selectedCells} \
        --IGNORE_CHIMERIC true
    """
}