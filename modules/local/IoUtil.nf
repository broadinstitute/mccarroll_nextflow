/**
 * Read a 2-line TSV file into a map.
 *
 * Example file:
 *   sample\tlane\tplatform
 *   S1\tL001\tILLUMINA
 *
 * Returns:
 *   [sample: 'S1', lane: 'L001', platform: 'ILLUMINA']
 */
def readSingleRowTsv(tsvFile) {
    def lines = tsvFile.readLines()

    assert lines.size() == 2 :
        "Expected exactly 2 lines in ${tsvFile}, found ${lines.size()}"

    def header = lines[0].split('\t', -1)
    def values = lines[1].split('\t', -1)

    assert header.size() == values.size() :
        "Header/value column count mismatch in ${tsvFile}"

    return [header, values].transpose().collectEntries { k, v ->
        [(k): v]
    }
}