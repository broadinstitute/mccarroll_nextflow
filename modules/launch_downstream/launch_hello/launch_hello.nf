process LAUNCH_HELLO {
    tag "$greeting"
    label 'process_single'

    container 'quay.io/biocontainers/seqerakit:0.5.7--pyhdfd78af_0'

    // First testing if this is available by default.
    secret 'TWR_ACCESS_TOKEN'

    input:
        val greeting

    script:
    sanitizedGreeting = greeting.replaceAll(/[^A-Za-z0-9]+/, '-').toLowerCase().replaceAll(/^-+|-+$/, '')
    if (!sanitizedGreeting) {
        sanitizedGreeting = 'greeting'
    }
    // Run names must be unique per workspace, so suffix with a timestamp.
    def timestamp = new java.text.SimpleDateFormat('yyyyMMddHHmmss').format(new Date())
    def runName = "hello-${sanitizedGreeting}-${timestamp}"
    def mainScriptLine = params.helloMainScript ? "main-script: \"${params.helloMainScript}\"" : ''
    def schemaLine = params.helloSchema ? "schema-name: \"${params.helloSchema}\"" : ''
    def revisionLine = params.helloRevision ? "revision: \"${params.helloRevision}\"" : ''
    """
    set -euo pipefail

    export TOWER_ACCESS_TOKEN="\${TWR_ACCESS_TOKEN}"
    export TOWER_API_ENDPOINT="${params.towerApiEndpoint}"

    tw info

    cat <<-END_LAUNCH_YAML > launch_${sanitizedGreeting}.yml
    launch:
      - name: "${runName}"
        workspace: "${params.seqeraWorkspace}"
        compute-env: "${params.computeEnv}"
        pipeline: "${params.helloPipeline}"
        ${mainScriptLine}
        ${schemaLine}
        ${revisionLine}
        params:
          greeting: "${greeting}"
    END_LAUNCH_YAML

    seqerakit launch_${sanitizedGreeting}.yml
    """

    stub:
    """
    true
    """
}
