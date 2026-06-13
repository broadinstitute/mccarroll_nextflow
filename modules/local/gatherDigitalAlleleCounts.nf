include { locusFunctionClpArguments } from '../../modules/local/locusFunction.nf'

process GATHER_DIGITAL_ALLELE_COUNTS {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        // Although the BAM doesn't have the most complete meta, it's used here because this is run on split BAMs so the output files need to be named appropriately.
        tuple val(meta), path(bam)
        path selectedCells
        path donorFile
        path bcf
        val locusFunction
        val strandStrategy
        val nonAutosomes
    output:
    tuple val(meta), path("${output_file}"), emit: digitalAlleleFrequencies

    script:
    output_file = "${meta.id}.allele_freq.txt"
    nonAutosomesString = nonAutosomes? nonAutosomes.collect{ seq -> "--IGNORED_CHROMOSOMES ${seq}" }.join(' ') : ''
    locusFunctionArgs = locusFunctionClpArguments(locusFunction)

    """
    GatherDigitalAlleleCounts \
          --INPUT ${bam} \
          --VCF ${bcf} \
          --CELL_BC_FILE ${selectedCells} \
          --SAMPLE_FILE ${donorFile} \
          --ALLELE_FREQUENCY_OUTPUT ${output_file} \
          ${locusFunctionArgs} \
          --STRAND_STRATEGY ${strandStrategy} \
          ${nonAutosomesString} \
          --SINGLE_VARIANT_READS false \
          --MULTI_GENES_PER_READ false
    """
}