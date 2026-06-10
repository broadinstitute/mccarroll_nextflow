include { locusFunctionClpArguments } from '../../modules/local/locusFunction.nf'

process DETECT_DOUBLETS {
    label 'process_medium'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        tuple val(meta), path(inputBam), path(vcf), path(vcfIndex), path(donorAssignments)
        path selectedCells
        path donorFile
        path cbrbCellSelectionReport
        path alleleFrequency
        val strandStrategy
        val locusFunction
        val nonAutosomes

    output:
        tuple val(meta), path("${output_file}"), emit: doublets

    script:
    output_file = "${meta.id}.doublets.txt"
    locusFunctionArgs = locusFunctionClpArguments(locusFunction)
    nonAutosomesString = nonAutosomes? nonAutosomes.collect{ seq -> "--IGNORED_CHROMOSOMES ${seq}" }.join(' ') : ''
    """
    DetectDoublets -m 30g \
        --INPUT_BAM ${inputBam} \
        --VCF ${vcf} \
        --CELL_BC_FILE ${selectedCells} \
        --SINGLE_DONOR_LIKELIHOOD_FILE ${donorAssignments} \
        --SAMPLE_FILE ${donorFile} \
        --OUTPUT ${output_file} \
        --FORCED_RATIO 0.8 \
        ${locusFunctionArgs} \
        --STRAND_STRATEGY ${strandStrategy} \
        ${nonAutosomesString} \
          --CELL_CONTAMINATION_ESTIMATE_FILE ${cbrbCellSelectionReport} \
          --ALLELE_FREQUENCY_ESTIMATE_FILE ${alleleFrequency} 
    """
}