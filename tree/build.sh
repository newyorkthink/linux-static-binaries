#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/version.conf"

: "${PACKAGE_REVISION:?PACKAGE_REVISION 未设置}"

PRIMARY_INDEX='https://oldmanprogrammer.net/tar/tree/'
UPSTREAM_URL='https://github.com/Old-Man-Programmer/tree.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='tree'

TREE_VERSION="$(python3 - "$PRIMARY_INDEX" <<'PY'
import re
import sys
import urllib.request

url = sys.argv[1]
request = urllib.request.Request(url, headers={'User-Agent': 'linux-static-binaries'})
with urllib.request.urlopen(request, timeout=30) as response:
    page = response.read().decode('utf-8', errors='replace')

versions = set(re.findall(r'tree-([0-9]+(?:\\.[0-9]+)+)\\.tgz', page))
if not versions:
    raise SystemExit('无法从 tree 官方发布目录解析稳定版本。')

def version_key(value: str) -> tuple[int, ...]:
    return tuple(int(part) for part in value.split('.'))

print(max(versions, key=version_key))
PY
)"
[[ "$TREE_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || {
    echo "解析出的 tree 稳定版本格式异常：$TREE_VERSION" >&2
    exit 1
}

TREE_TAG="$TREE_VERSION"
TREE_COMMIT="$(git ls-remote --tags "$UPSTREAM_URL" "refs/tags/$TREE_TAG^{}" | awk 'NR == 1 {print $1}')"
if [[ -z "$TREE_COMMIT" ]]; then
    TREE_COMMIT="$(git ls-remote --tags --refs "$UPSTREAM_URL" "refs/tags/$TREE_TAG" | awk 'NR == 1 {print $1}')"
fi
[[ "$TREE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "无法解析 tree $TREE_TAG 对应的官方 Git Commit。" >&2
    exit 1
}

PACKAGE_VERSION="${TREE_VERSION}-r${PACKAGE_REVISION}"
WORK_DIR="$BUILD_BASE/tree-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"
GIT_DIR="$WORK_DIR/git"
SOURCE_ARCHIVE="$WORK_DIR/tree-$TREE_VERSION.tgz"
SOURCE_URL="${PRIMARY_INDEX}tree-${TREE_VERSION}.tgz"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

curl -fsSL --retry 3 "$SOURCE_URL" -o "$SOURCE_ARCHIVE"
tar -xzf "$SOURCE_ARCHIVE" --no-same-owner --no-same-permissions \
    --strip-components=1 -C "$SOURCE_DIR"

for required_file in Makefile LICENSE INSTALL README tree.c tree.h; do
    [[ -s "$SOURCE_DIR/$required_file" ]] || {
        echo "tree 官方源码包缺少预期文件：$required_file" >&2
        exit 1
    }
done

git clone --quiet --depth=1 --branch "$TREE_TAG" "$UPSTREAM_URL" "$GIT_DIR"
ACTUAL_COMMIT="$(git -C "$GIT_DIR" rev-parse HEAD)"
[[ "$ACTUAL_COMMIT" == "$TREE_COMMIT" ]] || {
    printf 'tree 上游 Commit 不匹配：动态解析 %s，实际 Checkout %s\n' \
        "$TREE_COMMIT" "$ACTUAL_COMMIT" >&2
    exit 1
}

# 官方主站 tarball 与官方 Git Tag 的实际构建输入必须一致。
for source_file in \
    Makefile \
    color.c file.c filter.c hash.c html.c info.c json.c list.c \
    strverscmp.c tree.c tree.h unix.c util.c xml.c; do
    cmp -s "$SOURCE_DIR/$source_file" "$GIT_DIR/$source_file" || {
        echo "tree 官方 tarball 与 Git Tag 内容不一致：$source_file" >&2
        exit 1
    }
done

make -C "$SOURCE_DIR" \
    -j"$(nproc)" \
    CC=musl-gcc \
    LDFLAGS='-static -s'

install -Dm755 "$SOURCE_DIR/tree" "$DIST_DIR/$ARTIFACT_NAME"
target="$DIST_DIR/$ARTIFACT_NAME"

file "$target" | grep -Fq 'ELF 64-bit'
file "$target" | grep -Fq 'x86-64'

if readelf -l "$target" | grep -Fq 'Requesting program interpreter'; then
    echo 'tree 仍包含 ELF interpreter，不是完整静态二进制。' >&2
    exit 1
fi

if readelf -d "$target" 2>/dev/null | grep -Fq '(NEEDED)'; then
    echo 'tree 仍包含动态 NEEDED 依赖，不是完整静态二进制。' >&2
    exit 1
fi

printf '%s\n' "$PACKAGE_VERSION" > "$DIST_DIR/version.txt"
(
    cd "$DIST_DIR"
    sha256sum "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$TREE_TAG" "$TREE_COMMIT"
