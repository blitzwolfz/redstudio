// An editable UTF-8 document with an independent buffer and dirty state.
import "std/path" as path;
import "std/fs" as fs;

class Document {
  init(file, contents = nil) {
    this.path = file;
    this.name = path.base(file);
    this.contents = contents;
    if (this.contents == nil) {
      this.contents = read_file(file);
      if (this.contents == nil) { this.contents = ""; }
    }
    this.saved = this.contents;
    this.cursor = this.contents.char_len();
    this.scroll = 0;
    this.encoding = "UTF-8";
  }

  dirty() { return this.contents != this.saved; }

  insert(value) {
    if (value == "") { return this; }
    const chars = this.contents.chars();
    this.contents = chars.slice(0, this.cursor).join("") + value +
                    chars.slice(this.cursor).join("");
    this.cursor += value.char_len();
    return this;
  }

  backspace() {
    if (this.cursor > 0) {
      const chars = this.contents.chars();
      this.contents = chars.slice(0, this.cursor - 1).join("") +
                      chars.slice(this.cursor).join("");
      this.cursor -= 1;
    }
    return this;
  }

  position() {
    const before = this.contents.chars().slice(0, this.cursor).join("");
    const rows = before.split("\n");
    return [rows.len() - 1, rows[rows.len() - 1].char_len()];
  }

  left() { if (this.cursor > 0) { this.cursor -= 1; } return this; }
  right() { if (this.cursor < this.contents.char_len()) { this.cursor += 1; } return this; }

  line_start() {
    let at = this.cursor;
    const chars = this.contents.chars();
    while (at > 0 and chars[at - 1] != "\n") { at -= 1; }
    this.cursor = at;
    return this;
  }

  line_end() {
    let at = this.cursor;
    const chars = this.contents.chars();
    while (at < chars.len() and chars[at] != "\n") { at += 1; }
    this.cursor = at;
    return this;
  }

  vertical(by) {
    const [line, column] = this.position();
    const rows = this.contents.split("\n");
    const target = line + by;
    if (target < 0 or target >= rows.len()) { return this; }
    let at = 0;
    for (let i in range(0, target)) { at += rows[i].char_len() + 1; }
    const col = min(column, rows[target].char_len());
    this.cursor = at + col;
    return this;
  }

  save() {
    if (this.path == nil) { throw error("Save As needs a destination path", nil, "io"); }
    fs.write_atomic(this.path, this.contents);
    this.saved = this.contents;
    return this.path;
  }

  save_as(target) {
    if (target != this.path and exists(target)) {
      throw error("'${target}' already exists", target, "io");
    }
    fs.write_atomic(target, this.contents);
    this.path = target;
    this.name = path.base(target);
    this.saved = this.contents;
    return this.path;
  }

  line_count() { return this.contents.split("\n").len(); }
}
