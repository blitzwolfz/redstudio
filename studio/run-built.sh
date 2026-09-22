#!/bin/sh
set -eu
studio_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
red_studio_dir=$(CDPATH= cd -- "$studio_dir/.." && pwd)
default_project="$red_studio_dir"
red_root="$red_studio_dir/../Red"
if [ -d "$red_root" ]; then
  red_root=$(CDPATH= cd -- "$red_root" && pwd)
  default_project="$red_root"
fi
export RED_STUDIO_PROJECT="${RED_STUDIO_PROJECT:-$default_project}"
export ANDY_GUI="${ANDY_GUI:-$red_studio_dir/dist/andy-gui}"
exec "$red_studio_dir/dist/RedStudio" "$@"
