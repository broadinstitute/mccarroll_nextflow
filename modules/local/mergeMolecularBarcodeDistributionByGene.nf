process MERGE_MOLECULAR_BARCODE_DISTRIBUTION_BY_GENE {
    label 'process_low'
     container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_java:current'

    input:
    val library
    path chimericTranscripts

    output:
    path "${output_file}", emit: chimericTranscripts

    script:
    output_file = library + ".chimeric_transcripts.txt.gz"

    """
    MergeMolecularBarcodeDistributionByGene \
        --INPUT ${chimericTranscripts.join(' --INPUT ')} \
        --OUTPUT ${output_file} \
        --COLUMN_FLEXIBILTY  true
    """
}