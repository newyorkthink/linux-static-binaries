#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/version.conf"

: "${PACKAGE_REVISION:?PACKAGE_REVISION 未设置}"

UPSTREAM_URL='https://github.com/rofl0r/microsocks.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='microsocks'

RELEASE_API='https://api.github.com/repos/rofl0r/microsocks/releases/latest'
mapfile -t release_fields < <(
    python3 - "$RELEASE_API" <<'PY_RELEASE'
import json
import re
import sys
import urllib.request

url = sys.argv[1]
request = urllib.request.Request(
    url,
    headers={
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'linux-static-binaries',
    },
)
with urllib.request.urlopen(request, timeout=30) as response:
    data = json.load(response)

if data.get('draft') or data.get('prerelease'):
    raise SystemExit('GitHub releases/latest 返回了非稳定 Release')

tag = data.get('tag_name') or ''
if not re.fullmatch(r'v[0-9]+(?:\.[0-9]+)+', tag):
    raise SystemExit(f'最新稳定 Release Tag 格式异常：{tag!r}')

print(tag)
print(tag[1:])
PY_RELEASE
)
[[ "${#release_fields[@]}" -eq 2 ]] || {
    echo '无法从 GitHub 官方 releases/latest 解析 MicroSocks 最新稳定版本。' >&2
    exit 1
}

MICROSOCKS_TAG="${release_fields[0]}"
MICROSOCKS_VERSION="${release_fields[1]}"

MICROSOCKS_COMMIT="$(git ls-remote --tags "$UPSTREAM_URL" "refs/tags/$MICROSOCKS_TAG^{}" | awk 'NR == 1 {print $1}')"
if [[ -z "$MICROSOCKS_COMMIT" ]]; then
    MICROSOCKS_COMMIT="$(git ls-remote --tags --refs "$UPSTREAM_URL" "refs/tags/$MICROSOCKS_TAG" | awk 'NR == 1 {print $1}')"
fi
[[ "$MICROSOCKS_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "无法解析 $MICROSOCKS_TAG 对应的上游 Commit。" >&2
    exit 1
}

PACKAGE_VERSION="${MICROSOCKS_VERSION}-r${PACKAGE_REVISION}"
WORK_DIR="$BUILD_BASE/microsocks-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

git clone --quiet --depth=1 --branch "$MICROSOCKS_TAG" \
    "$UPSTREAM_URL" \
    "$SOURCE_DIR"

ACTUAL_COMMIT="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
if [[ "$ACTUAL_COMMIT" != "$MICROSOCKS_COMMIT" ]]; then
    printf '上游 Commit 不匹配：动态解析 %s，实际 Checkout %s\n' "$MICROSOCKS_COMMIT" "$ACTUAL_COMMIT" >&2
    exit 1
fi

make -C "$SOURCE_DIR" \
    -j"$(nproc)" \
    CC=musl-gcc \
    CFLAGS='-Os -Wall -std=c99' \
    LDFLAGS='-static -s'

install -Dm755 "$SOURCE_DIR/microsocks" "$DIST_DIR/$ARTIFACT_NAME"

if ! file "$DIST_DIR/$ARTIFACT_NAME" | grep -Fq 'ELF 64-bit'; then
    echo '最终产物不是预期的 64-bit ELF。' >&2
    exit 1
fi

if readelf -l "$DIST_DIR/$ARTIFACT_NAME" | grep -Fq 'Requesting program interpreter'; then
    echo '最终产物仍包含 ELF interpreter，不是完整静态二进制。' >&2
    exit 1
fi

if readelf -d "$DIST_DIR/$ARTIFACT_NAME" 2>/dev/null | grep -Fq '(NEEDED)'; then
    echo '最终产物仍包含动态 NEEDED 依赖，不是完整静态二进制。' >&2
    exit 1
fi

printf '%s\n' "$PACKAGE_VERSION" > "$DIST_DIR/version.txt"

(
    cd "$DIST_DIR"
    sha256sum "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$MICROSOCKS_TAG" "$MICROSOCKS_COMMIT"
