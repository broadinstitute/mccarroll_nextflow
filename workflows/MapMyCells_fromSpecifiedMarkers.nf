

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
    main:
    if (params.dge_h5ad == '') {
        if (params.dge_matrix != '' && params.reduced_gtf != '') {
            dge_h5ad = dge_to_h5ad(
                    params.dge_matrix,
                    params.reduced_gtf,
                    "${params.analysis_identifier}.h5ad")
        } else {
            error "Either provide params.dge_h5ad or both params.dge_matrix and params.reduced_gtf"
        }
    } else {
        dge_h5ad = file(params.dge_h5ad)
    }
    mapMyCells_fromSpecifiedMarkers(
        params.query_markers_json,
        params.precomputed_stats_h5ad,
        dge_h5ad,
        params.gene_mapping,
        params.mmc_args,
        params.analysis_identifier)

    publish:
        dge_h5ad = dge_h5ad
}

output {
    dge_h5ad {
        path: 'dge_h5ad'
    }
}