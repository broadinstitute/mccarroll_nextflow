process CHECK_BARCODE_ACCEPTANCE_RATE {
    // exec: blocks run natively in the Nextflow JVM and cannot be dispatched to
    // google-batch (or any grid/cloud executor), so pin this process to the
    // local executor. This also silences the "cannot be executed by
    // 'google-batch' executor -- Using 'local' executor instead" warning.
    executor 'local'

    input:
    // metricsFile is a val rather than a path because apparently nextflow will not stage files
    // for exec: blocks.  Declaring metricsFile causes the full path to be available as a string 
    // rather than a staged file path.
    val metricsFile 
    val minFraction

    output:
    path resultFileName

    exec:
    // Intentionally no 'def' so the variable is bound in the task context and visible to output:
    resultFileName = 'barcode_acceptance_rate.txt'
    def lines = metricsFile.readLines()
        .findAll { line -> !line.isEmpty() && !line.startsWith('#') }
    if (lines.size() < 2) {
        error "No data rows found in ${metricsFile}"
    }
    def headers = lines[0].split('\t') as List
    def values  = lines[1].split('\t') as List
    def row = [headers, values].transpose().collectEntries()
    def readsRejected = row['READS_REJECTED'].toLong()
    def readsAccepted = row['READS_ACCEPTED'].toLong()
    def total = readsAccepted + readsRejected
    def fraction = total > 0 ? (readsAccepted / total.doubleValue()) : 0.0
    def summary = "${String.format('%.4f', fraction)} " +
                  "(${readsAccepted} accepted out of ${total} total)"
    def resultFile = task.workDir.resolve(resultFileName)
    if (fraction < minFraction) {
        def msg = "Barcode acceptance rate ${String.format('%.4f', fraction)} is below minimum allowed " +
                  "${minFraction} (${readsAccepted} accepted out of ${total} total reads in ${metricsFile.name})"
        resultFile.text = "FAILURE: ${msg}\n"
        error msg
    }
    resultFile.text = "SUCCESS: Barcode acceptance rate: ${summary}\n"
    log.info "Barcode acceptance rate: ${summary}"
}
