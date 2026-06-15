// Collect a channel of tuple(meta, value) in which meta.collectIndex is an integer on which to sort.
// Return the collected values in order by collectIndex.  Return value is a channel containing a single list item.
def collectInOrder(inChannel) {
    def ret = inChannel
        .map { meta, value ->
            tuple(meta.collectIndex, value)
        }
        .toSortedList { a, b -> a[0] <=> b[0] }
        .map { sorted ->
            sorted.collect { pair ->
                pair[1]
            }
        }

    return ret
}

// Take 3 channels of tuple(meta, file) and return a channel of tuple(meta, list-of-files).
// It is assumed that the meta is the same for all the inputs so any can be used.
def sparseMatrixChannelHelper(sparseDgeMatrix, sparseDgeFeatures, sparseDgeBarcodes) {
    def sparseDgeFeaturesNoMeta = sparseDgeFeatures.map { _meta, file -> file }
    def sparseDgeBarcodesNoMeta = sparseDgeBarcodes.map { _meta, file -> file }
    return sparseDgeMatrix.combine(sparseDgeFeaturesNoMeta).combine(sparseDgeBarcodesNoMeta).map { meta, mat, feat, barc ->
        tuple(meta, [mat, feat, barc])
    }
}

// Take a channel of tuple(meta, file) and return a channel of just the files.  Assumes meta is not needed.
def noMetaChannelHelper(channel) {
    return channel.map { _meta, file -> file }
}

// Take a channel of tuple(meta, file) and return a channel of just the meta.  Assumes file is not needed.
def metaOnlyChannelHelper(channel) {
    return channel.map { meta, _file -> meta }
}

// Combines two channels (assumed to each contain a single item) into a channel of tuple(value1, value2)
def combineIntoTupleChannel(channel1, channel2) {
    return channel1.combine(channel2).map { v1, v2 ->
        tuple(v1, v2)
    }
}

def addMeta(meta, channel) {
    return channel.map { file ->
        tuple(meta, file)
    }
}