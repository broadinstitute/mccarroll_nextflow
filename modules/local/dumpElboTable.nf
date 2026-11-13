process DUMP_ELBO_TABLE {
    tag "${library}"
    label 'process_low'

    container 'us.gcr.io/mccarroll-scrna-seq/drop-seq_private_python:current'

    input:
    val library
    path h5

    output:
    path "${output_file}", emit: elboTable
   tuple val("${task.process}"), val('dumpElboTable'), eval("cat /etc/dropseq-version"), topic: versions, emit: versions_dumpElboTable

    script:
    output_file = "${library}.elbo.txt"
    """
    dump_elbo_table --input '${h5}' \
        --output '${output_file}'
    """
}
