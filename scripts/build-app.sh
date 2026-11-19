#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
# Keep compiler caches within the checkout for restricted build environments.
export CLANG_MODULE_CACHE_PATH="$project_root/.build/clang-module-cache"
build_arguments=(-c release --arch arm64 --arch x86_64 --disable-sandbox)
swift build "${build_arguments[@]}"
binary_dir="$(swift build "${build_arguments[@]}" --show-bin-path)"
app_path="$project_root/dist/Align.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_dir/Align" "$app_path/Contents/MacOS/Align"
architectures="$(lipo -archs "$app_path/Contents/MacOS/Align")"
if [[ " $architectures " != *" arm64 "* || " $architectures " != *" x86_64 "* ]]; then
    echo "Expected arm64 and x86_64, found: $architectures" >&2
    exit 1
fi
cp "$project_root/Resources/Info.plist" "$app_path/Contents/Info.plist"
cp "$project_root/Resources/Align.icns" "$app_path/Contents/Resources/Align.icns"
# Ad-hoc signing is sufficient for a local build; distribution needs a Developer ID.
codesign --force --sign - --identifier local.align.app "$app_path"
codesign --verify --strict "$app_path"
echo "Built: $app_path"
