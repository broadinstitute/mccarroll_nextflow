#!/usr/bin/env nextflow

nextflow.enable.strict = true
nextflow.enable.types = true

process EXAMPLE {
    container 'ubuntu'

    input:
    record(
        message: String
    )

    script:
    """
    echo "$message" > content.txt
    """

    output:
    record(
        example_file: file('content.txt')
    )
}

workflow {
    main:
    def ch_example = EXAMPLE(record(message: "Hello, World!"))

    publish:
    example = ch_example

    onComplete:
    println "Workflow complete."
    println "Workflow output directory: ${workflow.outputDir.toUriString()}"
    println "Workflow output exists?: ${workflow.outputDir.exists()}"
    println "Workflow output contents: ${workflow.outputDir.listDirectory()}"
    println("workflow:\nBEGIN\n${workflow}".replaceAll(", ", ",\n") + "\nEND")
    println("workflow.platform:\nBEGIN\n${workflow.platform}".replaceAll(", ", ",\n") + "\nEND")
}

output {
    example {
        path { r ->
            println "Path: ${r.example_file.toUriString()}"
            "other_dir/"
        }
    }
}
