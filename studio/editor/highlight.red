// Line-at-a-time syntax colouring for the editor. Each line becomes a list
// of [text, colour, attrs] runs; nothing is carried between lines, so a
// block comment or multi-line string is coloured per line.
import "std/path" as path;
import "../ui/theme.red" as theme;

const KEYWORDS = ["fun", "class", "let", "const", "if", "else", "for", "while",
                  "return", "import", "as", "try", "catch", "finally", "throw",
                  "in", "and", "or", "not", "nil", "true", "false", "this",
                  "break", "continue", "enum", "spawn", "is", "null", "export",
                  "then", "fi", "do", "done", "set", "exec", "local", "echo"];
const WORD = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789";
const DIGITS = "0123456789";
const UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789";

fun kind_for(file) {
  const ext = path.ext(file);
  if (ext == ".md") { return "markdown"; }
  if (ext == ".red" or ext == ".json" or ext == ".js" or ext == ".ts" or
      ext == ".c" or ext == ".cpp" or ext == ".h" or ext == ".mm") { return "code"; }
  if (ext == ".sh" or ext == ".yml" or ext == ".yaml" or ext == ".toml" or
      ext == ".py" or ext == ".cmake" or path.base(file) == "CMakeLists.txt") {
    return "hash";
  }
  return "plain";
}

fun all_upper(word) {
  let letters = 0;
  for (let ch in word.chars()) {
    if (!UPPER.contains(ch)) { return false; }
    if (!"_0123456789".contains(ch)) { letters += 1; }
  }
  return letters > 1;
}

fun runs(line, kind) {
  if (kind == "plain") { return [[line.chars(), theme.TEXT, 0]]; }
  if (kind == "markdown") { return markdown(line); }
  const chars = line.chars();
  const n = chars.len();
  let out = [];
  let i = 0;
  while (i < n) {
    const ch = chars[i];
    if ((kind == "code" and ch == "/" and i + 1 < n and chars[i + 1] == "/") or
        (kind == "hash" and ch == "#")) {
      out.push([chars.slice(i), theme.COMMENT, 0]);
      break;
    }
    if (ch == "\"" or ch == "'") {
      let j = i + 1;
      while (j < n and chars[j] != ch) {
        if (chars[j] == "\\") { j += 1; }
        j += 1;
      }
      if (j < n) { j += 1; }
      out.push([chars.slice(i, j), theme.STRING, 0]);
      i = j;
      continue;
    }
    if (DIGITS.contains(ch)) {
      let j = i + 1;
      while (j < n and (WORD.contains(chars[j]) or chars[j] == ".")) { j += 1; }
      out.push([chars.slice(i, j), theme.NUMBER, 0]);
      i = j;
      continue;
    }
    if (WORD.contains(ch)) {
      let j = i + 1;
      while (j < n and WORD.contains(chars[j])) { j += 1; }
      const word = chars.slice(i, j).join("");
      let fg = theme.TEXT;
      if (KEYWORDS.contains(word)) { fg = theme.KEYWORD; }
      else if (j < n and chars[j] == "(") { fg = theme.FUNCTION; }
      else if (all_upper(word)) { fg = theme.CONSTANT; }
      out.push([chars.slice(i, j), fg, 0]);
      i = j;
      continue;
    }
    out.push([[ch], theme.TEXT, 0]);
    i += 1;
  }
  return out;
}

fun markdown(line) {
  const chars = line.chars();
  const trimmed = line.trim_start();
  if (trimmed.starts_with("#")) { return [[chars, theme.KEYWORD, 1]]; }
  if (trimmed.starts_with("```")) { return [[chars, theme.COMMENT, 0]]; }
  if (trimmed.starts_with("<")) { return [[chars, theme.COMMENT, 0]]; }
  let out = [];
  let i = 0;
  let in_code = false;
  let start = 0;
  if (trimmed.starts_with("- ") or trimmed.starts_with("* ")) {
    const lead = chars.len() - trimmed.chars().len();
    out.push([chars.slice(0, lead + 1), theme.KEYWORD, 0]);
    i = lead + 1;
    start = i;
  }
  while (i < chars.len()) {
    if (chars[i] == "`") {
      if (in_code) {
        out.push([chars.slice(start, i + 1), theme.STRING, 0]);
        start = i + 1;
      } else {
        if (i > start) { out.push([chars.slice(start, i), theme.TEXT, 0]); }
        start = i;
      }
      in_code = !in_code;
    }
    i += 1;
  }
  if (start < chars.len()) {
    let fg = theme.TEXT;
    if (in_code) { fg = theme.STRING; }
    out.push([chars.slice(start), fg, 0]);
  }
  return out;
}
