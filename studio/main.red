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

const DARK = color.rgb(0x17, 0x1b, 0x23);
const SIDEBAR = color.rgb(0x20, 0x26, 0x31);
const SURFACE = color.rgb(0x2b, 0x33, 0x41);
const BORDER = color.rgb(0x3b, 0x45, 0x55);
const ACCENT = color.rgb(0xe0, 0x5b, 0x50);
const TEXT = color.rgb(0xf0, 0xf2, 0xf6);
const MUTED = color.rgb(0x98, 0xa5, 0xb8);
const GREEN = color.rgb(0x49, 0xb5, 0x8b);
const AMBER = color.rgb(0xe2, 0xb6, 0x65);

fun pad(value, width) {
  let out = value;
  while (out.len() < width) { out += " "; }
  return out;
}

fun lines_for(text) { return text.replace("\r", "").split("\n"); }

class RedStudio {
  init(root, headless = false) {
    this.project = project_model.Project(root);
    this.directory = this.project.root;
    this.documents = [];
    this.active = 0;
    this.page = "Explorer";
    this.output = "Welcome to Red Studio. Open a file or run a Red source file.\nCtrl+S saves · Ctrl+R runs · Ctrl+B builds";
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
    this.scene_width = 1440;
    this.scene_height = 900;
    this.window = nil;
    this.entries = [];
    this.refresh_entries();
    this.open_file(path.join(root, "README.md"));
  }

  refresh_entries() {
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
      this.documents.push(document.Document(file));
      this.active = this.documents.len() - 1;
      if (this.documents[this.active].recovered) {
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
    this.output = "${action} queued · ${path.base(doc.path)}";
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
      this.status = "${result["status"].upper()} · ${result["action"]} · ${result["duration"]}s";
    }
  }

  draw_file_row(scene, entry, index) {
    const y = 264 + index * 32;
    if (entry["directory"]) {
      scene.text(286, y, "▸", ACCENT, 14);
      scene.text(308, y, entry["name"] + "/", TEXT, 13);
    } else {
      scene.text(286, y, "·", MUTED, 14);
      scene.text(308, y, entry["name"], TEXT, 13);
    }
  }

  draw_editor(scene) {
    let doc = this.current_document();
    scene.rect(252, 170, 1188, 478, BORDER, SIDEBAR, 7, 1);
    if (doc == nil) {
      scene.text(286, 220, "Open a file from the project explorer", MUTED, 17);
      return;
    }
    const source = lines_for(doc.contents);
    const cursor_position = doc.position();
    const cursor_line = cursor_position[0];
    const cursor_col = cursor_position[1];
    let visible = 22;
    if (source.len() < visible) { visible = source.len(); }
    for (let i in range(0, visible)) {
      const y = 220 + i * 19;
      scene.text(278, y, pad(str(i + 1), 3), MUTED, 12);
      let row = source[i];
      if (row.len() > 126) { row = row.sub(0, 126); }
      if (i == cursor_line) {
        scene.fill(324, y - 3, 1090, 19, color.rgb(0x27, 0x2f, 0x3c));
      }
      scene.text(332, y, row, TEXT, 13);
      if (i == cursor_line) { scene.fill(332 + cursor_col * 8, y - 2, 2, 17, ACCENT); }
    }
    scene.text(284, 627, "${doc.name} · ${doc.encoding}", MUTED, 11);
  }

