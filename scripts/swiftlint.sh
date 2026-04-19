#!/bin/sh
set -eu

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

project_root="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cache_dir="${DERIVED_FILE_DIR:-$project_root/.build/tool-cache}"

mkdir -p "$cache_dir/swiftlint"

cd "$project_root"

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "error: SwiftLint is not installed or not available on PATH."
    exit 1
fi

swiftlint lint \
    --config "$project_root/.swiftlint.yml" \
    --reporter xcode \
    --cache-path "$cache_dir/swiftlint" \
    --force-exclude \
    --working-directory "$project_root"
