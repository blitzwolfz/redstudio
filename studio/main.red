// Red Studio: a native pixel workbench for Red projects.
import "andy/native" as native;
import "andy/native_gui" as gui;
import "andy/color" as color;
import "andy/event" as event;
import "std/path" as path;
import "project/model.red" as project_model;
import "editor/document.red" as document;
import "tasks/manager.red" as task_manager;
import "gallery/gallery.red" as gallery;
import "inspector/json.red" as json_inspector;
import "editor/highlight.red" as highlight;
import "editor/preview.red" as preview;
import "ui/theme.red" as theme;

// The window size, and the edges that follow from it. `layout` updates
// them whenever the window is resized.
let W = 1440;
let H = 900;
const TOP = 40;
let STATUS_Y = 876;
const STRIPE = 40;
const TOOL_W = 264;
const EDITOR_X = STRIPE + TOOL_W;
let BOTTOM_Y = 684;
const TAB_H = 36;
const ROW_H = 24;
const TAB_W = 176;
const PAGES = ["Explorer", "Search", "Tasks", "HTTP", "JSON", "Gallery"];
const TOOL_TITLES = {"Explorer": "Project", "Search": "Find in Files", "Tasks": "Tasks",
                     "HTTP": "HTTP Client", "JSON": "JSON Structure", "Gallery": "Components"};

const MIN_W = 960;
const MIN_H = 600;

fun layout(width, height) {
  W = max(MIN_W, width);
  H = max(MIN_H, height);
  STATUS_Y = H - 24;
  // The Output panel gives up height first when the window is short.
  BOTTOM_Y = STATUS_Y - max(120, min(192, floor(H * 0.22)));
}

fun lines_for(text) { return text.replace("\r", "").split("\n"); }

fun seconds(value) {
  if (value == nil) { return ""; }
  return str(round(value * 100) / 100) + "s";
}

class RedStudio {
  init(root, headless = false) {
    this.project = project_model.Project(root);
    this.directory = this.project.root;
    this.documents = [];
    this.active = 0;
    this.page = "Explorer";
    this.output = "Ready. Ctrl+R runs the open file, Ctrl+B builds it and Ctrl+T runs the tests.";
    this.status = "Ready";
    this.manager = task_manager.Manager(2, headless);
    this.url = "http://127.0.0.1:8080/api/status";
    this.url_focus = false;
    this.http_focus = "";
    this.http_method = "GET";
    this.http_body = "{}";
    this.search_query = "";
    this.search_focus = false;
    this.prompt_mode = "";
    this.prompt_value = "";
    this.selected_path = nil;
    this.window = nil;
    this.hits = [];
    this.tree_top = 0;
    this.listed = nil;
    this.follow_cursor = true;
    this.entries = [];
    this.refresh_entries();
    this.open_file(path.join(root, "README.md"));
  }

  refresh_entries() {
    if (this.directory != this.listed) { this.tree_top = 0; this.listed = this.directory; }
    try { this.entries = this.project.entries(this.directory); }
    catch (e) { this.entries = []; this.status = e.message; }
  }

  current_document() {
    if (this.documents.len() == 0) { return nil; }
    return this.documents[this.active];
  }

  open_file(file) {
    if (!is_file(file)) { return; }
    for (let i in range(0, this.documents.len())) {
      if (this.documents[i].path == file) { this.active = i; return; }
    }
    try {
      let doc = preview.classify(file);
      if (doc == nil) {
        doc = document.Document(file);
        if (preview.looks_binary(doc.contents)) { doc = preview.Preview(file, "binary", "Binary file"); }
      }
      this.documents.push(doc);
      this.active = this.documents.len() - 1;
      this.follow_cursor = true;
      if (doc.recovered) {
        this.status = "Recovered unsaved changes for ${path.base(file)}";
      } else { this.status = "Opened ${path.base(file)}"; }
    } catch (e) { this.status = "Open failed: ${e.message}"; }
  }

  save() {
    const doc = this.current_document();
    if (doc == nil) { return false; }
    try { doc.save(); this.status = "Saved ${doc.name}"; return true; }
    catch (e) { this.status = "Save failed: ${e.message}"; return false; }
  }

  run_action(action) {
    let doc = this.current_document();
    if (doc == nil) { this.status = "Open a source file first"; return; }
    if (doc.dirty() and !this.save()) { return; }
    if ((action == "run" or action == "build" or action == "compile" or
         action == "format") and path.ext(doc.path) != ".red") {
      this.status = "Select a .red file for this toolchain action"; return;
    }
    let target = doc.path;
    if (action == "test" and is_dir(path.join(this.project.root, "tests"))) {
      target = path.join(this.project.root, "tests");
    }
    this.manager.submit(action, target, this.project.root);
    this.output = "${action} queued for ${path.base(doc.path)}";
    this.status = "${action} running in background";
  }

  submit_http() {
    let action = "http-get";
    if (this.http_method == "POST") { action = "http-post"; }
    this.manager.submit(action, this.url, this.project.root, this.http_body);
    this.output = "${this.http_method} ${this.url} queued";
    this.status = "HTTP request running in background";
  }

  poll_tasks() {
    for (let result in this.manager.collect()) {
      this.output = result["out"];
      if (result["err"] != "") { this.output += "\n\n" + result["err"]; }
      this.status = "${result["action"]} ${result["status"]} in ${seconds(result["duration"])}";
    }
  }

  // Every clickable region is recorded while drawing, so hit testing
  // always agrees with what is on screen.
  hit(x, y, w, h, id) {
    this.hits.push({"x": x, "y": y, "w": w, "h": h, "id": id});
  }

