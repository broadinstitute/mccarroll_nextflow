process CREATE_INTERVALS {
    tag "$sample_name"
    publishDir "${params.output_dir}/intervals", mode: 'copy'
    
    input:
    path molbc_umis
    val sample_name
    
    output:
    path "${sample_name}.intervals.txt", emit: intervals
    
    script:
    """
    CreateIntervalsFromMolecularBarcodes.py \\
        --input ${molbc_umis} \\
        --output ${sample_name}.intervals.txt
    """
}
