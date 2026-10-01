#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

xcodebuild_path="/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild"
if [[ ! -x "$xcodebuild_path" ]]; then
    echo "Full Xcode is required to build the WidgetKit extension." >&2
    exit 1
fi

if ! "$xcodebuild_path" -version >/dev/null 2>&1; then
    echo "Xcode is not ready. Open or reinstall Xcode, and accept its license before retrying." >&2
    exit 1
fi

team_setting=()
if [[ -n "${AI_USAGE_DEVELOPMENT_TEAM:-}" ]]; then
    team_setting=("DEVELOPMENT_TEAM=$AI_USAGE_DEVELOPMENT_TEAM")
fi

derived_data="$project_dir/.build/xcode"
"$xcodebuild_path" \
    -project "$project_dir/AIUsageWidget.xcodeproj" \
    -scheme AIUsageWidget \
    -configuration Release \
    -derivedDataPath "$derived_data" \
    -allowProvisioningUpdates \
    "${team_setting[@]}" \
    build

built_app="$derived_data/Build/Products/Release/AI Usage Widget.app"
app_dir="$project_dir/dist/AI Usage Widget.app"
mkdir -p "$project_dir/dist"
if [[ -d "$app_dir" ]]; then
    /bin/rm -rf "$app_dir"
fi
/usr/bin/ditto "$built_app" "$app_dir"

echo "Built: $app_dir"
echo "Open it once, then add AI Usage from Notification Center's widget gallery."
