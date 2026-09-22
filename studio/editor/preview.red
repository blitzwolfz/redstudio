// Read-only tabs for files that are not text: images are shown as images,
// and binaries or very large files get a description instead of being
// decoded into the editor.
import "std/path" as path;

const IMAGE_TYPES = {".png": "PNG", ".jpg": "JPEG", ".jpeg": "JPEG", ".gif": "GIF",
                     ".bmp": "BMP", ".tif": "TIFF", ".tiff": "TIFF", ".webp": "WebP",
                     ".heic": "HEIC", ".ico": "Icon", ".icns": "Icon"};
const BINARY_TYPES = {".mov": "QuickTime movie", ".mp4": "MPEG-4 video", ".m4v": "MPEG-4 video",
                      ".mp3": "MP3 audio", ".wav": "WAV audio", ".m4a": "MPEG-4 audio",
                      ".zip": "ZIP archive", ".gz": "gzip archive", ".tar": "tar archive",
                      ".dmg": "disk image", ".pdf": "PDF document", ".o": "object file",
                      ".a": "static library", ".so": "shared library", ".dylib": "shared library",
                      ".rbc": "Red bytecode", ".sqlite": "SQLite database", ".db": "database",
                      ".psd": "Photoshop document", ".sketch": "Sketch document",
                      ".ttf": "font", ".otf": "font", ".woff": "font", ".woff2": "font"};

// Text larger than this is not loaded into the editor.
const TEXT_LIMIT = 4 * 1024 * 1024;
// Image headers are only read for files up to this size.
const HEADER_LIMIT = 64 * 1024 * 1024;

fun size_text(bytes) {
  if (bytes == nil) { return "unknown size"; }
  if (bytes < 1024) { return "${bytes} bytes"; }
  if (bytes < 1024 * 1024) { return "${round(bytes / 1024)} KB"; }
  return "${round(bytes / 1024 / 1024 * 10) / 10} MB";
}

fun be16(data, at) { return data.code_at(at) * 256 + data.code_at(at + 1); }
fun be32(data, at) { return be16(data, at) * 65536 + be16(data, at + 2); }
fun le16(data, at) { return data.code_at(at) + data.code_at(at + 1) * 256; }
fun le32(data, at) { return le16(data, at) + le16(data, at + 2) * 65536; }

// Pixel dimensions from the file header, or nil when the format is not
// one that is cheap to read.
fun dimensions(file, kind) {
  const size = file_size(file);
  if (size == nil or size > HEADER_LIMIT) { return nil; }
  const data = read_file(file);
  if (data == nil) { return nil; }
  const n = data.len();
  try {
    if (kind == "PNG" and n >= 24) { return [be32(data, 16), be32(data, 20)]; }
    if (kind == "GIF" and n >= 10) { return [le16(data, 6), le16(data, 8)]; }
    if (kind == "BMP" and n >= 26) { return [le32(data, 18), abs(le32(data, 22))]; }
    if (kind == "JPEG") {
      let at = 2;
      while (at + 9 < n) {
        if (data.code_at(at) != 0xff) { return nil; }
        const marker = data.code_at(at + 1);
        if (marker >= 0xc0 and marker <= 0xcf and marker != 0xc4 and
            marker != 0xc8 and marker != 0xcc) {
          return [be16(data, at + 7), be16(data, at + 5)];
        }
        at += 2 + be16(data, at + 2);
      }
    }
  } catch (e) { }
  return nil;
}

class Preview {
  init(file, kind, detail) {
    this.path = file;
    this.name = path.base(file);
    this.kind = kind;
    this.detail = detail;
    this.bytes = file_size(file);
    this.size = nil;
    if (kind == "image") { this.size = dimensions(file, detail); }
    this.contents = "";
    this.encoding = "";
    this.scroll = 0;
    this.recovered = false;
  }

  // The editing interface, so every tab can be treated alike.
  dirty() { return false; }
  position() { return [0, 0]; }
  insert(value) { return this; }
  backspace() { return this; }
  left() { return this; }
  right() { return this; }
  vertical(by) { return this; }
  line_start() { return this; }
  line_end() { return this; }
  persist_recovery() { return this; }
  flush_recovery(now) { return this; }
  line_count() { return 0; }
  save() { throw error("${this.name} is read-only here", this.path, "io"); }
  save_as(target) { throw error("${this.name} is read-only here", this.path, "io"); }

  summary() {
    if (this.kind == "image") {
      let text = this.detail + " image";
      if (this.size != nil) { text = "${this.size[0]} × ${this.size[1]} " + text; }
      return text + ", " + size_text(this.bytes);
    }
    return "${this.detail}, ${size_text(this.bytes)}";
  }
}

// A Preview for `file` when it should not be opened as text, else nil.
fun classify(file) {
  const ext = path.ext(file).lower();
  if (IMAGE_TYPES.has(ext)) { return Preview(file, "image", IMAGE_TYPES[ext]); }
  if (BINARY_TYPES.has(ext)) { return Preview(file, "binary", BINARY_TYPES[ext]); }
  const bytes = file_size(file);
  if (bytes != nil and bytes > TEXT_LIMIT) { return Preview(file, "large", "Large file"); }
  return nil;
}

// True when text read from a file is really binary data.
fun looks_binary(contents) {
  let head = contents;
  if (head.len() > 8192) { head = head.sub(0, 8192); }
  return head.find(chr(0)) >= 0;
}
