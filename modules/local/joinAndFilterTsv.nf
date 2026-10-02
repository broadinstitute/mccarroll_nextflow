process JOIN_AND_FILTER_TSV {
    label 'process_low'

    container 'quay.io/broadinstitute/drop-seq_python:current'

    input:
    tuple val(meta), path(file)
    val outputFileName
    val dropColumns
    // for each input tuple, the length of the lists in the tuple must match
    tuple path(joinFiles), val(inputColumns), val(joinColumns)
    tuple val(setColumns), val(setValues)
    tuple val(minColumns), val(minValues)
    tuple val(maxColumns), val(maxValues)
    tuple val(includeFiles), val(includeFileColumns)
    tuple val(excludeFiles), val(excludeFileColumns)
    tuple val(includes), val(includeColumns)
    tuple val(excludes), val(excludeColumns)
    tuple val(renameFromColumns), val(renameFromValues)
    val noHeader
    output:
    tuple val(meta), path(outputFileName), emit: joinedAndFiltered
    

    script:
    def otherArgs = ""
    otherArgs += [joinFiles, inputColumns, joinColumns].transpose().collect { joinFile, inputColumn, joinColumn ->
        "--join $joinFile $inputColumn $joinColumn"
    }.join(" ") + " "
    otherArgs += [setColumns, setValues].transpose().collect { setColumn, setValue ->
        "--set $setColumn $setValue"
    }.join(" ") + " "
    otherArgs += dropColumns.collect { dropColumn ->
        "--drop $dropColumn"
    }.join(" ") + " "
    otherArgs += [includeFiles, includeFileColumns].transpose().collect { includeFile, includeFileColumn ->
        "--include-file $includeFile $includeFileColumn"
    }.join(" ") + " "
    otherArgs += [excludeFiles, excludeFileColumns].transpose().collect { excludeFile, excludeFileColumn ->
        "--exclude-file $excludeFile $excludeFileColumn"
    }.join(" ") + " "
    otherArgs += [includes, includeColumns].transpose().collect { _include, includeColumn ->
        "--include $_include $includeColumn"
    }.join(" ") + " "
    otherArgs += [excludes, excludeColumns].transpose().collect { exclude, excludeColumn ->
        "--exclude $exclude $excludeColumn"
    }.join(" ") + " " 
    otherArgs += [renameFromColumns, renameFromValues].transpose().collect { renameFromColumn, renameFromValue ->
        "--rename $renameFromColumn $renameFromValue"
    }.join(" ") + " "
    if (noHeader) {
        otherArgs += "--no-header "
    }
    """
    join_and_filter_tsv \
    --input $file \
    --output $outputFileName \
    $otherArgs
    """
}