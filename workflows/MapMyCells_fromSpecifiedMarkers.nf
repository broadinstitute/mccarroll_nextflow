

params.query_markers_json = ''
params.precomputed_stats_h5ad = ''
params.dge_h5ad = ''
params.dge_matrix = ''
params.reduced_gtf = ''
params.mmc_args = ''
params.gene_mapping = ''
params.analysis_identifier = 'mapmycells_analysis'

include { mapMyCells_fromSpecifiedMarkers } from '../modules/MapMyCells.nf'
include { dge_to_h5ad } from '../modules/dge_to_h5ad.nf'

workflow {
    if (params.dge_h5ad == '') {
        params.dge_h5ad = "${params.analysis_identifier}.h5ad"
        if (params.dge_matrix != '' && params.reduced_gtf != '') {
            dge_to_h5ad(
                    params.dge_matrix,
                    params.reduced_gtf,
                    params.dge_h5ad)
        } else {
            error "Either provide params.dge_h5ad or both params.dge_matrix and params.reduced_gtf"
        }
    }
    mapMyCells_fromSpecifiedMarkers(
        params.query_markers_json,
        params.precomputed_stats_h5ad,
        params.dge_h5ad,
        params.gene_mapping,
        params.mmc_args,
        params.analysis_identifier)
}