  // Wheel steps: negative is up. The editor moves three lines a step.
  scroll(x, y, amount) {
    if (x >= STRIPE and x < EDITOR_X and y >= TOP and y < BOTTOM_Y and this.page == "Explorer") {
      this.tree_top = max(0, min(this.tree_top + amount * 2, this.entries.len() - 1));
      return;
    }
    const doc = this.current_document();
    if (doc == nil or this.page != "Explorer" or x < EDITOR_X or y < TOP or y >= BOTTOM_Y) { return; }
    const last = max(0, doc.line_count() - 10);
    doc.scroll = max(0, min(doc.scroll + amount * 3, last));
    this.follow_cursor = false;
  }

  hit_at(x, y) {
    let found = nil;
    for (let one in this.hits) {
      if (x >= one["x"] and x < one["x"] + one["w"] and
          y >= one["y"] and y < one["y"] + one["h"]) { found = one["id"]; }
    }
    return found;
  }

  task_counts() {
    let counts = {"queued": 0, "running": 0, "completed": 0, "failed": 0};
    for (let task in this.manager.tasks) {
      counts[task["status"]] = counts.get(task["status"], 0) + 1;
    }
    return counts;
  }

  draw_toolbar(s) {
    s.fill(0, 0, W, TOP, theme.PANEL);
    s.line(0, TOP - 0.5, W, TOP - 0.5, theme.HAIRLINE, 1);
    s.rect(12, 9, 22, 22, theme.BRAND, theme.BRAND, 5, 1);
    s.text(18.2, theme.ty(20, 13), "R", color.WHITE, 13, 1);
    s.text(46, theme.ty(20, 13), this.project.name, theme.TEXT, 13, 1);
    let crumb = "";
    if (this.directory != this.project.root) {
      crumb = this.directory.sub(this.project.root.len() + 1).replace("/", "  ›  ");
    }
    if (crumb != "") {
      s.text(56 + theme.measure(this.project.name, 13) * 1.06, theme.ty(20, 12.5),
             "›  " + theme.clip(crumb, max(4, floor((W - 620 - this.project.name.char_len() * 8) / 7))), theme.MUTED, 12.5);
    }

    // Run widget: the target file, then the toolchain actions.
    const doc = this.current_document();
    let target = "No file";
    if (doc != nil) { target = doc.name; }
    const actions = [["Build", "build", 58], ["Compile", "compile", 74],
                     ["Format", "format", 68], ["Test", "test", 50]];
    let x = W - 12;
    for (let i in range(0, actions.len())) {
      const action = actions[actions.len() - 1 - i];
      x -= action[2];
      s.text(x + 11, theme.ty(20, 12.5), action[0], theme.TEXT, 12.5);
      this.hit(x, 6, action[2], 28, "action:" + action[1]);
      x -= 2;
    }
    s.line(x - 6, 12, x - 6, 28, theme.EDGE, 1);
    x -= 44;
    s.rect(x, 7, 32, 26, theme.RAISED, theme.RAISED, 6, 1);
    s.text(x + 11, theme.ty(20, 13), "▶", theme.GREEN, 13);
    this.hit(x, 6, 32, 28, "action:run");
    const pill = 40 + theme.measure(theme.clip(target, 24), 12.5);
    x -= pill + 8;
    s.rect(x, 7, pill, 26, theme.EDGE, color.DEFAULT, 6, 1);
    if (doc != nil) { theme.file_badge(s, x + 9, 13, doc.name); }
    s.text(x + 28, theme.ty(20, 12.5), theme.clip(target, 24), theme.TEXT, 12.5);
  }

  draw_stripe(s) {
    s.fill(0, TOP, STRIPE, STATUS_Y - TOP, theme.PANEL);
    s.line(STRIPE - 0.5, TOP, STRIPE - 0.5, STATUS_Y, theme.HAIRLINE, 1);
    for (let i in range(0, PAGES.len())) {
      const y = TOP + 8 + i * 36;
      const active = PAGES[i] == this.page;
      let ink = theme.MUTED;
      if (active) {
        s.rect(6, y, 28, 28, theme.RAISED, theme.RAISED, 6, 1);
        ink = theme.TEXT;
      }
      this.draw_page_icon(s, PAGES[i], 6, y, ink);
      this.hit(0, y - 4, STRIPE, 36, "page:" + PAGES[i]);
    }
  }

  // Tool window icons drawn from primitives, 28x28 cells.
  draw_page_icon(s, page, x, y, ink) {
    if (page == "Explorer") {
      s.rect(x + 7, y + 8, 6, 3, ink, ink, 1, 1);
      s.rect(x + 7, y + 10, 14, 10, ink, color.DEFAULT, 2, 1.4);
    } else if (page == "Search") {
      s.rect(x + 7, y + 7, 11, 11, ink, color.DEFAULT, 5.5, 1.5);
      s.line(x + 16, y + 16, x + 21, y + 21, ink, 1.8);
    } else if (page == "Tasks") {
      for (let r in range(0, 3)) {
        s.fill(x + 7, y + 8.5 + r * 5, 2.5, 2.5, ink);
        s.fill(x + 12, y + 9 + r * 5, 9, 1.5, ink);
      }
    } else if (page == "HTTP") {
      s.line(x + 7, y + 11, x + 20, y + 11, ink, 1.5);
      s.line(x + 16, y + 7.5, x + 20, y + 11, ink, 1.5);
      s.line(x + 8, y + 17, x + 21, y + 17, ink, 1.5);
      s.line(x + 8, y + 17, x + 12, y + 20.5, ink, 1.5);
    } else if (page == "JSON") {
      s.text(x + 6.5, y + 6.5, "{ }", ink, 12, 1);
    } else {
      for (let r in range(0, 2)) {
        for (let c in range(0, 2)) {
          s.rect(x + 7.5 + c * 7, y + 7.5 + r * 7, 5.5, 5.5, ink, color.DEFAULT, 1.5, 1.3);
        }
      }
    }
  }

