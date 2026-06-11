process MAPMYCELLS_FROMSPECIFIEDMARKERS {
    label 'process_single_medium'
    label 'error_retry'

    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/mapmycells:current'

    input:
        val library
        path query_markers_json
        path precomputed_stats_h5ad
        path dge_h5ad
        val mmc_args

    output:
    path "${json_report}", emit: json_report
    path "${csv_report}", emit: csv_report

    script:
    json_report = "${library}.json"
    csv_report = "${library}.csv"
    """
    python -m cell_type_mapper.cli.from_specified_markers \
        --query_markers.serialized_lookup '${query_markers_json}' \
        --precomputed_stats.path '${precomputed_stats_h5ad}' \
        --query_path '${dge_h5ad}' \
        --extended_result_path '${json_report}' \
        --csv_result_path '${csv_report}' \
        ${mmc_args} --type_assignment.normalization raw \
        --query_gene_id_col gene_ids \
        --type_assignment.n_processors 1 \
        --max_gb 8
    """
}