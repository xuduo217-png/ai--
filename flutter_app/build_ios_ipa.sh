#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export_options="$script_dir/ios/ExportOptions.appstore.plist"

if ! command -v flutter >/dev/null 2>&1; then
  echo "错误：未找到 flutter 命令，请先配置 Flutter 环境。" >&2
  exit 1
fi

if [[ ! -f "$export_options" ]]; then
  echo "错误：未找到导出配置：$export_options" >&2
  exit 1
fi

profile_uuid="$(/usr/libexec/PlistBuddy -c 'Print :provisioningProfiles:com.gude.cwyy' "$export_options" 2>/dev/null || true)"
profile_path="$HOME/Library/MobileDevice/Provisioning Profiles/$profile_uuid.mobileprovision"

if [[ -z "$profile_uuid" || ! -f "$profile_path" ]]; then
  echo "错误：未安装导出配置指定的 provisioning profile：$profile_uuid" >&2
  exit 1
fi

if ! security cms -D -i "$profile_path" 2>/dev/null \
  | plutil -p - 2>/dev/null \
  | grep -q 'com.apple.developer.associated-domains'; then
  echo "错误：provisioning profile 不包含 Associated Domains：$profile_uuid" >&2
  exit 1
fi

printf '请输入外部版本号（例如 2.0.0）：'
IFS= read -r build_name

if [[ ! "$build_name" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "错误：外部版本号必须是 x.y.z 格式，例如 2.0.0。" >&2
  exit 1
fi

printf '请输入内部构建号（例如 7）：'
IFS= read -r build_number

if [[ ! "$build_number" =~ ^[1-9][0-9]*$ ]]; then
  echo "错误：内部构建号必须是正整数，例如 7。" >&2
  exit 1
fi

echo "开始构建 iOS 和 Android App：版本 ${build_name}，构建号 ${build_number}"

cd "$script_dir"

echo "正在构建 iOS IPA..."
flutter build ipa \
  --release \
  --build-name="$build_name" \
  --build-number="$build_number" \
  --export-options-plist="$export_options"

echo "正在构建 Android APK..."
flutter build apk \
  --release \
  --build-name="$build_name" \
  --build-number="$build_number"

echo "正在构建 Android AAB..."
flutter build appbundle \
  --release \
  --build-name="$build_name" \
  --build-number="$build_number"

echo "构建完成："
echo "  iOS IPA：$script_dir/build/ios/ipa/"
echo "  Android APK：$script_dir/build/app/outputs/flutter-apk/app-release.apk"
echo "  Android AAB：$script_dir/build/app/outputs/bundle/release/app-release.aab"
