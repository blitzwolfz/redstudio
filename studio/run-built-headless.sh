#!/bin/sh
set -eu
studio_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export RED_STUDIO_HEADLESS=1
exec "$studio_dir/run-built.sh" "$@"
