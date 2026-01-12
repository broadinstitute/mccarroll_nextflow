params.query_markers_json = ''
params.precomputed_stats_h5ad = ''
params.dge_h5ad = ''
params.mmc_args = ''
params.gene_mapping = ''
params.analysis_identifier = 'mapmycells_analysis'

include { mapMyCells_fromSpecifiedMarkers } from '../modules/MapMyCells.nf'
workflow {
    mapMyCells_fromSpecifiedMarkers(
        params.query_markers_json,
        params.precomputed_stats_h5ad,
        params.dge_h5ad,
        params.gene_mapping,
        params.mmc_args,
        params.analysis_identifier)
}