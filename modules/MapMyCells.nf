process mapMyCells_fromSpecifiedMarkers {
    publishDir 'results', mode: 'copy'
    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/mapmycells:current'
    memory '16 GB'

    input:
        path query_markers_json
        path precomputed_stats_h5ad
        path dge_h5ad
        path gene_mapping
        val mmc_args
        val analysis_identifier

    output:
    path "${analysis_identifier}.json"
    path "${analysis_identifier}.csv"

    script:
    """
    python -m cell_type_mapper.cli.from_specified_markers \
        --query_markers.serialized_lookup '${query_markers_json}' \
        --precomputed_stats.path '${precomputed_stats_h5ad}' \
        --query_path '${dge_h5ad}' \
        --extended_result_path '${analysis_identifier}.json' \
        --csv_result_path '${analysis_identifier}.csv' \
        ${gene_mapping? "--gene_mapping.db_path '${gene_mapping}'" : ""} \
        ${mmc_args} --type_assignment.normalization raw
    """
}