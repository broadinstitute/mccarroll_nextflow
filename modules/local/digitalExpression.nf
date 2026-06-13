include { locusFunctionClpArguments } from '../../modules/local/locusFunction.nf'

process DIGITAL_EXPRESSION {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    tuple val(meta), path(inputBam), path(selectedCells)
    val locusFunction
    val library
    val strandStrategy
    val readQuality
    val functionalStrategy
    val cellBarcodeTag
    val molecularBarcodeTag
    val doMetaGenes

    output:
    tuple val(meta), path("${output_file}"), emit: dge
    tuple val(meta), path("${summary_file}"), emit: dge_summary

    script:
    output_file = "${meta.id}.digital_expression.txt.gz"
    summary_file = "${meta.id}.digital_expression_summary.txt"
    locusFunctionArgs = locusFunctionClpArguments(locusFunction)
    if (doMetaGenes) {
        metagene_args = "--GENE_NAME_TAG mn --GENE_STRAND_TAG ms --GENE_FUNCTION_TAG mf"
    } else {
        metagene_args = ""
    }
    """
    DigitalExpression \
        --INPUT ${inputBam} \
        --OUTPUT ${output_file} \
        --SUMMARY ${summary_file} \
        --READ_MQ ${readQuality} \
        --MIN_BC_READ_THRESHOLD 0 \
        --CELL_BC_FILE ${selectedCells} \
        --OUTPUT_HEADER true \
        --OMIT_MISSING_CELLS true \
        --FUNCTIONAL_STRATEGY ${functionalStrategy} \
        --UEI ${library} \
        --CELL_BARCODE_TAG ${cellBarcodeTag} \
        --MOLECULAR_BARCODE_TAG ${molecularBarcodeTag} \
        --STRAND_STRATEGY ${strandStrategy} \
        ${locusFunctionArgs} \
        ${metagene_args}
    """
}