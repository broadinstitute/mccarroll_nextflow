include { locusFunctionClpArguments } from '../../modules/local/locusFunction.nf'

process DISCOVER_META_GENES {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'
    memory '8 GB'

    input:
    tuple val(meta), path(bam)
    path selectedCells
    val locusFunction
    val functionalStrategy

    output:
    tuple val(meta), path("${output_report}"), emit: metaGeneReport

    script:
    output_report = "${meta.id}.metagene_report.txt"
    locusFunctionArgs = locusFunctionClpArguments(locusFunction)
    """
    DiscoverMetaGenes \
        --INPUT ${bam} \
        --CELL_BC_FILE ${selectedCells} \
        --WRITE_SINGLE_GENES true \
        --FUNCTIONAL_STRATEGY ${functionalStrategy} \
        ${locusFunctionArgs} \
        --REPORT ${output_report}
    """
}