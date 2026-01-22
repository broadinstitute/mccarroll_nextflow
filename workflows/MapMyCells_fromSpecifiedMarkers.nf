

params.query_markers_json = ''
params.precomputed_stats_h5ad = ''
params.dge_h5ad = ''
params.dge_matrix = ''
params.reduced_gtf = ''
params.matrix_mtx = ''
params.features_tsv = ''
params.barcodes_tsv = ''
params.mmc_args = ''
params.gene_mapping = ''
params.analysis_identifier = 'mapmycells_analysis'

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
    converted_h5ad = (params.dge_h5ad == '' ? "${params.analysis_identifier}.h5ad": '')

    main:
    if (params.dge_h5ad == '') {
        if (params.dge_matrix != '' && params.reduced_gtf != '') {
            converted_h5ad = dge_to_h5ad(
                    params.dge_matrix,
                    params.reduced_gtf,
                    "${params.analysis_identifier}.h5ad")
        } else if (params.matrix_mtx != '' && params.features_tsv != '' && params.barcodes_tsv != '') {
            converted_h5ad = mtx_to_h5ad(
                    params.matrix_mtx,
                    params.features_tsv,
                    params.barcodes_tsv,
                    "${params.analysis_identifier}.h5ad")

        } else {
            error "One of the following must be provided: params.dge_h5ad, or (params.dge_matrix, params.reduced_gtf), " +
                    "or (params.matrix_mtx, params.features_tsv, params.barcodes_tsv)."
        }
    } else {
        converted_h5ad = file(params.dge_h5ad)
    }
    mapMyCells_fromSpecifiedMarkers(
            params.query_markers_json,
            params.precomputed_stats_h5ad,
            converted_h5ad,
            params.gene_mapping,
            params.mmc_args,
            params.analysis_identifier)

}

workflow {
    main:
    MapMyCells_fromSpecifiedMarkers_workflow(
        params.query_markers_json,
        params.precomputed_stats_h5ad,
        params.dge_h5ad,
        params.dge_matrix,
        params.reduced_gtf,
        params.matrix_mtx,
        params.features_tsv,
        params.barcodes_tsv,
        params.mmc_args,
        params.gene_mapping,
        params.analysis_identifier)
    publish:
    converted_h5ad = MapMyCells_fromSpecifiedMarkers_workflow.out.converted_h5ad
}

output {
    converted_h5ad {
        path: 'converted_h5ad'
    }
}