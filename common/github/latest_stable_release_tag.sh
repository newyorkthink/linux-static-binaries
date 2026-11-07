#!/usr/bin/env bash
set -Eeuo pipefail

# 从官方 GitHub API 读取最新正式 Release Tag，并校验调用方提供的格式。
 # 校验 GitHub 仓库名称和稳定 Tag 的格式参数。
if (( $# != 2 )) || [[ ! "$1" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || [[ -z "$2" ]]; then
  echo '用法：latest_stable_release_tag.sh <owner/repo> <Tag 正则>' >&2
  exit 2
fi
repository="$1"
pattern="$2"
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# 加载仓库内统一的 GitHub API 访问函数。
# shellcheck source=common/github/github_api.sh
source "$root/common/github/github_api.sh"
# 请求官方最新正式 Release 元数据。
data="$(github_api_get "https://api.github.com/repos/$repository/releases/latest")"
# 校验版本 Tag 不属于草稿或预发布，且格式与当前软件一致。
tag="$(printf '%s\n' "$data" | jq -er --arg pattern "$pattern" '
  select(type=="object" and .draft==false and .prerelease==false)
  | .tag_name
  | select(type=="string" and test("^"+$pattern+"$"))
')" || { echo "错误：无法确定官方最新正式 Release：$repository" >&2; exit 1; }
# 输出经核对的正式 Release Tag。
printf '%s\n' "$tag"
