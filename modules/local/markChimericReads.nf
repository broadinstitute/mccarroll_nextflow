include { locusFunctionClpArguments } from '../../modules/local/locusFunction.nf'

process MARK_CHIMERIC_READS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'
    memory '8 GB'

    input:
        tuple val(meta), path(inputBam)
        val strandStrategy
        val locusFunction
    output:
    tuple val(meta), path("${output_file}"), emit: chimericMarkedBam
    tuple val(meta), path("${output_metrics}"), emit: chimericReadMetrics    
    tuple val(meta), path("${output_chimeric_transcripts}"), emit: chimericTranscripts    

    script:
    output_file = meta.id + ".chimeric_marked.bam"
    output_metrics = meta.id + ".chimeric_read_metrics"
    output_chimeric_transcripts = meta.id + ".chimeric_transcripts.txt.gz"
    locusFunctionArgs = locusFunctionClpArguments(locusFunction)
    """
    MarkChimericReads \
          --I ${inputBam} \
          --O ${output_file} \
          --METRICS ${output_metrics} \
          --OUTPUT_REPORT ${output_chimeric_transcripts} \
          --STRAND_STRATEGY ${strandStrategy} \
          ${locusFunctionArgs} \
          --COMPRESSION_LEVEL 0 \
          --VALIDATION_STRINGENCY SILENT
    """
}