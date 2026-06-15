process WRITE_PROPERTIES {
    label 'process_single'

    container 'us-docker.pkg.dev/mccarroll-scrna-seq/us.gcr.io/mapmycells:current'

    input:
        val properties

    output:
        path "${output_file}"

    script:
    output_file = "properties.yaml"
    // Configure options to force Newline (Block) style
    options = new org.yaml.snakeyaml.DumperOptions()
    options.setDefaultFlowStyle(org.yaml.snakeyaml.DumperOptions.FlowStyle.BLOCK)
    options.setPrettyFlow(true) // Ensures clean alignment
    def yaml_str = new org.yaml.snakeyaml.Yaml(options).dump(properties)

    """
    cat > '${output_file}' << EOF
${yaml_str}
EOF
    """
}