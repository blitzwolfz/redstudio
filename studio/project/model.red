// Project filesystem model and safe file operations.
import "std/path" as path;

const IGNORED = [".git", "build", "build-tsan", "build-asan", "build-dbg", "vendor", ".codex"];

class Project {
  init(root) {
    this.root = root;
    this.name = path.base(this.root);
  }

  entries(directory = nil) {
    let parent = directory;
    if (parent == nil) { parent = this.root; }
    let result = [];
    for (let name in list_dir(parent).sort()) {
      if (IGNORED.contains(name) or name.starts_with(".")) { continue; }
      result.push({"name": name, "path": path.join(parent, name),
                   "directory": is_dir(path.join(parent, name))});
    }
    return result;
  }

  create(parent, name, directory = false) {
    if (name == "" or name.contains("/") or name == "." or name == "..") {
      throw error("Enter a single file or folder name", name, "io");
    }
    const target = path.join(parent, name);
    if (exists(target)) { throw error("'${target}' already exists", target, "io"); }
    if (directory) { mkdir(target); } else { write_file(target, ""); }
    return target;
  }

  rename(source, name) {
    if (name == "" or name.contains("/") or name == "." or name == "..") {
      throw error("Enter a single file or folder name", name, "io");
    }
    const target = path.join(path.dir(source), name);
    if (exists(target)) { throw error("'${target}' already exists", target, "io"); }
    rename(source, target);
    return target;
  }

  remove(source) {
    if (is_dir(source)) { throw error("Folder deletion requires confirmation in the UI", source, "io"); }
    remove_file(source);
    return source;
  }
}
