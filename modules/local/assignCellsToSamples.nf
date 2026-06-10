include { locusFunctionClpArguments } from '../../modules/local/locusFunction.nf'

process ASSIGN_CELLS_TO_SAMPLES {
    label 'process_medium'

    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
        tuple val(meta), path(inputBam)
        path bcf
        path bcfIndex
        path selectedCells
        path cbrbCellSelectionReport
        path alleleFrequency
        val strandStrategy
        val functionalStrategy
        val cellBarcodeTag
        val molecularBarcodeTag
        val locusFunction
        val nonAutosomes
    output:
        tuple val(meta), path("${donor_assignments}"), emit: donorAssignments
        tuple val(meta), path("${vcf}"), emit: vcf
        tuple val(meta), path("${vcfIndex}"), emit: vcfIndex

    script:
    donor_assignments = "${meta.id}.donor_assignments.txt"
    vcf = "${meta.id}.vcf.gz"
    vcfIndex = "${vcf}.tbi"
    locusFunctionArgs = locusFunctionClpArguments(locusFunction)
    nonAutosomesString = nonAutosomes? nonAutosomes.collect{ seq -> "--IGNORED_CHROMOSOMES ${seq}" }.join(' ') : ''
    """
    AssignCellsToSamples  -m 30g \
          --INPUT_BAM ${inputBam} \
          --VCF ${bcf} \
          --OUTPUT ${donor_assignments} \
          --VCF_OUTPUT ${vcf} \
          --CELL_BARCODE_TAG ${cellBarcodeTag} \
          --MOLECULAR_BARCODE_TAG ${molecularBarcodeTag} \
          --STRAND_STRATEGY ${strandStrategy} \
          --CELL_BC_FILE ${selectedCells} \
          --CELL_CONTAMINATION_ESTIMATE_FILE ${cbrbCellSelectionReport} \
          --ALLELE_FREQUENCY_ESTIMATE_FILE ${alleleFrequency} \
          --FUNCTIONAL_STRATEGY ${functionalStrategy} \
          ${locusFunctionArgs} \
          ${nonAutosomesString}
    """
}