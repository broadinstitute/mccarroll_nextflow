process MAKE_TRIPLET_DGE {
    label 'process_low'
    container 'quay.io/broadinstitute/drop-seq_java:current'

    input:
    tuple val(meta), path(denseDge)
    path reducedGtf

    output:
    tuple val(meta), path("${matrix}"), emit: matrix
    tuple val(meta), path("${features}"), emit: features
    tuple val(meta), path("${barcodes}"), emit: barcodes

    script:
    matrix = "matrix.mtx.gz"
    features = "features.tsv.gz"
    barcodes = "barcodes.tsv.gz"

    """
    MakeTripletDge \
        --YAML "dges: [{dge: ${denseDge}}]" \
        --OUTPUT ${matrix} \
        --OUTPUT_FEATURES ${features} \
        --OUTPUT_CELLS ${barcodes} \
        --REDUCED_GTF ${reducedGtf}
    """
}