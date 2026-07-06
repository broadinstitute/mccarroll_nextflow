process SAY_GREETING {
    tag "$greeting"
    label 'process_single'

    container 'docker.io/library/ubuntu:22.04'

    input:
        val greeting

    output:
        path 'greeting.txt', emit: greeting

    script:
    """
    set -euo pipefail

    echo '${greeting}' > greeting.txt
    """

    stub:
    """
    set -euo pipefail

    touch greeting.txt
    """
}
