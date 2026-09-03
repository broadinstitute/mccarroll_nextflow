#!/usr/bin/env nextflow

nextflow.enable.strict = true
nextflow.enable.types = true

include { TWILIO_EMAIL_SEND } from '../../modules/local/twilioSendEmail.nf'

params {
    from_address: String
    to_address: String
    subject: String
    text: String
}

workflow {
    main:
    requests = channel.of(
        record(
            from_address: params.from_address,
            to_address: params.to_address,
            subject: params.subject,
            text: params.text
        )
    )

    results_ch = TWILIO_EMAIL_SEND(requests)

    publish:
    results = results_ch
}

output {
    results {}
}
