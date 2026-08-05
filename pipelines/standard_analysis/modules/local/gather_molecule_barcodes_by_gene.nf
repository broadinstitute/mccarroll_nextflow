process GATHER_MOLECULE_BARCODES_BY_GENE {
    tag "$sample_name"
    publishDir "${params.output_dir}/molecule_barcodes", mode: 'copy'
    
    input:
    path dge_subset
    val sample_name
    
    output:
    path "${sample_name}.molbc_umis.txt.gz", emit: molbc_umis
    
    script:
    """
    GatherMoleculeBarcodesByGene.py \\
        --input ${dge_subset} \\
        --output ${sample_name}.molbc_umis.txt.gz \\
        --sample ${sample_name}
    """
}