  draw() {
    const s = gui.Scene(this.scene_width, this.scene_height);
    s.clear(DARK);
    // Title/menu strip.
    s.fill(0, 0, this.scene_width, 54, SIDEBAR);
    s.rect(18, 12, 29, 29, ACCENT, ACCENT, 7, 1);
    s.text(27, 17, "R", color.WHITE, 16);
    s.text(60, 19, "Red Studio", TEXT, 15);
    s.text(194, 20, "${this.project.name}  /  ${path.base(this.directory)}", MUTED, 12);
    s.text(1160, 20, "Red Workbench", MUTED, 12);
    s.line(0, 54, this.scene_width, 54, BORDER, 1);

    // Activity rail and project tree.
    s.fill(0, 55, 66, 790, color.rgb(0x1b, 0x21, 0x2b));
    const nav = ["Explorer", "Search", "Tasks", "HTTP", "JSON", "Gallery"];
    for (let i in range(0, nav.len())) {
      const y = 82 + i * 54;
      if (nav[i] == this.page) { s.fill(0, y - 12, 3, 38, ACCENT); }
      let nav_color = MUTED;
      let nav_label_color = MUTED;
      if (nav[i] == this.page) { nav_color = ACCENT; nav_label_color = TEXT; }
      s.text(16, y, nav[i].sub(0, 1), nav_color, 17);
      s.text(16, y + 18, nav[i], nav_label_color, 9);
    }
    s.fill(66, 55, 176, 790, SIDEBAR);
    s.text(88, 81, this.page.upper(), MUTED, 11);
    if (this.page == "Explorer") {
      s.text(88, 116, "PROJECT", MUTED, 10);
      s.text(88, 144, this.project.name, TEXT, 13);
      s.text(88, 192, "⌂  ${path.base(this.project.root)}", ACCENT, 11);
      for (let i in range(0, this.entries.len())) {
        if (i >= 18) { break; }
        this.draw_file_row(s, this.entries[i], i);
      }
      s.text(88, 800, "+ New file   ·   F2 rename   ·   Ctrl+D delete", MUTED, 10);
      if (this.prompt_mode != "") {
        s.rect(260, 330, 670, 144, BORDER, SIDEBAR, 9, 1);
        s.text(286, 354, "${this.prompt_mode.upper()} FILE", ACCENT, 12);
        s.input(286, 382, 620, 38, this.prompt_value, TEXT, SURFACE, BORDER);
        s.text(286, 440, "Return confirms · Escape cancels", MUTED, 11);
      }
    } else if (this.page == "Gallery") {
      s.text(88, 124, "Native controls", TEXT, 12);
      s.text(88, 152, "Buttons", MUTED, 11);
      s.text(88, 178, "Inputs", MUTED, 11);
      s.text(88, 204, "Surfaces", MUTED, 11);
    } else {
      s.text(88, 124, "${this.page} tools", TEXT, 12);
      s.text(88, 152, "Choose an action in the main panel.", MUTED, 10);
    }
    s.line(242, 55, 242, 845, BORDER, 1);

    if (this.page == "Gallery") {
      return gallery.scene(this.scene_width - 242, 790);
    }

    // Action bar and document tabs.
    s.text(274, 79, "File   Edit   View   Run   Build   Tools   Help", MUTED, 12);
    s.button(978, 67, 78, 32, "Run", color.WHITE, ACCENT);
    s.button(1064, 67, 78, 32, "Build", TEXT, SURFACE);
    s.button(1150, 67, 78, 32, "Compile", TEXT, SURFACE);
    s.button(1236, 67, 78, 32, "Format", TEXT, SURFACE);
    s.button(1322, 67, 78, 32, "Test", TEXT, SURFACE);
    s.fill(252, 116, 1188, 45, color.rgb(0x1b, 0x21, 0x2b));
    for (let i in range(0, this.documents.len())) {
      let label = this.documents[i].name;
      if (this.documents[i].dirty()) { label += "  ●"; }
      const x = 274 + i * 188;
      if (i == this.active) { s.fill(x - 8, 116, 180, 45, SIDEBAR); }
      let tab_color = MUTED;
      if (i == this.active) { tab_color = TEXT; }
      s.text(x, 132, label, tab_color, 12);
    }
    if (this.page == "Search") {
      s.text(286, 196, "PROJECT SEARCH", MUTED, 11);
      s.input(286, 220, 760, 42, this.search_query, TEXT, SURFACE, BORDER);
      s.button(1062, 220, 110, 42, "Search", color.WHITE, ACCENT);
      s.text(286, 282, "Searches Red source, docs, JSON and configuration files in a background task.", MUTED, 12);
    } else if (this.page == "HTTP") {
      s.text(286, 196, "HTTP INSPECTOR", MUTED, 11);
      s.input(286, 220, 760, 42, this.url, TEXT, SURFACE, BORDER);
      s.button(1062, 220, 110, 42, "Send", color.WHITE, ACCENT);
      s.button(1184, 220, 118, 42, this.http_method, TEXT, SURFACE);
      s.rect(286, 310, 760, 132, BORDER, SURFACE, 5, 1);
      let body_lines = lines_for(this.http_body);
      let body_count = body_lines.len();
      if (body_count > 5) { body_count = 5; }
      for (let i in range(0, body_count)) {
        s.text(302, 330 + i * 20, body_lines[i], TEXT, 12);
      }
      s.text(286, 282, "Plain HTTP · localhost friendly · HTTPS is not available in Red's current client", MUTED, 12);
      s.text(286, 458, "Click the body to edit JSON. Response headers and JSON body appear below.", TEXT, 13);
    } else if (this.page == "JSON") {
      s.text(286, 196, "JSON INSPECTOR", MUTED, 11);
      const doc = this.current_document();
      if (doc != nil) {
        try {
          const info = json_inspector.inspect(doc.contents);
          const rows = json_inspector.summary(info["value"]);
          s.text(286, 226, "Valid JSON · ${info["kind"]} · ${rows.len()} top-level values", GREEN, 13);
          let row_count = rows.len();
          if (row_count > 16) { row_count = 16; }
          for (let i in range(0, row_count)) {
            s.text(300, 256 + i * 24, "${rows[i]["key"]}    ${rows[i]["type"]}    ${rows[i]["value"]}", TEXT, 12);
          }
        } catch (e: "json") {
          s.text(286, 228, "${doc.name} is not valid JSON: ${e.message}", AMBER, 13);
        }
      } else { s.text(286, 226, "Open a .json file to inspect its values.", MUTED, 13); }
    } else if (this.page == "Tasks") {
      s.text(286, 196, "BACKGROUND TASKS", MUTED, 11);
      if (this.manager.tasks.len() == 0) {
        s.text(286, 228, "No tasks yet. Use Run, Build or Test to queue work.", MUTED, 13);
      } else {
        let task_count = this.manager.tasks.len();
        if (task_count > 18) { task_count = 18; }
        for (let i in range(0, task_count)) {
          const task = this.manager.tasks[this.manager.tasks.len() - 1 - i];
          let task_color = AMBER;
          if (task["status"] == "running") { task_color = ACCENT; }
          if (task["status"] == "completed") { task_color = GREEN; }
          if (task["status"] == "failed") { task_color = color.rgb(0xe0, 0x6a, 0x65); }
          s.text(286, 226 + i * 26,
                 "#${task["id"]}   ${task["action"].upper()}   ${path.base(task["file"])}   ${task["status"].upper()}",
                 task_color, 13);
        }
      }
    } else { this.draw_editor(s); }

    // Output pane.
    s.rect(252, 664, 1188, 166, BORDER, SIDEBAR, 7, 1);
    s.text(278, 683, "OUTPUT", ACCENT, 11);
    s.text(360, 683, "PROBLEMS", MUTED, 11);
    s.text(468, 683, "TASKS", MUTED, 11);
    const out_lines = lines_for(this.output);
    let count = out_lines.len();
    if (count > 6) { count = 6; }
    for (let i in range(0, count)) {
      let row = out_lines[out_lines.len() - count + i];
      if (row.len() > 145) { row = row.sub(0, 145); }
      let output_color = TEXT;
      if (i == 0) { output_color = GREEN; }
      s.text(278, 710 + i * 18, row, output_color, 12);
    }
    // Status bar.
    s.fill(0, 845, this.scene_width, 55, color.rgb(0x20, 0x26, 0x31));
    s.text(22, 865, this.status, GREEN, 11);
    let doc = this.current_document();
    if (doc != nil) {
      const location = doc.position();
      s.text(1060, 865, "Ln ${location[0] + 1}, Col ${location[1] + 1}     ${doc.name}     UTF-8", MUTED, 11);
    }
    return s;
  }

