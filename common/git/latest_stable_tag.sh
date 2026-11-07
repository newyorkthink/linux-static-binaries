#!/usr/bin/env bash
set -Eeuo pipefail

# 根据前缀读取官方 Git 最新稳定数字 Tag。
# 校验官方 Git 地址及软件规定的 Tag 前缀参数。
if (( $# != 2 )); then
  echo '用法：latest_stable_tag.sh <官方 Git HTTPS URL> <Tag 前缀>' >&2
  exit 2
fi
url="$1"
prefix="$2"
[[ "$url" == https://* && "$prefix" != *[[:space:]]* ]] || { echo '错误：Git 来源或前缀无效。' >&2; exit 2; }
# 读取官方稳定 Tag，并按数字版本排序以选出最新版本。
tag="$(
  git ls-remote --tags --refs "$url" "refs/tags/${prefix}*" |
    awk -v prefix="$prefix" '{
      tag=$2
      sub(/^refs\/tags\//, "", tag)
      if (index(tag,prefix)!=1) next
      v=substr(tag,length(prefix)+1)
      if (v ~ /^[0-9]+([.][0-9]+)+$/) print v "\t" tag
    }' |
    sort -t $'\t' -k1,1V |
    tail -n 1 |
    cut -f2-
)"
[[ -n "$tag" ]] || { echo "错误：未找到最新稳定 Tag：$url" >&2; exit 1; }
# 输出最新稳定 Tag。
printf '%s\n' "$tag"
