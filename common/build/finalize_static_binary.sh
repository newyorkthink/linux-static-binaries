#!/usr/bin/env bash
set -Eeuo pipefail

# 在静态 ELF 检查成功后生成构建版本和产物 SHA-256。
if (( $# != 2 )) || [[ -z "$1" || -z "$2" ]]; then
  echo '用法：finalize_static_binary.sh <静态 ELF 路径> <动态上游版本>' >&2
  exit 2
fi
target="$1"
version="$2"
[[ -s "$target" && "$version" != *[[:space:]]* ]] || { echo '错误：产物为空或上游版本无效。' >&2; exit 1; }
dir="$(cd -- "$(dirname -- "$target")" && pwd -P)"
name="$(basename -- "$target")"
target="$dir/$name"
# 核对 ELF 架构，禁止 interpreter 和动态 NEEDED 依赖。
file "$target" | grep -Fq 'ELF 64-bit' || { echo "错误：$name 不是 64 位 ELF。" >&2; exit 1; }
file "$target" | grep -Fq 'x86-64' || { echo "错误：$name 不是 x86-64 ELF。" >&2; exit 1; }
if readelf -l "$target" | grep -Fq 'Requesting program interpreter'; then
  echo "错误：$name 包含 ELF interpreter。" >&2
  exit 1
fi
if readelf -d "$target" 2>/dev/null | grep -Fq '(NEEDED)'; then
  echo "错误：$name 包含动态 NEEDED 依赖。" >&2
  exit 1
fi
# 只记录本次实际上游版本和二进制校验值。
printf '%s\n' "$version" > "$dir/version.txt"
(
  cd "$dir"
  sha256sum "$name" > "$name.sha256"
)
