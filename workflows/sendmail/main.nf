#!/usr/bin/env nextflow

nextflow.enable.strict = true
nextflow.enable.types = true

include { TWILIO_EMAIL_SEND } from '../../modules/local/twilioSendEmail.nf'

params {
    from: String
    to: String
    subject: String
    text: String
}

workflow {

    main:

    def results_ch = TWILIO_EMAIL_SEND(
        record(
            from: params.from,
            to: params.to,
            subject: params.subject,
            text: params.text + "\n\nvia twilio process",
        )
    )

    results_ch
        .map { it -> it.done }
        .subscribe { done ->
            if (!workflow.stubRun) {
                sendMail(
                    from: params.from,
                    to: params.to,
                    subject: params.subject,
                    text: params.text + "\n\nvia sendMail() with done=${done}",
                )
            }
        }

    publish:
    results = results_ch
}

output {
    results {
    }
}
