process dge_to_h5ad {
    label 'process_medium'
    label 'conversion'
    
    publishDir params.outdir, mode: 'copy'
    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_python:current'
    memory '8 GB'

    input:
        path dge_matrix
        path reduced_gtf
        val output_file

    output:
    path "${output_file}", emit: h5ad

    script:
    """
    dge_to_h5ad --input '${dge_matrix}' \
        --output '${output_file}' \
        --reduced-gtf '${reduced_gtf}'
    """
}