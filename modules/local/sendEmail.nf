process SEND_EMAIL {
    executor 'local'

    input:
    val subject
    val body
    val to
    val attachments

    output:
    // We don't need this for caching, but it ensures that the file creation below succeeded.
    path 'email_status.txt'

    // `when` depracated. However, large attachments are crashing.
    // A failure here is producing an error that (possibly) triggers joins to fail and killing the workflow.
    // https://docs.seqera.io/nextflow/strict-syntax#process-when-section
    // For now adding lots of opt-outs including this `when`.
    // Will replace with something more comprehensive when possible. -kshakir 2026-10-12
    when:
        task.ext.when == null || task.ext.when

    exec:
    try {
        sendMail(
            subject: subject,
            body: body,
            to: to,
            attach: attachments
        )
        // Nextflow won't cache jobs without a work directory.
        // Make sure to write back to the work directory, especially in a bucket.
        // Bucket paths don't create empty directories automatically.
        // https://github.com/nextflow-io/nextflow/issues/6246#issuecomment-3558617569
        task.workDir.resolve('email_status.txt').text = "Sent '${subject}' to ${to} at ${new Date()}\n"
    } catch (Exception e) {
        log.error("Failed to send email. Subject: ${subject}\nBody: ${body}\nTo: ${to}\nAttachments: ${attachments}", e)
        def text = "Failed to send email. Subject: ${subject}\nBody: ${body}\nTo: ${to}\nAttachments: ${attachments}\n"
        text += e.toString() + "\n"
        e.getStackTrace().each { stackTraceElement ->
            text += stackTraceElement.toString() + "\n"
        }
        task.workDir.resolve('email_status.txt').text = text
        if (task.ext.throw_on_error ?: false) {
            throw e
        }
    }

    stub:
    """
    echo "Stubbed sending '${subject}' to $to at ${new Date()}" > email_status.txt
    """
}
