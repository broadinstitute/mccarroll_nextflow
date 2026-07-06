include { SAY_GREETING } from '../../../modules/launch_downstream/say_greeting/say_greeting.nf'
include { validateParameters; paramsSummaryLog } from 'plugin/nf-schema'

workflow {

    main:
    validateParameters()
    log.info paramsSummaryLog(workflow)

    SAY_GREETING(channel.of(params.greeting))
}
