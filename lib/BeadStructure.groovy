/*
 * MIT License
 * 
 * Copyright 2026 Broad Institute
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */


import java.util.regex.Pattern

class BeadStructure {

    // -------------------------
    // Static definitions (object equivalent)
    // -------------------------
    static class ElementType {
        String stringRep
        String tag
        String name

        ElementType(String stringRep, String tag, String name) {
            this.stringRep = stringRep
            this.tag = tag
            this.name = name
        }
    }

    static final ElementType Molecular = new ElementType("M", "XM", "Molecular")
    static final ElementType Cellular  = new ElementType("C", "XC", "Cellular")
    static final ElementType Skip      = new ElementType("X", null, "Skip")
    static final ElementType Template  = new ElementType("T", null, "Template")

    static final Map<String, ElementType> ElementTypes = [
            (Molecular.stringRep): Molecular,
            (Cellular.stringRep) : Cellular,
            (Skip.stringRep)     : Skip,
            (Template.stringRep) : Template
    ]

    static final Set<ElementType> IndexElementTypes = [Molecular, Cellular] as Set

    static final String Asterisk = "*"
    static final Pattern BeadStructureRegex = Pattern.compile("([0-9]+|[*])([A-Z])(.*)")

    // -------------------------
    // Element class
    // -------------------------
    static class Element {
        ElementType elementType
        int firstBase
        int length
        int readIndex  // zero-based

        String getRange() {
            "${firstBase}-${firstBase + length - 1}"
        }

        String getStringRep() {
            (length == -1 ? Asterisk : length.toString()) + elementType.stringRep
        }

        String getAsBaseRange() {
            "${firstBase}-${firstBase + length - 1}"
        }
    }

    // -------------------------
    // Instance fields
    // -------------------------
    String structureString
    List<Integer> readLengths
    List<Element> elements

    BeadStructure(String structureString, List<Integer> readLengths = null) {
        this.structureString = structureString
        this.readLengths = readLengths
        this.elements = parse(structureString, readLengths)

        if (!elements.any { it.elementType == Template }) {
            throw new RuntimeException("Bead structure '${structureString}' does not contain T operator.")
        }

        // Validate per-read uniqueness
        groupedElements.values().each { group ->
            def readIndexSet = group.collect { it.readIndex }.toSet()
            if (readIndexSet.size() > 1) {
                throw new RuntimeException(
                        "In bead structure ${structureString}, operator '${group[0].elementType.stringRep}' appears in more than one read."
                )
            }
        }

        // Validate read lengths
        if (readLengths != null) {
            readLengths.eachWithIndex { readLength, readIndex ->
                int sum = elements.findAll { it.readIndex == readIndex }
                        .collect { it.length }
                        .sum() ?: 0
                if (sum != readLength) {
                    throw new RuntimeException(
                            "Error in bead structure '${structureString}'. " +
                                    "For read ${readIndex + 1}, sum of bead structure elements (${sum}) != read length(${readLength})"
                    )
                }
            }
        }
    }

    // -------------------------
    // Parsing
    // -------------------------
    private List<Element> parse(String structureString, List<Integer> readLengths) {

        def perRead = structureString.split("\\|")

        if (readLengths != null && perRead.length != readLengths.size()) {
            throw new RuntimeException(
                    "Number of reads in bead structure '${structureString}' != number of template reads in flowcell."
            )
        }

        def result = []

        perRead.eachWithIndex { readStr, readIndex ->

            List<Element> thisReadElements = []
            String remaining = readStr
            int firstBase = 1

            while (!remaining.isEmpty()) {

                def matcher = BeadStructureRegex.matcher(remaining)
                if (!matcher.matches()) {
                    throw new RuntimeException(
                            "Error in bead structure '${structureString}' starting at '${remaining}'."
                    )
                }

                String lengthStr = matcher.group(1)
                String typeStr   = matcher.group(2)
                String rest      = matcher.group(3)

                int elementLength

                if (lengthStr == Asterisk) {
                    if (!rest.isEmpty()) {
                        throw new RuntimeException(
                                "Error in bead structure '${structureString}'. Asterisk can only be used for last operator for a read."
                        )
                    } else if (readLengths != null) {
                        int used = thisReadElements.collect { it.length }.sum() ?: 0
                        elementLength = readLengths[readIndex] - used
                    } else if (!IndexElementTypes.contains(ElementTypes[typeStr])) {
                        elementLength = -1
                    } else {
                        throw new RuntimeException(
                                "Bead structure '${structureString}' contains ${Asterisk} for index element, but read length is not available."
                        )
                    }
                } else {
                    elementLength = lengthStr.toInteger()
                }

                thisReadElements << new Element(
                        elementType: ElementTypes[typeStr],
                        firstBase: firstBase,
                        length: elementLength,
                        readIndex: readIndex
                )

                remaining = rest
                firstBase += elementLength
            }

            if (!thisReadElements.any { it.elementType != Skip }) {
                throw new RuntimeException(
                        "BEAD_STRUCTURE '${structureString}' has no non-skip elements for read ${readIndex + 1}"
                )
            }

            result.addAll(thisReadElements)
        }

        return result
    }

    // -------------------------
    // Methods
    // -------------------------
    int getNumBases() {
        elements.collect { it.length }.sum() ?: 0
    }

    String toString() {
        def grouped = elements.groupBy { it.readIndex }
        (0..<grouped.size()).collect { i ->
            grouped[i].collect { it.stringRep }.join("")
        }.join("|")
    }

    private List<Element> getElementsForType(ElementType elementType) {
        def elems = groupedElements[elementType]
        if (elems == null) {
            throw new RuntimeException(
                    "Element type ${elementType} not found in ${structureString}"
            )
        }
        if (elems.collect { it.readIndex }.toSet().size() != 1) {
            throw new RuntimeException(
                    "Element ${elementType} is on more than one read in ${structureString}"
            )
        }
        return elems
    }

    String getBaseRangeForElementType(ElementType elementType) {
        getElementsForType(elementType).stream().map { it.getAsBaseRange() }.toList().join(":")
    }

    int getReadIndexForElementType(ElementType elementType) {
        getElementsForType(elementType).head().readIndex


    }

    // Preserve insertion order
    Map<ElementType, List<Element>> getGroupedElements() {
        def grouped = elements.groupBy { it.elementType }
        def ret = new LinkedHashMap<ElementType, List<Element>>()

        elements.each { e ->
            if (e.elementType.tag != null && !ret.containsKey(e.elementType)) {
                ret[e.elementType] = grouped[e.elementType]
            }
        }

        return ret
    }
}