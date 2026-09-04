include { locusFunctionClpArguments } from '../../modules/local/locusFunction.nf'

process CREATE_META_GENE_BAM {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'

     input:
    tuple val(meta), path(bam)
    path selectedCells
    path metaGeneReport
    val locusFunction
    val functionalStrategy

    output:
    tuple val(meta), path("${output_file}"), emit: bam
    tuple val("${task.process}"), val('CreateMetaGeneBam'), eval("DiscoverMetaGenes --version 2>&1 | sed -n 's/.*Version://p'"), topic: versions, emit: versions_CreateMetaGeneBam
    
    script:
    output_file = "${meta.id}.metagene.bam"
    locusFunctionArgs = locusFunctionClpArguments(locusFunction)
    """
    DiscoverMetaGenes \
        --INPUT ${bam} \
        --CELL_BC_FILE ${selectedCells} \
        --WRITE_SINGLE_GENES false \
        --FUNCTIONAL_STRATEGY ${functionalStrategy} \
        --KNOWN_META_GENE_FILE ${metaGeneReport} \
        ${locusFunctionArgs} \
        --OUTPUT ${output_file}
    """
}