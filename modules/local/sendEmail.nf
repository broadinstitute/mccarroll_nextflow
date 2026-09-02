process SEND_EMAIL {
    secret 'SENDGRID_API_KEY'
    label 'process_low'
    container 'docker.io/twilio/twilio-cli:latest'
    input:
    val subject
    val body
    val to
    path attachments

    script:
    to_arg = to instanceof List ? to.join(', ') : to
    attachments_arg = attachments.collect{f -> "--attachment ${f}"}.join(' ')
    """
    twilio email:send  --to $to_arg --text "$body" $attachments_arg --subject "$subject" --from dropseq@broadinstitute.org
    """

}