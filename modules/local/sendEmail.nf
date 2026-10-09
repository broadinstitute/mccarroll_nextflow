process SEND_EMAIL {
    executor 'local'

    input:
    val subject
    val body
    val to
    val attachments

    output:
    // We don't need this for caching, but it ensures that the file creation below succeeded.
    path 'email_sent.txt'

    exec:
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
    task.workDir.resolve('email_sent.txt').text = "Sent '${subject}' to ${to} at ${new Date()}\n"

    stub:
    """
    echo "Subject: $subject"
    echo "Body: $body"
    echo "To: $to"
    echo "Attach: $attachments"
    echo "Sent '${subject}' to $to at ${new Date()}" > email_sent.txt
    """
}
