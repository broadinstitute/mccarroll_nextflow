process MAKE_SPARSE_DGE {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    tuple val(meta), path(denseDge)

    output:
    tuple val(meta), path("${matrix}"), emit: matrix
    tuple val(meta), path("${features}"), emit: features
    tuple val(meta), path("${barcodes}"), emit: barcodes

    script:
    matrix = "matrix.mtx.gz"
    features = "features.tsv.gz"
    barcodes = "barcodes.tsv.gz"

    """
    MergeDge \
        --INPUT ${denseDge} \
        --OUTPUT ${matrix} \
        --OUTPUT_FORMAT MM_SPARSE_10X \
        --OUTPUT_HEADER false \
        --OUTPUT_FEATURES ${features} \
        --OUTPUT_CELLS ${barcodes}
    """
}