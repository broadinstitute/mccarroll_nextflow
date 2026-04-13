def locusFunctionClpArguments(locusFunction) {
    // Map from desired locus function to values to be passed to the 'LOCUS_FUNCTION_LIST' command-line argument.  
    // Because the default is EXONIC, (actually CODING, UTR), all that is necessary is to add INTRONIC if requested,
    // and clear EXONIC if only INTRONIC is requested.
    def locusFunctionClpMap = [
        'EXONIC_INTRONIC': ['INTRONIC'],
        'EXONIC': [],
        'INTRONIC': ['null', 'INTRONIC']
    ]
    def clpValues = locusFunctionClpMap[locusFunction]
    if (clpValues == null) {
        error "Invalid locus function: ${locusFunction}.  Valid options are: ${locusFunctionClpMap.keySet().join(', ')}"
    }
    return clpValues.collect { value -> "--LOCUS_FUNCTION_LIST ${value}" }.join(' ')
}