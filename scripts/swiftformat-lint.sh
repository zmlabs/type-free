#!/bin/sh
set -eu

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

project_root="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cache_dir="${DERIVED_FILE_DIR:-$project_root/.build/tool-cache}"

mkdir -p "$cache_dir"

cd "$project_root"

if ! command -v swiftformat >/dev/null 2>&1; then
    echo "error: SwiftFormat is not installed or not available on PATH."
    exit 1
fi

swiftformat \
    "$project_root/TypeFree" \
    "$project_root/TypeFreeTests" \
    "$project_root/TypeFreeUITests" \
    --lint \
    --config "$project_root/.swiftformat" \
    --cache ignore