  draw_tool_window(s) {
    s.fill(STRIPE, TOP, TOOL_W, BOTTOM_Y - TOP, theme.PANEL);
    s.line(EDITOR_X - 0.5, TOP, EDITOR_X - 0.5, BOTTOM_Y, theme.HAIRLINE, 1);
    s.text(STRIPE + 14, theme.ty(TOP + 18, 13), TOOL_TITLES[this.page], theme.TEXT, 13, 1);
    const left = STRIPE + 14;
    if (this.page == "Explorer") {
      let y = TOP + 38;
      if (this.directory == this.project.root) { s.fill(STRIPE, y, TOOL_W, ROW_H, theme.CURRENT_LINE); }
      theme.chevron(s, left, y + 8, true);
      theme.folder_icon(s, left + 14, y + 5, theme.AMBER);
      s.text(left + 36, theme.ty(y + 12, 12.5), this.project.name, theme.TEXT, 12.5, 1);
      let home = env("HOME", "");
      let where = path.dir(this.project.root);
      if (home != "" and where.starts_with(home)) { where = "~" + where.sub(home.len()); }
      s.text(left + 44 + theme.measure(this.project.name, 12.5) * 1.06, theme.ty(y + 12, 11.5),
             theme.clip(where, 22), theme.FAINT, 11.5);
      this.hit(STRIPE, y, TOOL_W, ROW_H, "root");
      y += ROW_H;
      let indent = left + 16;
      if (this.directory != this.project.root) {
        s.text(indent + 12, theme.ty(y + 12, 12.5), "..", theme.MUTED, 12.5, 1);
        s.text(indent + 34, theme.ty(y + 12, 12), "Up to " + path.base(path.dir(this.directory)), theme.FAINT, 12);
        this.hit(STRIPE, y, TOOL_W, ROW_H, "up");
        y += ROW_H;
        indent += 14;
      }
      const room = floor((BOTTOM_Y - 42 - y) / ROW_H);
      if (this.tree_top > max(0, this.entries.len() - room)) {
        this.tree_top = max(0, this.entries.len() - room);
      }
      for (let i in range(this.tree_top, this.entries.len())) {
        if (i - this.tree_top >= room) {
          s.text(indent, theme.ty(y + 12, 11.5), "${this.entries.len() - i} more, scroll to see them", theme.FAINT, 11.5);
          break;
        }
        const entry = this.entries[i];
        if (entry["path"] == this.selected_path) { s.fill(STRIPE, y, TOOL_W, ROW_H, theme.SELECT); }
        if (entry["directory"]) {
          theme.chevron(s, indent, y + 8, false);
          theme.folder_icon(s, indent + 12, y + 5);
          s.text(indent + 34, theme.ty(y + 12, 12.5), theme.clip(entry["name"], 26), theme.TEXT, 12.5);
        } else {
          theme.file_badge(s, indent + 12, y + 5, entry["name"]);
          s.text(indent + 34, theme.ty(y + 12, 12.5), theme.clip(entry["name"], 26), theme.TEXT, 12.5);
        }
        this.hit(STRIPE, y, TOOL_W, ROW_H, "entry:" + str(i));
        y += ROW_H;
      }
      // Footer actions.
      const fy = BOTTOM_Y - 36;
      s.line(STRIPE, fy - 0.5, EDITOR_X, fy - 0.5, theme.HAIRLINE, 1);
      s.text(left, theme.ty(fy + 18, 12.5), "+  New file", theme.TEXT, 12.5);
      this.hit(STRIPE, fy, 110, 36, "new");
      s.text(left + 104, theme.ty(fy + 18, 11.5), "F2 rename    Ctrl+D delete", theme.FAINT, 11.5);
    } else if (this.page == "Search") {
      let y = TOP + 50;
      for (let row in theme.wrap("Searches Red source, documentation, JSON and configuration files in the background.", 38)) {
        s.text(left, y, row, theme.MUTED, 12); y += 18;
      }
      y += 10;
      s.text(left, y, "Matches are listed in the Output panel.", theme.MUTED, 12);
    } else if (this.page == "Tasks") {
      const counts = this.task_counts();
      const rows = [["Running", "running", theme.FOCUS], ["Queued", "queued", theme.AMBER],
                    ["Completed", "completed", theme.GREEN], ["Failed", "failed", theme.ERROR]];
      let y = TOP + 42;
      for (let row in rows) {
        s.rect(left + 1, y + 8, 8, 8, row[2], row[2], 4, 1);
        s.text(left + 18, theme.ty(y + 12, 12.5), row[0], theme.TEXT, 12.5);
        s.text(EDITOR_X - 36, theme.ty(y + 12, 12.5), str(counts[row[1]]), theme.MUTED, 12.5);
        y += ROW_H + 4;
      }
    } else if (this.page == "HTTP") {
      let y = TOP + 50;
      for (let row in theme.wrap("Plain HTTP only. Red's client does not support HTTPS yet, so it suits local services.", 38)) {
        s.text(left, y, row, theme.MUTED, 12); y += 18;
      }
      y += 10;
      s.text(left, y, "Ctrl+Return sends from the body.", theme.MUTED, 12);
    } else if (this.page == "JSON") {
      const doc = this.current_document();
      let y = TOP + 42;
      if (doc != nil) {
        theme.file_badge(s, left, y + 5, doc.name);
        s.text(left + 22, theme.ty(y + 12, 12.5), theme.clip(doc.name, 28), theme.TEXT, 12.5);
        y += ROW_H + 8;
      }
      if (doc == nil or path.ext(doc.name) != ".json") {
        for (let row in theme.wrap("Open a .json file from the Project view to inspect its top-level values.", 38)) {
          s.text(left, y, row, theme.MUTED, 12); y += 18;
        }
      }
    } else {
      let y = TOP + 42;
      for (let name in ["Buttons", "Fields", "Tabs", "File marks", "Status"]) {
        s.text(left + 4, theme.ty(y + 12, 12.5), name, theme.TEXT, 12.5);
        y += ROW_H;
      }
    }
  }

