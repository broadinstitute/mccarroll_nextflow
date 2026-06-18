process DUMP_ELBO_TABLE {
    label 'process_low'

    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/drop-seq_private_python:current'

    input:
        val library
        path h5

    output:
    path "${output_file}"

    script:
    output_file = "${library}.elbo.txt"
    """
    dump_elbo_table --input '${h5}' \
        --output '${output_file}'
    """

}