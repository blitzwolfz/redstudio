#!/bin/sh
set -eu
studio_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
red_studio_dir=$(CDPATH= cd -- "$studio_dir/.." && pwd)
red_root=$(CDPATH= cd -- "$red_studio_dir/../Red" && pwd)
export RED_STUDIO_PROJECT="${RED_STUDIO_PROJECT:-$red_root}"
export ANDY_GUI="${ANDY_GUI:-$red_root/build/andy-gui}"
exec "$red_studio_dir/dist/RedStudio" "$@"
