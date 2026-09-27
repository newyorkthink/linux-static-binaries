#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/version.conf"

: "${PACKAGE_REVISION:?PACKAGE_REVISION 未设置}"

SOURCE_URL='https://www.chiark.greenend.org.uk/~sgtatham/utils/xclipglue.tar.gz'
UPSTREAM_URL='https://git.tartarus.org/simon/xclipglue.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
WORK_DIR="$BUILD_BASE/xclipglue-build"
SOURCE_DIR="$WORK_DIR/source"
GIT_DIR="$WORK_DIR/git"
ARTIFACT_NAME='xclipglue'

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

# 官网 tarball 是正式发布源码；开发 Git 仓库没有稳定 Tag。
curl -fsSL --retry 3 "$SOURCE_URL" -o "$WORK_DIR/xclipglue.tar.gz"
tar -xzf "$WORK_DIR/xclipglue.tar.gz" --no-same-owner --no-same-permissions \
    --strip-components=1 -C "$SOURCE_DIR"

[[ -s "$SOURCE_DIR/xclipglue.cpp" && -s "$SOURCE_DIR/Makefile" && -s "$SOURCE_DIR/xclipglue.1" ]] || {
    echo '上游正式源码包缺少预期文件。' >&2
    exit 1
}

# 记录本次官方 Git HEAD，并核对 Checkout 与正式源码包的程序内容。
UPSTREAM_COMMIT="$(git ls-remote "$UPSTREAM_URL" HEAD | awk 'NR == 1 {print $1}')"
[[ "$UPSTREAM_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo '无法解析上游 Git HEAD Commit。' >&2
    exit 1
}
git clone --quiet --depth=1 "$UPSTREAM_URL" "$GIT_DIR"
ACTUAL_COMMIT="$(git -C "$GIT_DIR" rev-parse HEAD)"
[[ "$ACTUAL_COMMIT" == "$UPSTREAM_COMMIT" ]] || {
    printf '上游 Commit 不匹配：动态解析 %s，实际 Checkout %s\n' "$UPSTREAM_COMMIT" "$ACTUAL_COMMIT" >&2
    exit 1
}

UPSTREAM_VERSION="$(python3 - "$SOURCE_DIR" "$GIT_DIR" <<'PY'
import pathlib
import re
import sys

source, checkout = (pathlib.Path(p) for p in sys.argv[1:])
published = (source / 'xclipglue.cpp').read_text(encoding='utf-8')
git_source = (checkout / 'xclipglue.cpp').read_text(encoding='utf-8')
version_pattern = re.compile(r'"xclipglue, version ([0-9]{8}\.[0-9a-f]{7,40})";')
matches = version_pattern.findall(published)
if len(matches) != 1:
    raise SystemExit('正式源码包中的版本号缺失或格式异常。')
version = matches[0]
if f'xclipglue version {version}' not in (source / 'xclipglue.1').read_text(encoding='utf-8'):
    raise SystemExit('正式源码包的源码和 man page 版本不一致。')
if (source / 'Makefile').read_bytes() != (checkout / 'Makefile').read_bytes():
    raise SystemExit('正式源码包的 Makefile 与官方 Git HEAD 不一致。')

published = version_pattern.sub('"xclipglue, unknown version"; /*---buildsys-replace---*/', published)
if published != git_source:
    raise SystemExit('正式源码包的程序内容与官方 Git HEAD 不一致。')
print(version)
PY
)"

make -C "$SOURCE_DIR" progs \
    CXX=g++ \
    CXXFLAGS='-O2 -static -s' \
    XCBLIB='-lxcb -lXau -lXdmcp'

install -Dm755 "$SOURCE_DIR/xclipglue" "$DIST_DIR/$ARTIFACT_NAME"
target="$DIST_DIR/$ARTIFACT_NAME"

file "$target" | grep -Fq 'ELF 64-bit'
file "$target" | grep -Fq 'x86-64'

if readelf -l "$target" | grep -Fq 'Requesting program interpreter'; then
    echo 'xclipglue 仍包含 ELF interpreter，不是完整静态二进制。' >&2
    exit 1
fi

if readelf -d "$target" 2>/dev/null | grep -Fq '(NEEDED)'; then
    echo 'xclipglue 仍包含动态 NEEDED 依赖，不是完整静态二进制。' >&2
    exit 1
fi

printf '%s-r%s\n' "$UPSTREAM_VERSION" "$PACKAGE_REVISION" > "$DIST_DIR/version.txt"
(
    cd "$DIST_DIR"
    sha256sum "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

printf 'Built %s (%s-r%s, upstream commit %s)\n' \
    "$ARTIFACT_NAME" "$UPSTREAM_VERSION" "$PACKAGE_REVISION" "$UPSTREAM_COMMIT"
