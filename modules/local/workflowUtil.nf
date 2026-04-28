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