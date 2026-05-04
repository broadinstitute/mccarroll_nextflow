include { readSingleRowTsv } from "./IoUtil.nf"

// The arguments that we make decisions based on.
def CBRB_ARGS() { 
    [
    expectedCells          : "--expected-cells",
    totalDropletsIncluded  : "--total-droplets-included",
    numTrainingTries       : "--num-training-tries",
    finalElboFailFraction  : "--final-elbo-fail-fraction",
    learningRate           : "--learning-rate"
]
}

// The defaults for these arguments, while --expected-cells and --total-droplets-included are 
// determined using DropSift.
def CBRB_DEFAULTS() { [
    (CBRB_ARGS().numTrainingTries)      : 3,
    (CBRB_ARGS().finalElboFailFraction) : 0.1,
    (CBRB_ARGS().learningRate)          : "0.00000625"
]
}

// Probably don't need this, but a workflow is unusual if it contains options in addition to these.
def USUAL_ARGS() { [
    CBRB_ARGS().expectedCells,
    CBRB_ARGS().totalDropletsIncluded,
    CBRB_ARGS().numTrainingTries,
    CBRB_ARGS().finalElboFailFraction,
    CBRB_ARGS().learningRate
] as Set
}

// Arguments that have values are expected to be passed as --key=value, and flags are expected to be passed as --flag.
// To remove a default argument, pass --key=null.  For example, if you want to remove the default learning rate, you would pass --learning-rate=null.
// Note that whitespace in values is not supported.
def parseArgString(argString) {
    if (!argString) return []

    argString
        .trim()
        .split(/\s+/)
        .findAll { x -> x }   // remove empty
        .collect { token ->
            if (token.contains('=')) {
                def (k, v) = token.split('=', 2)
                [(k): v]
            } else {
                token
            }
        }
}


// Create a dictionary of arguments from the argument string, applying defaults and removing any arguments with null values.
// If an argument has no value, it's value is set to an empty string.
def makeCbrbArgDict(argString) {
    def base = [:] + CBRB_DEFAULTS()
    def parsed = parseArgString(argString)

    parsed.inject(base) { acc, arg ->
        if (arg instanceof String) {
            // flag
            acc + [(arg): ""]
        }
        else if (arg instanceof Map) {
            arg.inject(acc) { a, k, v ->
                    a + [(k): v]
            }
        }
        else {
            acc
        }
    }
}

// --- Build flat CLI list ---

def makeCbrbArgList(argDict) {
    argDict.collectMany { k, v ->
        if (v == null || v.toString() == "null") {
            []
        }
        else if (v instanceof List) {
            [k] + v*.toString()
        }
        else {
            v.toString()
                ? [k, v.toString()]
                : [k]
        }
    }
}


// --- Top-level parser ---

def parseCbrbYamlArgs(argString) {
    def argDict = makeCbrbArgDict(argString)

    [
        argDict                : argDict,
        argList                : makeCbrbArgList(argDict),
        expectedCells          : argDict[CBRB_ARGS().expectedCells] as Integer,
        totalDropletsIncluded  : argDict[CBRB_ARGS().totalDropletsIncluded] as Integer,
    ]
}

// Add settings from svmEstimateCbrbParameters if not overridden by user
def addSvmEstimatedParameters(parsedYamlArgs, svmEstimatedParamsMap) {
    def argDict = svmEstimatedParamsMap + parsedYamlArgs.argDict
    [
        argDict                : argDict,
        argList                : makeCbrbArgList(argDict),
        expectedCells          : argDict[CBRB_ARGS().expectedCells] as Integer,
        totalDropletsIncluded  : argDict[CBRB_ARGS().totalDropletsIncluded] as Integer,
    ]
}

// Read svmEstimateCbrbParameters output and convert to a map of CLI arguments
def loadSvmEstimatedParameters(svmEstimatedParamsFile) {
    def paramLines = readSingleRowTsv(svmEstimatedParamsFile)
    return paramLines.collectEntries { k, v -> [("--" + k.replaceAll("_", "-")): v] }
}