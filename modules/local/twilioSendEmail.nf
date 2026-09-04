#!/usr/bin/env nextflow

nextflow.enable.strict = true
nextflow.enable.types = true

process TWILIO_EMAIL_SEND {
    container 'twilio/twilio-cli'

    secret 'SENDGRID_API_KEY'

    input:
    record(
        from: String,
        to: String,
        subject: String,
        text: String
    )

    output:
    record(
        done: true
    )

    script:
    """
    set -euo pipefail
    if [ -z "\${SENDGRID_API_KEY:-}" ]; then
        echo "SENDGRID_API_KEY is not set" >&2
        exit 1
    fi
    twilio email:send \\
        --from "${from}" \\
        --to "${to}" \\
        --subject "${subject}" \\
        --text "${text}" \\
        --no-attachment
    """

    stub:
    """
    echo "TWILIO_EMAIL_SEND stub"
    """
}
