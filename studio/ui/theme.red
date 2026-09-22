// Shared palette, metrics and drawing helpers for the workbench chrome.
import "andy/color" as color;
import "std/path" as path;
import "andy/native_gui" as gui;

// Surfaces, from the editor canvas outwards.
const INK = color.rgb(0x1e, 0x1f, 0x23);
const PANEL = color.rgb(0x27, 0x29, 0x2e);
const RAISED = color.rgb(0x35, 0x38, 0x3f);
const HAIRLINE = color.rgb(0x1a, 0x1b, 0x1e);
const EDGE = color.rgb(0x3d, 0x40, 0x48);
const SHADOW = color.rgb(0x14, 0x15, 0x17);

// Text.
const TEXT = color.rgb(0xdc, 0xde, 0xe3);
const MUTED = color.rgb(0x8c, 0x91, 0x9a);
const FAINT = color.rgb(0x5d, 0x61, 0x6a);

// Interaction and state.
const FOCUS = color.rgb(0x3a, 0x75, 0xe8);
const SELECT = color.rgb(0x2d, 0x3e, 0x5f);
const CURRENT_LINE = color.rgb(0x26, 0x28, 0x2d);
const BRAND = color.rgb(0xe2, 0x45, 0x3c);
const GREEN = color.rgb(0x5f, 0xb8, 0x65);
const AMBER = color.rgb(0xe3, 0xb3, 0x41);
const ERROR = color.rgb(0xf2, 0x5c, 0x5c);
const FOLDER = color.rgb(0x93, 0x9a, 0xa6);

// Syntax.
const KEYWORD = color.rgb(0xcf, 0x8e, 0x6d);
const STRING = color.rgb(0x6a, 0xab, 0x73);
const NUMBER = color.rgb(0x2a, 0xac, 0xb8);
const COMMENT = color.rgb(0x7a, 0x7e, 0x85);
const FUNCTION = color.rgb(0x56, 0xa8, 0xf5);
const CONSTANT = color.rgb(0xc7, 0x7d, 0xbb);

// Monospaced grid used for code, inputs and console output.
const CODE_SIZE = 12.5;
// SF Mono advances 0.618 of the point size for every glyph.
const MONO_ADVANCE = 0.618;
const CW = CODE_SIZE * MONO_ADVANCE;

// Advance widths of the system UI font for printable ASCII, as a fraction
// of the point size. The scene protocol has no text metrics, so these
// place carets and right-aligned labels.
const WIDTHS = [0.205, 0.267, 0.403, 0.605, 0.605, 0.807, 0.669, 0.254, 0.323, 0.323,
  0.4, 0.605, 0.215, 0.429, 0.215, 0.279, 0.605, 0.444, 0.566, 0.592, 0.605, 0.585,
  0.617, 0.546, 0.6, 0.617, 0.215, 0.215, 0.605, 0.605, 0.605, 0.489, 0.874, 0.636,
  0.604, 0.686, 0.678, 0.552, 0.527, 0.707, 0.699, 0.224, 0.495, 0.6, 0.524, 0.83,
  0.699, 0.731, 0.577, 0.731, 0.599, 0.593, 0.58, 0.696, 0.631, 0.924, 0.635, 0.612,
  0.617, 0.323, 0.279, 0.323, 0.605, 0.527, 0.5, 0.503, 0.554, 0.501, 0.554, 0.512,
  0.304, 0.549, 0.54, 0.206, 0.205, 0.485, 0.205, 0.803, 0.527, 0.53, 0.549, 0.549,
  0.308, 0.465, 0.302, 0.527, 0.483, 0.715, 0.468, 0.486, 0.467, 0.322, 0.215, 0.323,
  0.605];

fun advance(ch, size) {
  const code = ch.code_at(0);
  if (ch.len() == 1 and code >= 32 and code < 127) { return WIDTHS[code - 32] * size * 1.03; }
  return 0.62 * size;
}

fun measure(text, size) {
  let total = 0;
  for (let ch in text.chars()) { total += advance(ch, size); }
  return total;
}

