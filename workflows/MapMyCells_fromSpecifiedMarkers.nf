

include { mapMyCells_fromSpecifiedMarkers } from '../modules/MapMyCells_fromSpecifiedMarkers.nf'
include { dge_to_h5ad } from '../modules/dge_to_h5ad.nf'
include { mtx_to_h5ad } from '../modules/mtx_to_h5ad.nf'

workflow MapMyCells_fromSpecifiedMarkers_workflow  {
    take:
        query_markers_json
        precomputed_stats_h5ad
        dge_h5ad
        dge_matrix
        reduced_gtf
        matrix_mtx
        features_tsv
        barcodes_tsv
        mmc_args
        gene_mapping
        analysis_identifier

    emit:
    extended_result_path = "${analysis_identifier}.json"
    csv_result_path = "${analysis_identifier}.csv"
    converted_h5ad = (dge_h5ad == '' ? "${analysis_identifier}.h5ad": '')

    main:
    if (dge_h5ad == '') {
        if (dge_matrix != '' && reduced_gtf != '') {
            converted_h5ad = dge_to_h5ad(
                    dge_matrix,
                    reduced_gtf,
                    "${analysis_identifier}.h5ad")
        } else if (matrix_mtx != '' && features_tsv != '' && barcodes_tsv != '') {
            converted_h5ad = mtx_to_h5ad(
                    matrix_mtx,
                    features_tsv,
                    barcodes_tsv,
                    "${analysis_identifier}.h5ad")

        } else {
            error "One of the following must be provided: dge_h5ad, or (dge_matrix, reduced_gtf), " +
                    "or (matrix_mtx, features_tsv, barcodes_tsv)."
        }
    } else {
        converted_h5ad = file(dge_h5ad)
    }
    mapMyCells_fromSpecifiedMarkers(
            query_markers_json,
            precomputed_stats_h5ad,
            converted_h5ad,
            gene_mapping,
            mmc_args,
            analysis_identifier)

}

