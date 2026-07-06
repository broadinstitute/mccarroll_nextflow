include { MAKE_GREETINGS } from '../../../modules/launch_downstream/make_greetings/make_greetings.nf'
include { LAUNCH_HELLO }   from '../../../modules/launch_downstream/launch_hello/launch_hello.nf'
include { validateParameters; paramsSummaryLog } from 'plugin/nf-schema'

workflow {

    main:
    validateParameters()
    log.info paramsSummaryLog(workflow)

    if (!params.seqeraWorkspace || !params.computeEnv) {
        error "Required: --seqeraWorkspace <org/workspace> and --computeEnv <compute-env-name>"
    }

    MAKE_GREETINGS()

    def greetings = MAKE_GREETINGS.out.greetings
        .splitText()
        .map { line -> line.trim() }
        .filter { line -> line }

    LAUNCH_HELLO(greetings)
}
