#!/usr/bin/env bash
set -Eeuo pipefail

# 取得官方 Tag 对应的真实 Commit，或解析 HEAD。
# 校验官方 Git 地址和本次要核对的 Tag 或 HEAD。
if (( $# != 2 )); then
  echo '用法：resolve_git_commit.sh <官方 Git HTTPS URL> <Tag 或 HEAD>' >&2
  exit 2
fi
url="$1"
ref="$2"
[[ "$url" == https://* && "$ref" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo '错误：Git 引用无效。' >&2; exit 2; }
# 分别处理默认分支 HEAD 与带注解的正式 Tag。
if [[ "$ref" == HEAD ]]; then
  sha="$(git ls-remote "$url" HEAD | awk 'NR==1{print $1}')"
else
  sha="$(git ls-remote --tags "$url" "refs/tags/$ref^{}" | awk 'NR==1{print $1}')"
  if [[ -z "$sha" ]]; then
    sha="$(git ls-remote --tags --refs "$url" "refs/tags/$ref" | awk 'NR==1{print $1}')"
  fi
fi
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo "错误：无法解析 Git Commit：$ref" >&2; exit 1; }
# 输出本次核对的真实 Commit SHA。
printf '%s\n' "$sha"