// Code is drawn in the window's monospaced font, one command per run.
// `from` and the result are grid columns, so runs can be chained.
fun mono(s, x, y, chars, fg, from = 0, limit = 400, size = CODE_SIZE, attrs = 0) {
  let run = chars;
  if (from + run.len() > limit) { run = run.slice(0, max(0, limit - from)); }
  const text = run.join("").replace("\t", " ");
  if (text.trim() != "") {
    s.text(x + from * size * MONO_ADVANCE, y, text, fg, size, attrs + gui.MONO);
  }
  return from + run.len();
}

// A disclosure chevron, pointing down when open.
fun chevron(s, x, y, open, ink = MUTED) {
  if (open) {
    s.line(x, y + 2, x + 4, y + 6, ink, 1.4);
    s.line(x + 4, y + 6, x + 8, y + 2, ink, 1.4);
  } else {
    s.line(x + 2, y, x + 6, y + 4, ink, 1.4);
    s.line(x + 6, y + 4, x + 2, y + 8, ink, 1.4);
  }
}

// Top-left y that vertically centres text of `size` on `mid`.
fun ty(mid, size) { return mid - 0.41 * size; }

fun clip(text, count) {
  const chars = text.chars();
  if (chars.len() <= count) { return text; }
  return chars.slice(0, count - 1).join("") + "…";
}

fun wrap(text, width) {
  let out = [];
  let line = "";
  for (let word in text.split(" ")) {
    if (line != "" and (line + " " + word).char_len() > width) {
      out.push(line);
      line = word;
    } else if (line == "") { line = word; }
    else { line += " " + word; }
  }
  if (line != "") { out.push(line); }
  return out;
}

// A small coloured file-type mark, the equivalent of an IDE file icon.
fun file_badge(s, x, y, name) {
  const ext = path.ext(name);
  let fill = FAINT;
  let mark = "";
  if (ext == ".red") { fill = BRAND; mark = "R"; }
  else if (ext == ".json") { fill = AMBER; mark = "{"; }
  else if (ext == ".md") { fill = color.rgb(0x4f, 0x8f, 0xdc); mark = "M"; }
  else if (ext == ".sh") { fill = GREEN; mark = "$"; }
  else if (ext == ".png" or ext == ".svg") { fill = CONSTANT; mark = "▪"; }
  s.rect(x, y, 14, 14, fill, fill, 3, 1);
  if (mark != "") { s.text(x + 3.6, y + 2.4, mark, INK, 9, 1); }
}

fun folder_icon(s, x, y, tint = FOLDER) {
  s.rect(x, y + 1, 7, 4, tint, tint, 1.5, 1);
  s.rect(x, y + 3, 15, 10, tint, tint, 2, 1);
}

fun language_for(name) {
  const ext = path.ext(name);
  if (ext == ".red") { return "Red"; }
  if (ext == ".md") { return "Markdown"; }
  if (ext == ".json") { return "JSON"; }
  if (ext == ".sh") { return "Shell"; }
  if (ext == "") { return "Plain text"; }
  return ext.sub(1).upper();
}

fun primary_button(s, x, y, w, h, label) {
  s.rect(x, y, w, h, FOCUS, FOCUS, 5, 1);
  s.text(x + (w - measure(label, 12.5) * 1.06) / 2, ty(y + h / 2, 12.5), label, color.WHITE, 12.5, 1);
}

fun secondary_button(s, x, y, w, h, label) {
  s.rect(x, y, w, h, EDGE, RAISED, 5, 1);
  s.text(x + (w - measure(label, 12.5)) / 2, ty(y + h / 2, 12.5), label, TEXT, 12.5);
}

// A single-line text field with a caret after the last character.
fun field(s, x, y, w, h, value, focused, placeholder = "") {
  let border = EDGE;
  if (focused) { border = FOCUS; }
  s.rect(x, y, w, h, border, INK, 5, 1);
  if (focused) { s.rect(x - 1, y - 1, w + 2, h + 2, FOCUS, color.DEFAULT, 6, 1); }
  let shown = value;
  while (shown != "" and measure(shown, 13) > w - 24) { shown = shown.chars().slice(1).join(""); }
  if (value == "" and placeholder != "") {
    s.text(x + 10, ty(y + h / 2, 13), placeholder, FAINT, 13);
  } else {
    s.text(x + 10, ty(y + h / 2, 13), shown, TEXT, 13);
  }
  if (focused) { s.fill(x + 10.5 + measure(shown, 13), y + 8, 1.5, h - 16, TEXT); }
}
