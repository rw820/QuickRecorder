#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
build_root="${project_dir}/.build"
app_dir="${build_root}/app/面试助手.app"
contents_dir="${app_dir}/Contents"
signing_identity=$(
  zsh "${script_dir}/setup-local-signing.sh" | tail -1
)

swift build --package-path "${project_dir}" -c release
mkdir -p "${contents_dir}/MacOS" "${contents_dir}/Resources"
cp "${build_root}/release/InterviewAssistantApp" \
   "${contents_dir}/MacOS/InterviewAssistantApp"
cp "${project_dir}/Resources/Info.plist" "${contents_dir}/Info.plist"
cp "${project_dir}/Resources/AppIcon.icns" \
   "${contents_dir}/Resources/AppIcon.icns"
codesign --force --deep --sign "${signing_identity}" \
  --entitlements "${project_dir}/Resources/InterviewAssistant.entitlements" \
  "${app_dir}"
codesign --verify --deep --strict "${app_dir}"
echo "${app_dir}"