  draw_tabs(s) {
    s.fill(EDITOR_X, TOP, W - EDITOR_X, TAB_H, theme.PANEL);
    s.line(EDITOR_X, TOP + TAB_H - 0.5, W, TOP + TAB_H - 0.5, theme.HAIRLINE, 1);
    for (let i in range(0, this.documents.len())) {
      const x = EDITOR_X + i * TAB_W;
      if (x + TAB_W > W) { break; }
      const doc = this.documents[i];
      const active = i == this.active and this.page == "Explorer";
      if (active) {
        s.fill(x, TOP, TAB_W, TAB_H - 1, theme.INK);
        s.fill(x, TOP + TAB_H - 3, TAB_W, 2, theme.FOCUS);
      }
      theme.file_badge(s, x + 12, TOP + 11, doc.name);
      let ink = theme.MUTED;
      if (active) { ink = theme.TEXT; }
      s.text(x + 34, theme.ty(TOP + 18, 12.5), theme.clip(doc.name, 18), ink, 12.5);
      if (doc.dirty()) { s.rect(x + TAB_W - 20, TOP + 15, 7, 7, ink, ink, 3.5, 1); }
      s.line(x + TAB_W - 0.5, TOP + 8, x + TAB_W - 0.5, TOP + TAB_H - 8, theme.HAIRLINE, 1);
      this.hit(x, TOP, TAB_W, TAB_H, "tab:" + str(i));
    }
  }

  draw_editor(s) {
    const body_y = TOP + TAB_H;
    s.fill(EDITOR_X, body_y, W - EDITOR_X, BOTTOM_Y - body_y, theme.INK);
    const doc = this.current_document();
    if (doc == nil) {
      s.text(EDITOR_X + 40, body_y + 40, "Open a file from the Project view.", theme.MUTED, 13);
      return;
    }
    if (doc.encoding == "") { this.draw_preview(s, doc, body_y); return; }
    const source = lines_for(doc.contents);
    const [cursor_line, cursor_col] = doc.position();
    const visible = floor((BOTTOM_Y - body_y - 12) / 20);
    if (this.follow_cursor) {
      if (cursor_line < doc.scroll) { doc.scroll = cursor_line; }
      if (cursor_line >= doc.scroll + visible) { doc.scroll = cursor_line - visible + 1; }
    }
    const kind = highlight.kind_for(doc.name);
    const gutter = EDITOR_X + 58;
    const code_x = gutter + 14;
    const limit = floor((W - code_x - 20) / theme.CW);
    for (let row in range(0, visible)) {
      const i = doc.scroll + row;
      if (i >= source.len()) { break; }
      const y = body_y + 8 + row * 20;
      const text_y = theme.ty(y + 10, theme.CODE_SIZE);
      let number_ink = theme.FAINT;
      if (i == cursor_line) {
        s.fill(EDITOR_X, y, W - EDITOR_X, 20, theme.CURRENT_LINE);
        number_ink = theme.MUTED;
      }
      const number = str(i + 1).pad_left(4);
      theme.mono(s, EDITOR_X + 18, text_y, number.chars(), number_ink);
      let col = 0;
      for (let run in highlight.runs(source[i], kind)) {
        col = theme.mono(s, code_x, text_y, run[0], run[1], col, limit, theme.CODE_SIZE, run[2]);
        if (col >= limit) { break; }
      }
      if (i == cursor_line) { s.fill(code_x + cursor_col * theme.CW, y + 2, 1.5, 16, theme.TEXT); }
    }
    s.line(gutter, body_y, gutter, BOTTOM_Y, theme.HAIRLINE, 1);
    // Scroll position marker.
    if (source.len() > visible) {
      const track = BOTTOM_Y - body_y - 8;
      let thumb = floor(track * visible / source.len());
      if (thumb < 24) { thumb = 24; }
      const top = body_y + 4 + floor((track - thumb) * doc.scroll / (source.len() - visible));
      s.rect(W - 9, top, 5, thumb, theme.RAISED, theme.RAISED, 2.5, 1);
    }
  }

  // Images are shown fitted to the editor; other binary files are described.
  draw_preview(s, doc, body_y) {
    const mid_x = EDITOR_X + (W - EDITOR_X) / 2;
    if (doc.kind == "image") {
      s.image(EDITOR_X + 24, body_y + 24, W - EDITOR_X - 48, BOTTOM_Y - body_y - 64, doc.path);
      const caption = doc.summary();
      s.text(mid_x - theme.measure(caption, 12) / 2, BOTTOM_Y - 30, caption, theme.MUTED, 12);
      return;
    }
    let title = "${doc.name} is not a text file";
    let detail = "It is a ${doc.summary()}, so it is not opened in the editor.";
    if (doc.kind == "large") {
      title = "${doc.name} is too large to edit";
      detail = "Files over 4 MB are not loaded into the editor. This one is ${preview.size_text(doc.bytes)}.";
    }
    const y = body_y + 150;
    s.text(mid_x - theme.measure(title, 15) * 1.06 / 2, y, title, theme.TEXT, 15, 1);
    s.text(mid_x - theme.measure(detail, 12.5) / 2, y + 30, detail, theme.MUTED, 12.5);
    if (platform() == "darwin") {
      const label = "Open in default app";
      const bw = theme.measure(label, 12.5) + 28;
      theme.secondary_button(s, mid_x - bw / 2, y + 62, bw, 32, label);
      this.hit(mid_x - bw / 2, y + 62, bw, 32, "open-external");
    }
  }

  // Heading used by the tool pages that take over the editor area.
  page_heading(s, title, detail) {
    const x = EDITOR_X + 32;
    s.text(x, TOP + TAB_H + 26, title, theme.TEXT, 17, 1);
    if (detail != "") { s.text(x, TOP + TAB_H + 54, detail, theme.MUTED, 12.5); }
  }

