// Component gallery, drawn with the same pixel primitives and theme as the app.
import "andy/native_gui" as gui;
import "../ui/theme.red" as theme;

fun draw(s, x, y, width, height) {
  s.fill(x, y, width, height, theme.INK);
  const left = x + 32;
  s.text(left, y + 26, "Components", theme.TEXT, 17, 1);
  s.text(left, y + 54, "The controls Red Studio is built from, drawn by the native scene renderer.", theme.MUTED, 12.5);

  let top = y + 96;
  s.text(left, top, "Buttons", theme.TEXT, 12.5, 1);
  theme.primary_button(s, left, top + 24, 76, 32, "Search");
  theme.secondary_button(s, left + 88, top + 24, 76, 32, "Cancel");

  top += 84;
  s.text(left, top, "Fields", theme.TEXT, 12.5, 1);
  theme.field(s, left, top + 24, 300, 32, "", false, "Text to find");
  theme.field(s, left + 316, top + 24, 300, 32, "http://127.0.0.1:8080", true);

  top += 84;
  s.text(left, top, "Tabs", theme.TEXT, 12.5, 1);
  s.fill(left, top + 24, 352, 36, theme.PANEL);
  s.fill(left, top + 24, 176, 35, theme.INK);
  s.fill(left, top + 57, 176, 2, theme.FOCUS);
  theme.file_badge(s, left + 12, top + 35, "main.red");
  s.text(left + 34, theme.ty(top + 42, 12.5), "main.red", theme.TEXT, 12.5);
  theme.file_badge(s, left + 188, top + 35, "README.md");
  s.text(left + 210, theme.ty(top + 42, 12.5), "README.md", theme.MUTED, 12.5);

  top += 88;
  s.text(left, top, "File marks", theme.TEXT, 12.5, 1);
  let mx = left;
  for (let name in ["main.red", "package.json", "README.md", "build.sh", "logo.png", "LICENSE"]) {
    theme.file_badge(s, mx, top + 28, name);
    s.text(mx + 22, theme.ty(top + 35, 12.5), name, theme.TEXT, 12.5);
    mx += 132;
  }

  top += 64;
  s.text(left, top, "Status", theme.TEXT, 12.5, 1);
  let sx = left;
  for (let row in [["Running", theme.FOCUS], ["Queued", theme.AMBER],
                   ["Completed", theme.GREEN], ["Failed", theme.ERROR]]) {
    s.rect(sx, top + 31, 8, 8, row[1], row[1], 4, 1);
    s.text(sx + 16, theme.ty(top + 35, 12.5), row[0], theme.TEXT, 12.5);
    sx += 120;
  }
  return s;
}

// A standalone scene of the gallery, for previews outside the workbench.
fun scene(width = 1136, height = 596) {
  const s = gui.Scene(width, height);
  return draw(s, 0, 0, width, height);
}
