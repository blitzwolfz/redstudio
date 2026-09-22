// Native component gallery scene, drawn with the same pixel primitives as the app.
import "andy/native_gui" as gui;
import "andy/color" as color;

fun scene(width = 1280, height = 780) {
  const s = gui.Scene(width, height);
  s.clear(color.rgb(0x17, 0x1b, 0x23));
  s.text(44, 44, "Native component gallery", color.rgb(0xf0, 0xf2, 0xf6), 27);
  s.text(44, 82, "Pixel scene primitives used throughout Red Studio", color.rgb(0x98, 0xa5, 0xb8), 14);
  s.text(44, 136, "BUTTONS", color.rgb(0x98, 0xa5, 0xb8), 11);
  s.button(44, 158, 144, 42, "Primary", color.WHITE, color.rgb(0xe0, 0x5b, 0x50));
  s.button(204, 158, 144, 42, "Secondary", color.rgb(0xf0, 0xf2, 0xf6), color.rgb(0x43, 0x4d, 0x5e));
  s.text(44, 240, "INPUT", color.rgb(0x98, 0xa5, 0xb8), 11);
  s.input(44, 262, 360, 42, "Search components…", color.rgb(0xf0, 0xf2, 0xf6), color.rgb(0x2b, 0x33, 0x41), color.rgb(0x3b, 0x45, 0x55));
  s.text(44, 342, "SURFACES", color.rgb(0x98, 0xa5, 0xb8), 11);
  s.rect(44, 362, 560, 150, color.rgb(0x3b, 0x45, 0x55), color.rgb(0x20, 0x26, 0x31), 10, 1);
  s.text(66, 392, "Native scene card", color.rgb(0xf0, 0xf2, 0xf6), 18);
  s.text(66, 425, "Rounded surfaces, borders and proportional text.", color.rgb(0x98, 0xa5, 0xb8), 13);
  s.rect(44, 544, 410, 76, color.rgb(0xe0, 0x5b, 0x50), color.rgb(0x2b, 0x33, 0x41), 8, 1);
  s.text(66, 573, "Active focus state", color.rgb(0xf0, 0xf2, 0xf6), 16);
  return s;
}
