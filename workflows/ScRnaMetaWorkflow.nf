include { MapMyCells_fromSpecifiedMarkers_workflow } from './MapMyCells_fromSpecifiedMarkers.nf'


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