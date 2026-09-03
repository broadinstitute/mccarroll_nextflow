process MERGE_CELLS_BY_NUM_TRANSCRIPTS {
    label 'process_low'

    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_java:current'

    input:
    val library
    path selectedCells
    path selectedCellsMetrics

    output:
    path "${output_file}", emit: mergedCells
    path "${output_metrics}", emit: mergedCellsMetrics
    //tuple val("${task.process}"), val('MergeCellsByNumTranscripts'), eval("MergeCellsByNumTranscripts --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_MergeCellsByNumTranscripts
    
    script:
    output_file = "${library}.size_selected_cells.txt.gz"
    output_metrics = "${library}.SelectCellsByNumTranscripts_metrics"
    """
    MergeCellsByNumTranscripts \
        --INPUT ${selectedCells.join(' --INPUT ')} \
        --INPUT_METRICS ${selectedCellsMetrics.join(' --INPUT_METRICS ')} \
        --OUTPUT ${output_file} \
        --METRICS ${output_metrics}
    """
}