#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# 只检查当前 Flutter 3.47 工具链所需组件；绝不运行安装或接受许可。
sdk=""
if [ -f android/local.properties ]; then
  while IFS= read -r line; do
    if [[ "$line" == sdk.dir=* ]]; then sdk="${line#sdk.dir=}"; break; fi
  done < android/local.properties
fi
sdk="${sdk:-${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}}"
sdk="${sdk%$'\r'}"
sdk="${sdk//\\\\/\\}"
sdk="${sdk//\\:/:}"
if command -v cygpath >/dev/null 2>&1 && [ -n "$sdk" ]; then sdk="$(cygpath -u "$sdk")"; fi
if [ -z "$sdk" ] || [ ! -d "$sdk" ]; then
  printf 'Android SDK未就绪；请用户自行配置，本脚本不安装或修改SDK。\n' >&2
  exit 2
fi
missing=0
for component in platforms/android-36/android.jar build-tools/36.0.0/aapt2.exe ndk/28.2.13676358/source.properties ndk/28.2.13676358/toolchains/llvm/prebuilt/windows-x86_64/bin/clang.exe; do
  if [ ! -f "$sdk/$component" ]; then printf 'Android缺少完整组件文件：%s；停止构建，交由用户配置。\n' "$component" >&2; missing=1; fi
done
if [ "$missing" -ne 0 ]; then exit 2; fi
printf 'Android SDK必需组件已存在；不执行安装。\n'
