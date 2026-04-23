include { locusFunctionClpArguments } from '../../modules/local/locusFunction.nf'

process SELECT_CELLS_BY_NUM_TRANSCRIPTS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'
    memory '8 GB'

    input:
    tuple val(meta), path(inputBam)
    val locusFunction
    val minimumTranscriptsPerCell
    val readQuality
    val functionalStrategy
    val strandStrategy

    output: 
    tuple val(meta), path("${output_file}"), emit: selectedCells
    tuple val(meta), path("${metrics_file}"), emit: metrics

    script:
    output_file = "${meta.id}.size_selected_cells.txt.gz"
    metrics_file = "${meta.id}.SelectCellsByNumTranscripts_metrics"
    locusFunctionArgs = locusFunctionClpArguments(locusFunction)
    """
    SelectCellsByNumTranscripts \
          --INPUT ${inputBam} \
          --OUTPUT ${output_file} \
          --MIN_TRANSCRIPTS_PER_CELL ${minimumTranscriptsPerCell} \
          --READ_MQ ${readQuality} \
          --FUNCTIONAL_STRATEGY ${functionalStrategy} \
          --METRICS ${metrics_file} \
          ${locusFunctionArgs} \
          --STRAND_STRATEGY ${strandStrategy}
    """
}