#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

xcode_root="/Applications/Xcode.app/Contents/Developer"
if [[ -x "$xcode_root/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" ]]; then
    swiftc_path="$xcode_root/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
    sdk_path="$xcode_root/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
else
    swiftc_path="$(xcrun --find swiftc)"
    sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
fi

case "$(uname -m)" in
    arm64) target="arm64-apple-macosx13.0" ;;
    x86_64) target="x86_64-apple-macosx13.0" ;;
    *) echo "Unsupported Mac architecture" >&2; exit 1 ;;
esac

build_dir="$project_dir/.build/widget-release"
mkdir -p "$build_dir/module-cache"
core_sources=("$project_dir"/Sources/AIUsageCore/*.swift)
app_sources=("$project_dir"/Sources/AIUsageWidget/*.swift)

"$swiftc_path" -O -parse-as-library -whole-module-optimization \
    -emit-object -emit-module -module-name AIUsageCore \
    -target "$target" -sdk "$sdk_path" \
    -module-cache-path "$build_dir/module-cache" \
    -emit-module-path "$build_dir/AIUsageCore.swiftmodule" \
    -o "$build_dir/AIUsageCore.o" "${core_sources[@]}"

"$swiftc_path" -O -target "$target" -sdk "$sdk_path" \
    -module-cache-path "$build_dir/module-cache" -I "$build_dir" \
    "${app_sources[@]}" "$build_dir/AIUsageCore.o" \
    -o "$build_dir/AIUsageWidget"

app_dir="$project_dir/dist/AI Usage Widget.app"
contents_dir="$app_dir/Contents"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$build_dir/AIUsageWidget" "$contents_dir/MacOS/AIUsageWidget"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
codesign --force --deep --sign - "$app_dir"

echo "Built: $app_dir"
echo "Open it with: open '$app_dir'"
