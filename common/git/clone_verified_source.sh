#!/usr/bin/env bash
set -Eeuo pipefail

# 克隆官方源码并核对实际 Checkout 与指定 Commit 一致。
if (( $# < 3 || $# > 4 )); then
  echo '用法：clone_verified_source.sh <URL> <目标目录> <预期 Commit> [Tag]' >&2
  exit 2
fi
url="$1"
dest="$2"
expected="$3"
tag="${4:-}"
[[ "$url" == https://* && -n "$dest" && "$dest" != / ]] || { echo '错误：Git 源或目标路径无效。' >&2; exit 2; }
[[ "$expected" =~ ^[0-9a-f]{40}$ ]] || { echo '错误：Commit SHA 格式无效。' >&2; exit 2; }
[[ ! -e "$dest" ]] || { echo "错误：目标目录已存在：$dest" >&2; exit 1; }
if [[ -n "$tag" ]]; then
  git clone --quiet --depth=1 --branch "$tag" "$url" "$dest"
else
  git clone --quiet --depth=1 "$url" "$dest"
fi
actual="$(git -C "$dest" rev-parse HEAD)"
[[ "$actual" == "$expected" ]] || {
  printf '上游 Commit 不匹配：动态解析 %s，实际 Checkout %s\n' "$expected" "$actual" >&2
  exit 1
}
