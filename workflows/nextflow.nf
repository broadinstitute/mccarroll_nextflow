include { MapMyCells_fromSpecifiedMarkers_workflow } from '../subworkflows/local/MapMyCells_fromSpecifiedMarkers.nf'
include { tag_and_split_bam_workflow } from '../subworkflows/local/tag_and_split_bam.nf'


// Validation helper function
def validateInputs(manifest) {
    def requiredManifestElements = ['project', 'library', 'experimentDate', 'reference']
    requiredManifestElements.each { element ->
        if (!manifest.containsKey(element)) {
            error "Manifest is missing required element: ${element}"
        }
    }
}

// Main workflow
workflow NEXTFLOW {
    take:
    manifest
    main:
    // Get rid of the DataflowVariable gorp, at least until I understand it better -- AW
    manifest = manifest.val
    // Validate inputs
    validateInputs(manifest)
    // TODO: decide how to handle allowedBarcodes - should it be a separate input or part of the manifest?
    tag_and_split_bam_workflow(manifest, manifest['allowedBarcodes'])
    
    print("Input manifest: ${manifest}")
    emit:
    manifest = manifest
    splitBams = tag_and_split_bam_workflow.out.splitBams
}

