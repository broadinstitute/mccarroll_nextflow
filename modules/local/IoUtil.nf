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
    def rows = tsvFile.splitCsv(header: true, sep: '\t')
    assert rows.size() == 1 : "Expected exactly 2 lines in ${tsvFile}, found ${rows.size() + 1}"   
    return rows.first()
}
