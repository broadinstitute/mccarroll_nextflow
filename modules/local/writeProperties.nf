process WRITE_PROPERTIES {
    label 'process_single'

    // TODO: this should run locally, or at least use a very lightweight container 
    container 'quay.io/broadinstitute/drop-seq_r:current'

    input:
    val properties

    output:
    path "${output_filename}"

    exec:
    output_filename = "properties.yaml"
    def output_file = task.workDir.resolve(output_filename)
    output_file.text = YamlUtils.toBlockYaml(properties)
}