  draw_search(s) {
    const x = EDITOR_X + 32;
    this.page_heading(s, "Find in Files", "Search text across the project. Press Return or click Search.");
    const y = TOP + TAB_H + 86;
    const fw = min(640, W - x - 32 - 88);
    theme.field(s, x, y, fw, 32, this.search_query, this.search_focus, "Text to find");
    this.hit(x, y, fw, 32, "search-input");
    theme.primary_button(s, x + fw + 12, y, 76, 32, "Search");
    this.hit(x + fw + 12, y, 76, 32, "search-submit");
  }

  draw_http(s) {
    const x = EDITOR_X + 32;
    this.page_heading(s, "HTTP Client", "Send a request to a plain HTTP endpoint. The response opens in Output.");
    let y = TOP + TAB_H + 86;
    let method_ink = theme.GREEN;
    if (this.http_method == "POST") { method_ink = theme.AMBER; }
    s.rect(x, y, 76, 32, theme.EDGE, theme.RAISED, 5, 1);
    s.text(x + 12, theme.ty(y + 16, 12.5), this.http_method, method_ink, 12.5, 1);
    theme.chevron(s, x + 56, y + 13, true);
    this.hit(x, y, 76, 32, "http-method");
    const bw = min(720, W - x - 32);
    const uw = bw - 84 - 76;
    theme.field(s, x + 84, y, uw, 32, this.url, this.http_focus == "url", "http://");
    this.hit(x + 84, y, uw, 32, "http-url");
    theme.primary_button(s, x + bw - 64, y, 64, 32, "Send");
    this.hit(x + bw - 64, y, 64, 32, "http-send");
    y += 56;
    s.text(x, y, "Request body", theme.TEXT, 12.5, 1);
    let note = "JSON, sent with POST";
    if (this.http_method == "GET") { note = "Ignored for GET requests"; }
    s.text(x + 96, y, note, theme.FAINT, 12);
    y += 24;
    let border = theme.EDGE;
    if (this.http_focus == "body") { border = theme.FOCUS; }
    const bh = min(200, BOTTOM_Y - y - 24);
    s.rect(x, y, bw, bh, border, theme.PANEL, 5, 1);
    this.hit(x, y, bw, bh, "http-body");
    const rows = lines_for(this.http_body);
    let shown = rows.len();
    const fits = max(1, floor((bh - 16) / 20));
    if (shown > fits) { shown = fits; }
    for (let i in range(0, shown)) {
      const row = rows[rows.len() - shown + i];
      const ry = y + 12 + i * 20;
      let col = 0;
      for (let run in highlight.runs(row, "code")) {
        col = theme.mono(s, x + 14, theme.ty(ry + 10, theme.CODE_SIZE), run[0], run[1], col, floor((bw - 28) / theme.CW));
      }
      if (this.http_focus == "body" and i == shown - 1) {
        s.fill(x + 14 + row.char_len() * theme.CW, ry + 2, 1.5, 16, theme.TEXT);
      }
    }
  }

  draw_json(s) {
    const x = EDITOR_X + 32;
    const doc = this.current_document();
    if (doc == nil) {
      this.page_heading(s, "JSON Structure", "Open a .json file to inspect its values.");
      return;
    }
    try {
      const info = json_inspector.inspect(doc.contents);
      const rows = json_inspector.summary(info["value"]);
      this.page_heading(s, "JSON Structure", "");
      const y0 = TOP + TAB_H + 50;
      s.rect(x, y0 + 1, 8, 8, theme.GREEN, theme.GREEN, 4, 1);
      s.text(x + 16, y0 - 2, "${doc.name} is valid JSON: ${info["kind"]} with ${rows.len()} top-level values",
             theme.MUTED, 12.5);
      let y = y0 + 30;
      const cols = [x, x + min(240, floor((W - x) * 0.25)), x + min(340, floor((W - x) * 0.25) + 100)];
      s.text(cols[0] + 12, theme.ty(y + 13, 12), "Key", theme.MUTED, 12, 1);
      s.text(cols[1] + 12, theme.ty(y + 13, 12), "Type", theme.MUTED, 12, 1);
      s.text(cols[2] + 12, theme.ty(y + 13, 12), "Value", theme.MUTED, 12, 1);
      y += 26;
      s.line(x, y - 0.5, W - 32, y - 0.5, theme.EDGE, 1);
      const room = floor((BOTTOM_Y - 16 - y) / 26);
      for (let i in range(0, rows.len())) {
        if (i >= room) { break; }
        const row = rows[i];
        if (i % 2 == 1) { s.fill(x, y, W - 32 - x, 26, theme.CURRENT_LINE); }
        const mid = theme.ty(y + 13, 12.5);
        s.text(cols[0] + 12, mid, theme.clip(row["key"], 36), theme.CONSTANT, 12.5);
        s.text(cols[1] + 12, theme.ty(y + 13, 12), row["type"], theme.MUTED, 12);
        let ink = theme.TEXT;
        if (row["type"] == "string") { ink = theme.STRING; }
        if (row["type"] == "number" or row["type"] == "int" or row["type"] == "float") { ink = theme.NUMBER; }
        if (row["type"] == "bool" or row["type"] == "nil") { ink = theme.KEYWORD; }
        s.text(cols[2] + 12, mid, theme.clip(row["value"], max(8, floor((W - 44 - cols[2]) / 7))), ink, 12.5);
        y += 26;
      }
    } catch (e: "json") {
      this.page_heading(s, "JSON Structure", "");
      s.rect(x, TOP + TAB_H + 51, 8, 8, theme.AMBER, theme.AMBER, 4, 1);
      s.text(x + 16, TOP + TAB_H + 48, "${doc.name} is not valid JSON: ${e.message}", theme.AMBER, 12.5);
    }
  }