  headless() {
    const output = env("RED_STUDIO_SCENE", "/tmp/red-studio.scene");
    write_file(output, this.draw().lines().join("\n") + "\n");
    print("Red Studio pixel scene rendered headlessly: ${output}");
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
        this.status = "Rename: enter a new name · Return confirms · Esc cancels"; return;
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
      const doc = this.current_document();
      if (doc != nil) {
        if (one.key == "left") { doc.left(); return; }
        if (one.key == "right") { doc.right(); return; }
        if (one.key == "up") { doc.vertical(-1); return; }
        if (one.key == "down") { doc.vertical(1); return; }
        if (one.key == "home") { doc.line_start(); return; }
        if (one.key == "end") { doc.line_end(); return; }
      }
      if (doc != nil and one.is_text()) { doc.insert(one.text); this.status = "Editing ${doc.name}"; return; }
      if (doc != nil and one.key == "backspace") { doc.backspace(); return; }
      if (doc != nil and one.key == "enter") { doc.insert("\n"); return; }
      if (one.key == "escape") { this.window.request_close(); }
      return;
    }
    if (one.kind != event.Kind.Mouse or !one.is_press()) { return; }
    const x = one.x;
    const y = one.y;
    if (x < 66 and y >= 68 and y < 420) {
      const slot = floor((y - 68) / 54);
      const pages = ["Explorer", "Search", "Tasks", "HTTP", "JSON", "Gallery"];
      if (slot >= 0 and slot < pages.len()) { this.page = pages[slot]; this.status = "${this.page} view"; }
      this.search_focus = false; this.http_focus = "";
    } else if (x >= 66 and x < 242 and y >= 176 and y < 214) {
      this.directory = this.project.root;
      this.refresh_entries();
    } else if (x >= 66 and x < 242 and y >= 780 and y < 826) {
      this.prompt_mode = "new"; this.prompt_value = "";
      this.status = "New file: enter a name · Return creates · Esc cancels";
    } else if (x >= 274 and x < 326 and y >= 60 and y < 110) {
      const current = this.current_document();
      if (current != nil) {
        this.prompt_mode = "save as"; this.prompt_value = current.name;
        this.page = "Explorer"; this.status = "Save As: enter a new name";
      }
    } else if (this.page == "Search" and y >= 220 and y < 270 and x >= 286 and x < 1046) {
      this.search_focus = true;
    } else if (this.page == "Search" and y >= 220 and y < 270 and x >= 1062 and x < 1174) {
      this.search_focus = false;
      this.manager.submit("search", this.search_query, this.project.root);
      this.output = "Search queued for '${this.search_query}'";
    } else if (this.page == "HTTP" and y >= 220 and y < 270 and x >= 286 and x < 1046) {
      this.http_focus = "url";
    } else if (this.page == "HTTP" and y >= 220 and y < 270 and x >= 1062 and x < 1174) {
      this.http_focus = "";
      this.submit_http();
    } else if (this.page == "HTTP" and y >= 220 and y < 270 and x >= 1184 and x < 1302) {
      this.http_focus = "";
      if (this.http_method == "GET") { this.http_method = "POST"; }
      else { this.http_method = "GET"; }
    } else if (this.page == "HTTP" and y >= 310 and y < 442 and x >= 286 and x < 1046) {
      this.http_focus = "body";
    } else if (x >= 240 and x < 500 and y >= 244 and y < 830) {
      const index = floor((y - 264) / 32);
      if (index >= 0 and index < this.entries.len()) {
        const entry = this.entries[index];
        this.selected_path = entry["path"];
        if (entry["directory"]) { this.directory = entry["path"]; this.refresh_entries(); }
        else { this.open_file(entry["path"]); }
      }
    } else if (x >= 978 and x < 1056 and y < 110) { this.run_action("run"); }
    else if (x >= 1064 and x < 1142 and y < 110) { this.run_action("build"); }
    else if (x >= 1150 and x < 1228 and y < 110) { this.run_action("compile"); }
    else if (x >= 1236 and x < 1314 and y < 110) { this.run_action("format"); }
    else if (x >= 1322 and x < 1400 and y < 110) { this.run_action("test"); }
    else if (y >= 116 and y < 161) {
      const index = floor((x - 266) / 188);
      if (index >= 0 and index < this.documents.len()) { this.active = index; }
    }
  }

  run() {
    this.window = native.Window({"title": "Red Studio", "cols": 120, "rows": 42});
    try {
      this.window.start();
      while (this.window.running) {
        const fresh = this.manager.collect();
        if (fresh.len() > 0) {
          for (let result in fresh) {
            if (result.get("event", "") == "running") {
              this.status = "RUNNING · task #${result["id"]}";
              continue;
            }
            this.output = result["out"];
            if (result["err"] != "") { this.output += "\n" + result["err"]; }
            this.status = "${result["status"].upper()} · ${result["action"]} · ${result["duration"]}s";
          }
          this.window.present_scene(this.draw());
        }
        for (let one in this.window.poll()) {
          if (one.kind == event.Kind.Close) { this.window.running = false; }
          else { this.dispatch(one); this.window.present_scene(this.draw()); }
        }
        sleep(0.01);
      }
    } finally { this.window.stop(); this.manager.shutdown(); }
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
