process WRITE_PROPERTIES {
    label 'process_single'

    // exec: blocks run natively in the Nextflow JVM and cannot be dispatched to
    // google-batch (or any grid/cloud executor), so pin this process to the
    // local executor. This also silences the "cannot be executed by
    // 'google-batch' executor -- Using 'local' executor instead" warning.
    executor 'local'

    input:
    val properties

    output:
    path "${output_filename}"

    exec:
    output_filename = "properties.yaml"
    def output_file = task.workDir.resolve(output_filename)
    output_file.text = YamlUtils.toBlockYaml(properties)
}