  draw_tasks(s) {
    const x = EDITOR_X + 32;
    if (this.manager.tasks.len() == 0) {
      this.page_heading(s, "Tasks", "Nothing has run yet. Use Run, Build or Test in the toolbar to queue work.");
      return;
    }
    this.page_heading(s, "Tasks", "Background work, newest first.");
    let y = TOP + TAB_H + 80;
    const cols = [x, x + 64, x + 184, W - 32 - 300, W - 32 - 150];
    const heads = ["ID", "Action", "Target", "Status", "Time"];
    for (let i in range(0, heads.len())) {
      s.text(cols[i] + 12, theme.ty(y + 13, 12), heads[i], theme.MUTED, 12, 1);
    }
    y += 26;
    s.line(x, y - 0.5, W - 32, y - 0.5, theme.EDGE, 1);
    const room = floor((BOTTOM_Y - 16 - y) / 28);
    const total = this.manager.tasks.len();
    for (let i in range(0, total)) {
      if (i >= room) { break; }
      const task = this.manager.tasks[total - 1 - i];
      let ink = theme.AMBER;
      if (task["status"] == "running") { ink = theme.FOCUS; }
      if (task["status"] == "completed") { ink = theme.GREEN; }
      if (task["status"] == "failed") { ink = theme.ERROR; }
      const mid = y + 14;
      s.text(cols[0] + 12, theme.ty(mid, 12.5), str(task["id"]), theme.MUTED, 12.5);
      s.text(cols[1] + 12, theme.ty(mid, 12.5), task["action"], theme.TEXT, 12.5);
      s.text(cols[2] + 12, theme.ty(mid, 12.5), theme.clip(path.base(task["file"]), max(8, floor((cols[3] - cols[2] - 24) / 7))), theme.TEXT, 12.5);
      s.rect(cols[3] + 12, mid - 4, 8, 8, ink, ink, 4, 1);
      s.text(cols[3] + 28, theme.ty(mid, 12.5), task["status"], theme.TEXT, 12.5);
      s.text(cols[4] + 12, theme.ty(mid, 12.5), seconds(task.get("duration", nil)), theme.MUTED, 12.5);
      y += 28;
      s.line(x, y - 0.5, W - 32, y - 0.5, theme.CURRENT_LINE, 1);
    }
  }

  draw_output(s) {
    s.fill(STRIPE, BOTTOM_Y, W - STRIPE, STATUS_Y - BOTTOM_Y, theme.PANEL);
    s.line(STRIPE, BOTTOM_Y + 0.5, W, BOTTOM_Y + 0.5, theme.HAIRLINE, 1);
    s.text(STRIPE + 14, theme.ty(BOTTOM_Y + 17, 13), "Output", theme.TEXT, 13, 1);
    const running = this.task_counts()["running"];
    if (running > 0) {
      s.rect(STRIPE + 72, BOTTOM_Y + 13, 8, 8, theme.FOCUS, theme.FOCUS, 4, 1);
      s.text(STRIPE + 86, theme.ty(BOTTOM_Y + 17, 12), "${running} running", theme.MUTED, 12);
    }
    const top = BOTTOM_Y + 34;
    s.fill(STRIPE, top, W - STRIPE, STATUS_Y - top, theme.INK);
    const rows = lines_for(this.output);
    const room = floor((STATUS_Y - top - 12) / 18);
    let count = rows.len();
    if (count > room) { count = room; }
    const limit = floor((W - STRIPE - 48) / 6.5);
    for (let i in range(0, count)) {
      const row = rows[rows.len() - count + i];
      let ink = theme.TEXT;
      const low = row.lower();
      if (low.contains("error") or low.contains("failed")) { ink = theme.ERROR; }
      else if (row.starts_with("HTTP 2")) { ink = theme.GREEN; }
      else if (i == 0 and rows.len() <= room) { ink = theme.MUTED; }
      s.text(STRIPE + 20, theme.ty(top + 16 + i * 18, 12.5), theme.clip(row, limit), ink, 12.5);
    }
  }

  draw_status(s) {
    s.fill(0, STATUS_Y, W, H - STATUS_Y, theme.PANEL);
    s.line(0, STATUS_Y + 0.5, W, STATUS_Y + 0.5, theme.HAIRLINE, 1);
    const mid = STATUS_Y + 12;
    const low = this.status.lower();
    let dot = nil;
    if (low.contains("failed")) { dot = theme.ERROR; }
    else if (low.contains("running")) { dot = theme.FOCUS; }
    else if (low.contains("completed") or low.starts_with("saved")) { dot = theme.GREEN; }
    let x = 14;
    if (dot != nil) { s.rect(x, mid - 3.5, 7, 7, dot, dot, 3.5, 1); x += 15; }
    s.text(x, theme.ty(mid, 12), theme.clip(this.status, floor((W - 360) / 7)), theme.MUTED, 12);
    const doc = this.current_document();
    if (doc != nil and doc.encoding == "") {
      const text = doc.summary();
      s.text(W - 14 - theme.measure(text, 12), theme.ty(mid, 12), text, theme.MUTED, 12);
    } else if (doc != nil) {
      const [line, column] = doc.position();
      const parts = ["${line + 1}:${column + 1}", "LF", doc.encoding, theme.language_for(doc.name)];
      let rx = W - 14;
      for (let i in range(0, parts.len())) {
        const part = parts[parts.len() - 1 - i];
        rx -= theme.measure(part, 12);
        s.text(rx, theme.ty(mid, 12), part, theme.MUTED, 12);
        rx -= 18;
      }
    }
  }

