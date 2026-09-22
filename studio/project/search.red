// Bounded text search that leaves generated and hidden directories alone.
import "std/fs" as fs;
import "std/path" as path;

const IGNORED = [".git", "build", "build-tsan", "build-asan", "build-dbg", "vendor", ".codex", "node_modules"];
const TEXT_EXTENSIONS = [".red", ".md", ".json", ".txt", ".cpp", ".h", ".hpp", ".c", ".css", ".js", ".toml", ".yml", ".yaml"];

fun skip(item) {
  return IGNORED.contains(path.base(item)) or path.base(item).starts_with(".");
}

fun find(root, term, limit = 200) {
  if (term == "") { return []; }
  const needle = term.lower();
  const matches = [];
  let inspected = 0;
  for (let file in fs.walk(root, {"dirs": false, "skip": skip})) {
    if (!TEXT_EXTENSIONS.contains(path.ext(file).lower())) { continue; }
    inspected += 1;
    if (inspected > 3000) { break; }
    const contents = read_file(file);
    if (contents == nil or contents.len() > 1048576) { continue; }
    const rows = contents.split("\n");
    for (let i in range(0, rows.len())) {
      if (rows[i].lower().contains(needle)) {
        matches.push({"file": file, "line": i + 1, "text": rows[i].trim()});
        if (matches.len() >= limit) { return matches; }
      }
    }
  }
  return matches;
}
