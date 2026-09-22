#!/bin/sh
set -eu
studio_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
red_studio_dir=$(CDPATH= cd -- "$studio_dir/.." && pwd)
red_root=$(CDPATH= cd -- "$red_studio_dir/../Red" && pwd)
export RED_STUDIO_PROJECT="${RED_STUDIO_PROJECT:-$red_root}"
export RED_EXECUTABLE="${RED_EXECUTABLE:-$red_root/build/red}"
export RED_STUDIO_HEADLESS=1
cd "$red_studio_dir"
exec "$RED_EXECUTABLE" "$studio_dir/main.red"