  draw_prompt(s) {
    const w = 440;
    const h = 132;
    const x = floor((W - w) / 2);
    const y = 180;
    s.rect(x - 2, y + 4, w + 4, h + 4, theme.SHADOW, theme.SHADOW, 12, 1);
    s.rect(x, y, w, h, theme.EDGE, theme.PANEL, 10, 1);
    let title = "New file";
    let hint = "Return creates the file. Escape cancels.";
    if (this.prompt_mode == "rename") { title = "Rename"; hint = "Return renames. Escape cancels."; }
    if (this.prompt_mode == "save as") { title = "Save as"; hint = "Return saves a copy here. Escape cancels."; }
    if (this.prompt_mode == "delete") {
      title = "Delete ${path.base(this.selected_path)}";
      hint = "Type DELETE and press Return. This cannot be undone.";
    }
    s.text(x + 20, y + 20, title, theme.TEXT, 14, 1);
    theme.field(s, x + 20, y + 52, w - 40, 32, this.prompt_value, true);
    s.text(x + 20, y + 98, hint, theme.MUTED, 12);
  }

  draw() {
    const s = gui.Scene(W, H);
    this.hits = [];
    s.clear(theme.INK);
    this.draw_toolbar(s);
    this.draw_stripe(s);
    this.draw_tool_window(s);
    if (this.page == "Gallery") {
      gallery.draw(s, EDITOR_X, TOP, W - EDITOR_X, BOTTOM_Y - TOP);
    } else {
      this.draw_tabs(s);
      if (this.page == "Search") {
        s.fill(EDITOR_X, TOP + TAB_H, W - EDITOR_X, BOTTOM_Y - TOP - TAB_H, theme.INK);
        this.draw_search(s);
      } else if (this.page == "HTTP") { this.draw_http(s); }
      else if (this.page == "JSON") { this.draw_json(s); }
      else if (this.page == "Tasks") { this.draw_tasks(s); }
      else { this.draw_editor(s); }
    }
    this.draw_output(s);
    this.draw_status(s);
    if (this.prompt_mode != "") { this.draw_prompt(s); }
    return s;
  }

  headless() {
    const output = env("RED_STUDIO_SCENE", "/tmp/red-studio.scene");
    write_file(output, this.draw().lines().join("\n") + "\n");
    print("Red Studio pixel scene rendered headlessly: ${output}");
    const backend = native.executable();
    if (backend != nil) { print("Native GUI backend found: ${backend}"); }
    else { print("Native GUI backend is unavailable; headless rendering is unaffected"); }
  }

  dispatch(one) {
    if (one.kind == event.Kind.Key) {
      if (one.matches("ctrl+s")) { this.save(); return; }
      if (one.matches("ctrl+r")) { this.run_action("run"); return; }
      if (one.matches("ctrl+shift+b")) { this.run_action("compile"); return; }
      if (one.matches("ctrl+shift+f")) { this.run_action("format"); return; }
      if (one.matches("ctrl+b")) { this.run_action("build"); return; }
      if (one.matches("ctrl+t")) { this.run_action("test"); return; }
      if (one.matches("ctrl+alt+s")) {
        const current = this.current_document();
        if (current != nil) {
          this.prompt_mode = "save as"; this.prompt_value = current.name;
          this.page = "Explorer"; this.status = "Save As: enter a new name";
        }
        return;
      }
      if (this.prompt_mode != "") {
        if (one.key == "escape") {
          this.prompt_mode = ""; this.prompt_value = ""; this.status = "Ready"; return;
        }
        if (one.key == "backspace" and this.prompt_value.len() > 0) {
          this.prompt_value = this.prompt_value.sub(0, this.prompt_value.len() - 1); return;
        }
        if (one.key == "enter") {
          try {
            if (this.prompt_mode == "new") {
              const created = this.project.create(this.directory, this.prompt_value);
              this.refresh_entries(); this.selected_path = created; this.open_file(created);
              this.status = "Created ${path.base(created)}";
            } else if (this.prompt_mode == "rename" and this.selected_path != nil) {
              const before = this.selected_path;
              const after = this.project.rename(before, this.prompt_value);
              this.selected_path = after;
              for (let doc in this.documents) {
                if (doc.path == before) { doc.path = after; doc.name = path.base(after); }
              }
              this.refresh_entries(); this.status = "Renamed to ${path.base(after)}";
            } else if (this.prompt_mode == "save as") {
              const current = this.current_document();
              if (current == nil) { throw error("No open document", nil, "io"); }
              const target = path.join(this.directory, this.prompt_value);
              current.save_as(target);
              this.refresh_entries(); this.status = "Saved as ${path.base(target)}";
            } else if (this.prompt_mode == "delete" and this.selected_path != nil) {
              if (this.prompt_value != "DELETE") {
                this.status = "Type DELETE to confirm file deletion"; return;
              }
              for (let doc in this.documents) {
                if (doc.path == this.selected_path and doc.dirty()) {
                  throw error("Save or close the dirty document before deleting it", doc.path, "io");
                }
              }
              this.project.remove(this.selected_path);
              this.refresh_entries(); this.status = "Deleted ${path.base(this.selected_path)}";
              this.selected_path = nil;
            }
          } catch (e) { this.status = "File operation failed: ${e.message}"; }
          this.prompt_mode = ""; this.prompt_value = ""; return;
        }
        if (one.is_text()) { this.prompt_value += one.text; return; }
      }
      if (one.key == "f2" and this.selected_path != nil) {
        this.prompt_mode = "rename"; this.prompt_value = path.base(this.selected_path);
        this.status = "Rename: enter a new name"; return;
      }
      if (one.matches("ctrl+d") and this.selected_path != nil) {
        this.prompt_mode = "delete"; this.prompt_value = "";
        this.status = "Confirm deletion: type DELETE and press Return"; return;
      }
      if (this.page == "Search" and this.search_focus) {
        if (one.is_text()) { this.search_query += one.text; return; }
        if (one.key == "backspace" and this.search_query.len() > 0) {
          this.search_query = this.search_query.sub(0, this.search_query.len() - 1); return;
        }
        if (one.key == "enter") {
          this.manager.submit("search", this.search_query, this.project.root);
          this.output = "Search queued for '${this.search_query}'";
          return;
        }
      }
      if (this.page == "HTTP" and this.http_focus != "") {
        let text = this.url;
        if (this.http_focus == "body") { text = this.http_body; }
        if (one.is_text()) {
          text += one.text;
          if (this.http_focus == "body") { this.http_body = text; } else { this.url = text; }
          return;
        }
        if (one.key == "backspace" and text.len() > 0) {
          text = text.sub(0, text.len() - 1);
          if (this.http_focus == "body") { this.http_body = text; } else { this.url = text; }
          return;
        }
        if (one.key == "enter") {
          if (this.http_focus == "body" and !one.ctrl) { this.http_body += "\n"; return; }
          this.submit_http(); return;
        }
      }
      let doc = this.current_document();
      if (this.page != "Explorer") { doc = nil; }
      if (doc != nil) { this.follow_cursor = true; }
      if (doc != nil) {
        if (one.key == "left") { doc.left(); return; }
        if (one.key == "right") { doc.right(); return; }
        if (one.key == "up") { doc.vertical(-1); return; }
        if (one.key == "down") { doc.vertical(1); return; }
        if (one.key == "home") { doc.line_start(); return; }
        if (one.key == "end") { doc.line_end(); return; }
      }
      if (doc != nil and one.is_text() and doc.encoding != "") { doc.insert(one.text); this.status = "Editing ${doc.name}"; return; }
      if (doc != nil and one.key == "backspace") { doc.backspace(); return; }
      if (doc != nil and one.key == "enter") { doc.insert("\n"); return; }
      if (one.key == "escape") { this.window.request_close(); }
      return;
    }
    if (one.kind == event.Kind.Mouse and one.is_wheel()) { this.scroll(one.x, one.y, one.wheel); return; }
    if (one.kind != event.Kind.Mouse or !one.is_press()) { return; }
    const id = this.hit_at(one.x, one.y);
    if (id != "search-input") { this.search_focus = false; }
    if (id != "http-url" and id != "http-body") { this.http_focus = ""; }
    if (id == nil) { return; }
    if (id.starts_with("page:")) {
      this.page = id.sub(5);
      this.status = "${TOOL_TITLES[this.page]} view";
    } else if (id.starts_with("action:")) {
      this.run_action(id.sub(7));
    } else if (id.starts_with("tab:")) {
      this.active = num(id.sub(4));
      this.page = "Explorer";
    } else if (id == "root") {
      this.directory = this.project.root;
      this.refresh_entries();
    } else if (id == "up") {
      this.directory = path.dir(this.directory);
      this.refresh_entries();
    } else if (id.starts_with("entry:")) {
      const entry = this.entries[num(id.sub(6))];
      this.selected_path = entry["path"];
      if (entry["directory"]) { this.directory = entry["path"]; this.refresh_entries(); }
      else { this.open_file(entry["path"]); }
    } else if (id == "open-external") {
      const doc = this.current_document();
      if (doc != nil) {
        shell("open '" + doc.path.replace("'", "'\\''") + "' >/dev/null 2>&1 &");
        this.status = "Opened ${doc.name} in its default app";
      }
    } else if (id == "new") {
      this.prompt_mode = "new"; this.prompt_value = "";
      this.status = "New file: enter a name";
    } else if (id == "search-input") {
      this.search_focus = true;
    } else if (id == "search-submit") {
      this.manager.submit("search", this.search_query, this.project.root);
      this.output = "Search queued for '${this.search_query}'";
    } else if (id == "http-url") {
      this.http_focus = "url";
    } else if (id == "http-body") {
      this.http_focus = "body";
    } else if (id == "http-send") {
      this.submit_http();
    } else if (id == "http-method") {
      if (this.http_method == "GET") { this.http_method = "POST"; }
      else { this.http_method = "GET"; }
    }
  }

