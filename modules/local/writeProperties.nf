process WRITE_PROPERTIES {
    label 'process_single'

    // TODO: this should run locally, or at least use a very lightweight container 
    container 'quay.io/broadinstitute/drop-seq_r:current'

    input:
    val properties

    output:
    path "${output_file}"

    script:
    output_file = "properties.yaml"
    def yaml_str = YamlUtils.toBlockYaml(properties)

    """
    cat > '${output_file}' << EOF
${yaml_str}
EOF
    """
}
