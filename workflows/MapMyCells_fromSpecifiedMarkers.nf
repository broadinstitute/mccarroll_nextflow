

include { MAPMYCELLS_FROMSPECIFIEDMARKERS } from '../modules/local/MapMyCells_fromSpecifiedMarkers.nf'
include { DGE_TO_H5AD                     } from '../modules/local/dge_to_h5ad.nf'
include { MTX_TO_H5AD                     } from '../modules/local/mtx_to_h5ad.nf'

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

    main:
    // Handle h5ad conversion based on input type
    // Priority: dge_h5ad > dge_matrix+gtf > matrix_mtx+features+barcodes
    def h5ad_ch
    def converted_h5ad_ch
    
    if (dge_h5ad) {
        h5ad_ch = dge_h5ad
        converted_h5ad_ch = channel.empty() // No conversion needed
    } else if (dge_matrix && reduced_gtf) {
        h5ad_ch = DGE_TO_H5AD(
                dge_matrix,
                reduced_gtf,
                "${analysis_identifier}.h5ad")
        converted_h5ad_ch = h5ad_ch
    } else if (matrix_mtx && features_tsv && barcodes_tsv) {
        h5ad_ch = MTX_TO_H5AD(
                matrix_mtx,
                features_tsv,
                barcodes_tsv,
                "${analysis_identifier}.h5ad")
        converted_h5ad_ch = h5ad_ch
    } else {
        error "One of the following must be provided: dge_h5ad, or (dge_matrix, reduced_gtf), " +
                "or (matrix_mtx, features_tsv, barcodes_tsv)."
    }
    
    MAPMYCELLS_FROMSPECIFIEDMARKERS(
            query_markers_json,
            precomputed_stats_h5ad,
            h5ad_ch,
            gene_mapping,
            mmc_args,
            analysis_identifier)

    emit:
    json_report = MAPMYCELLS_FROMSPECIFIEDMARKERS.out.json_report
    csv_report = MAPMYCELLS_FROMSPECIFIEDMARKERS.out.csv_report
    converted_h5ad = converted_h5ad_ch

}

