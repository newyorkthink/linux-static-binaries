#!/usr/bin/env bash
set -Eeuo pipefail

# 从官方 GitHub API 读取最新正式 Release Tag，并校验调用方提供的格式。
if (( $# != 2 )) || [[ ! "$1" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || [[ -z "$2" ]]; then
  echo '用法：latest_stable_release_tag.sh <owner/repo> <Tag 正则>' >&2
  exit 2
fi
repository="$1"
pattern="$2"
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=common/github/github_api.sh
source "$root/common/github/github_api.sh"
data="$(github_api_get "https://api.github.com/repos/$repository/releases/latest")"
tag="$(printf '%s\n' "$data" | jq -er --arg pattern "$pattern" '
  select(type=="object" and .draft==false and .prerelease==false)
  | .tag_name
  | select(type=="string" and test("^"+$pattern+"$"))
')" || { echo "错误：无法确定官方最新正式 Release：$repository" >&2; exit 1; }
printf '%s\n' "$tag"
