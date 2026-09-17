// -----------------------------
// Helpers (FileUtil replacements)
// -----------------------------

def hasExtension(path, ext: String) {
    def name = path instanceof java.nio.file.Path ? path.getFileName().toString() : path.toString()
    return name.endsWith("." + ext)
}

def withoutExtension(path, ext: String) {
    def name = path instanceof java.nio.file.Path
        ? path.getFileName().toString()
        : path.toString()

    def suffix = "." + ext

    if (!name.endsWith(suffix)) {
        throw new RuntimeException("Path ${path} does not have expected extension ${ext}")
    }

    def newName = name.substring(0, name.length() - suffix.length())

    if (path instanceof java.nio.file.Path) {
        return path.resolveSibling(newName)
    }
    else {
        path = path instanceof File ? path : new File(path.toString())
        if (path.getParent() == null) {
            return new File(newName)
        }
        return new File(path.getParent(), newName)
    }
}

def withExtension(path, ext: String) {
    def name = path instanceof java.nio.file.Path
        ? path.getFileName().toString()
        : path.toString()

    def newName = name + "." + ext

    if (path instanceof java.nio.file.Path) {
        return path.resolveSibling(newName)
    }
    else {
        path = path instanceof File ? path : new File(path.toString())
        if (path.getParent() == null) {
            return new File(newName)
        }
        return new File(path.getParent(), newName)
    }
}

def replaceExtension(path, oldExt: String, newExt: String) {
    return withExtension(withoutExtension(path, oldExt), newExt)
}

def subpath(dir, child: String) {
    if (dir instanceof java.nio.file.Path) {
        return dir.resolve(child)
    }
    else {
        return java.nio.file.Path.of(dir.toString()).resolve(child)
    }
}