  run() {
    this.window = native.Window({"title": "Red Studio", "cols": 120, "rows": 42});
    try {
      this.window.start();
      this.window.set_pixel_min(MIN_W, MIN_H);
      // The first frame asks for the preferred size; the window reports
      // what it could actually be, and every later frame fills that.
      this.window.present_scene(this.draw());
      while (this.window.running) {
        const fresh = this.manager.collect();
        if (fresh.len() > 0) {
          for (let result in fresh) {
            if (result.get("event", "") == "running") {
              this.status = "Task ${result["id"]} running";
              continue;
            }
            this.output = result["out"];
            if (result["err"] != "") { this.output += "\n" + result["err"]; }
            this.status = "${result["action"]} ${result["status"]} in ${seconds(result["duration"])}";
          }
          this.window.present_scene(this.draw());
        }
        // The window reports every mouse movement. Nothing here reacts to
        // hovering, so those events are dropped, and a batch of events
        // costs one frame rather than one frame each.
        let changed = false;
        for (let one in this.window.poll()) {
          if (one.kind == event.Kind.Close) { this.window.running = false; continue; }
          if (one.kind == event.Kind.Mouse and !one.is_press() and !one.is_wheel()) { continue; }
          if (one.kind == event.Kind.Resize) {
            if (one.pixels) { layout(one.width, one.height); changed = true; }
            continue;
          }
          this.dispatch(one);
          changed = true;
        }
        if (changed and this.window.running) { this.window.present_scene(this.draw()); }
        for (let doc in this.documents) { doc.flush_recovery(false); }
        sleep(0.008);
      }
    } finally {
      for (let doc in this.documents) { doc.flush_recovery(true); }
      this.window.stop();
      this.manager.shutdown();
    }
  }
}

let headless = false;
for (let argument in args()) { if (argument == "--headless") { headless = true; } }
if (env("RED_STUDIO_HEADLESS") == "1") { headless = true; }
let root = env("RED_STUDIO_PROJECT", ".");
for (let argument in args()) {
  if (argument != "--headless") { root = argument; }
}
const app = RedStudio(root, headless);
if (headless) { app.headless(); }
else { app.run(); }
