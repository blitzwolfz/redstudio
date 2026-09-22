#!/bin/sh
set -eu
studio_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
red_studio_dir=$(CDPATH= cd -- "$studio_dir/.." && pwd)
red_root=$(CDPATH= cd -- "$red_studio_dir/../Red" && pwd)
red_executable="${RED_EXECUTABLE:-$red_root/build/red}"
gui_backend="${ANDY_GUI:-$red_root/build/andy-gui}"
mkdir -p "$red_studio_dir/dist"
"$red_executable" build "$studio_dir/main.red" -o "$red_studio_dir/dist/RedStudio"
cp "$gui_backend" "$red_studio_dir/dist/andy-gui"
chmod +x "$red_studio_dir/dist/RedStudio" "$red_studio_dir/dist/andy-gui"
printf 'Standalone app and native backend are in %s/dist\n' "$red_studio_dir"
