process MAKE_GREETINGS {
    label 'process_single'

    container 'docker.io/library/ubuntu:22.04'

    output:
        path 'greetings.txt', emit: greetings

    script:
    """
    set -euo pipefail

    cat <<-END_GREETINGS > greetings.txt
    Hello
    Bonjour
    Holà
    END_GREETINGS
    """

    stub:
    """
    set -euo pipefail

    cat <<-END_GREETINGS > greetings.txt
    Hello
    Bonjour
    Holà
    END_GREETINGS
    """
}
