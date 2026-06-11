process MTX_TO_H5AD {
    label 'process_medium'

    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_python:current'
    memory '8 GB'

    input:
        val library
        path matrix_mtx
        path features_tsv
        path barcodes_tsv

    output:
    path "${output_file}"

    script:
    output_file = "${library}.h5ad"
    if (matrix_mtx.getParent() != features_tsv.getParent() || matrix_mtx.getParent() != barcodes_tsv.getParent()) {
        error "All three files (matrix.mtx, features.tsv.gz, barcodes.tsv.gz) must be in the same directory."
    }
    matrix_mtx_required = "matrix.mtx.gz"
    features_tsv_required = "features.tsv.gz"
    barcodes_tsv_required = "barcodes.tsv.gz"
    matrix_mtx_name = matrix_mtx.getName()
    if (!matrix_mtx_name.endsWith(matrix_mtx_required)) {
        error "Matrix file must end with '${matrix_mtx_required}', got '${matrix_mtx_name}'"
    }
    prefix = matrix_mtx_name.substring(0, matrix_mtx_name.length() - matrix_mtx_required.length())
    if (features_tsv.getName() != "${prefix}${features_tsv_required}") {
        error "Features file must be named '${prefix}${features_tsv_required}', got '${features_tsv.getName()}'"
    }
    if (barcodes_tsv.getName() != "${prefix}${barcodes_tsv_required}") {
        error "Barcodes file must be named '${prefix}${barcodes_tsv_required}', got '${barcodes_tsv.getName()}'"
    }
    if (prefix != "") {
            prefix_opt = "--prefix '${prefix}'"
    } else {
            prefix_opt = ""
    }
    """
    mtx_to_h5ad --input-directory . \
        --output '${output_file}' \
        ${prefix_opt}
    """
}