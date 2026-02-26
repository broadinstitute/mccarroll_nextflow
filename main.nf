include { MapMyCells_fromSpecifiedMarkers_workflow } from './workflows/MapMyCells_fromSpecifiedMarkers.nf'

params {
    query_markers_json: Path
    precomputed_stats_h5ad: Path
    dge_h5ad: Path
    dge_matrix: Path
    reduced_gtf: Path
    matrix_mtx: Path
    features_tsv: Path
    barcodes_tsv: Path
    mmc_args: String
    gene_mapping: Path
    analysis_identifier: String
}

// Validation helper function
def validateInputs() {
    // Validate required parameters
    if (!params.query_markers_json) {
        error "ERROR: --query_markers_json is required. Please provide the path to the query markers JSON file."
    }
    if (!params.precomputed_stats_h5ad) {
        error "ERROR: --precomputed_stats_h5ad is required. Please provide the path to the precomputed stats H5AD file."
    }
    if (!params.gene_mapping) {
        error "ERROR: --gene_mapping is required. Please provide the path to the gene mapping file."
    }
    
    // Validate that at least one input format is provided
    def has_dge_h5ad = params.dge_h5ad ? true : false
    def has_dge_matrix = params.dge_matrix && params.reduced_gtf
    def has_matrix_mtx = params.matrix_mtx && params.features_tsv && params.barcodes_tsv
    
    if (!has_dge_h5ad && !has_dge_matrix && !has_matrix_mtx) {
        error """
        ERROR: At least one input format must be provided:
        - Option 1: --dge_h5ad (H5AD file)
        - Option 2: --dge_matrix AND --reduced_gtf (DGE format)
        - Option 3: --matrix_mtx, --features_tsv, AND --barcodes_tsv (10x format)
        """
    }
}

// Main workflow
workflow {
    main:
    // Validate inputs
    validateInputs()
    
    // Create channels from required file parameters
    def query_markers_ch = channel.fromPath(params.query_markers_json, checkIfExists: true)
    def precomputed_stats_ch = channel.fromPath(params.precomputed_stats_h5ad, checkIfExists: true)
    def gene_mapping_ch = channel.fromPath(params.gene_mapping, checkIfExists: true)
    
    // Create channels for optional files - use null for missing files
    def dge_h5ad_ch = params.dge_h5ad ? channel.fromPath(params.dge_h5ad, checkIfExists: true) : null
    def dge_matrix_ch = params.dge_matrix ? channel.fromPath(params.dge_matrix, checkIfExists: true) : null
    def reduced_gtf_ch = params.reduced_gtf ? channel.fromPath(params.reduced_gtf, checkIfExists: true) : null
    def matrix_mtx_ch = params.matrix_mtx ? channel.fromPath(params.matrix_mtx, checkIfExists: true) : null
    def features_tsv_ch = params.features_tsv ? channel.fromPath(params.features_tsv, checkIfExists: true) : null
    def barcodes_tsv_ch = params.barcodes_tsv ? channel.fromPath(params.barcodes_tsv, checkIfExists: true) : null
    
    // Execute MapMyCells workflow
    MapMyCells_fromSpecifiedMarkers_workflow(
        query_markers_ch,
        precomputed_stats_ch,
        dge_h5ad_ch,
        dge_matrix_ch,
        reduced_gtf_ch,
        matrix_mtx_ch,
        features_tsv_ch,
        barcodes_tsv_ch,
        params.mmc_args,
        gene_mapping_ch,
        params.analysis_identifier
    )
    
    publish:
    json_report = MapMyCells_fromSpecifiedMarkers_workflow.out.json_report
    csv_report = MapMyCells_fromSpecifiedMarkers_workflow.out.csv_report
    converted_h5ad = MapMyCells_fromSpecifiedMarkers_workflow.out.converted_h5ad
}

output {
    json_report{
        mode 'copy'
    }
    csv_report{
        mode 'copy'
    }
    converted_h5ad{
        mode 'copy'
    }
}
