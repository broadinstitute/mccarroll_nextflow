// -----------------------------
// Helpers (FileUtil replacements)
// -----------------------------

def hasExtension(path, String ext) {
    def name = path instanceof java.nio.file.Path ? path.getFileName().toString() : path.name
    return name.endsWith("." + ext)
}

def withoutExtension(path, String ext) {
    def name = path instanceof java.nio.file.Path ?
        path.getFileName().toString() :
        path.name

    def suffix = "." + ext

    if (!name.endsWith(suffix)) {
        throw new RuntimeException("Path ${path} does not have expected extension ${ext}")
    }

    def newName = name.substring(0, name.length() - suffix.length())

    if (path instanceof java.nio.file.Path) {
        return path.resolveSibling(newName)
    } else {
        return new File(path.parent, newName)
    }
}

def withExtension(path, String ext) {
    def name = path instanceof java.nio.file.Path ?
        path.getFileName().toString() :
        path.name

    def newName = name + "." + ext

    if (path instanceof java.nio.file.Path) {
        return path.resolveSibling(newName)
    } else {
        return new File(path.parent, newName)
    }
}

def subpath(dir, String child) {
    if (dir instanceof java.nio.file.Path) {
        return dir.resolve(child)
    } else {
        return new File(dir, child)
    }
}

