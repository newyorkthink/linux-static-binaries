#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/version.conf"

: "${PACKAGE_REVISION:?PACKAGE_REVISION 未设置}"

STRACE_URL='https://github.com/strace/strace.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='strace'

stable_tags="$(
    git ls-remote --tags --refs "$STRACE_URL" |
        awk '
            {
                tag=$2
                sub(/^refs\/tags\//, "", tag)
                version=tag
                sub(/^v/, "", version)
                if (tag ~ /^v[0-9]+([.][0-9]+)+$/)
                    print version "\t" tag
            }
        ' |
        sort -t $'\t' -k1,1V |
        tail -n 1 |
        cut -f2-
)"
[[ -n "$stable_tags" ]] || {
    echo '无法从 strace 官方 Git 仓库解析稳定 Tag。' >&2
    exit 1
}

STRACE_TAG="$stable_tags"
STRACE_VERSION="${STRACE_TAG#v}"
[[ "$STRACE_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || {
    echo "解析出的 strace 稳定版本格式异常：$STRACE_VERSION" >&2
    exit 1
}

STRACE_COMMIT="$(git ls-remote --tags "$STRACE_URL" "refs/tags/$STRACE_TAG^{}" | awk 'NR == 1 {print $1}')"
if [[ -z "$STRACE_COMMIT" ]]; then
    STRACE_COMMIT="$(git ls-remote --tags --refs "$STRACE_URL" "refs/tags/$STRACE_TAG" | awk 'NR == 1 {print $1}')"
fi
[[ "$STRACE_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "无法解析 strace $STRACE_TAG 对应的官方 Git Commit。" >&2
    exit 1
}

PACKAGE_VERSION="${STRACE_VERSION}-r${PACKAGE_REVISION}"
WORK_DIR="$BUILD_BASE/strace-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
LINUX_UAPI_DIR="$WORK_DIR/linux-uapi"
LINUX_UAPI_ARCH_DIR="/usr/include/$MULTIARCH/asm"

for required_dir in /usr/include/linux /usr/include/asm-generic "$LINUX_UAPI_ARCH_DIR"; do
    [[ -d "$required_dir" ]] || {
        echo "缺少 Linux UAPI 头目录：$required_dir" >&2
        exit 1
    }
done

mkdir -p "$LINUX_UAPI_DIR"
cp -aL /usr/include/linux "$LINUX_UAPI_DIR/"
cp -aL /usr/include/asm-generic "$LINUX_UAPI_DIR/"
cp -aL "$LINUX_UAPI_ARCH_DIR" "$LINUX_UAPI_DIR/asm"

git clone --quiet --depth=1 --branch "$STRACE_TAG" "$STRACE_URL" "$SOURCE_DIR"
ACTUAL_COMMIT="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
[[ "$ACTUAL_COMMIT" == "$STRACE_COMMIT" ]] || {
    printf 'strace 上游 Commit 不匹配：动态解析 %s，实际 Checkout %s\n' \
        "$STRACE_COMMIT" "$ACTUAL_COMMIT" >&2
    exit 1
}

MUSL_CFLAGS="-O2 -static -isystem $LINUX_UAPI_DIR"
(
    cd "$SOURCE_DIR"
    ./bootstrap
    CC=musl-gcc CFLAGS="$MUSL_CFLAGS" LDFLAGS='-static' ./configure \
        --enable-mpers=no \
        --enable-stacktrace=no
    make -j"$(nproc)"
)

install -Dm755 "$SOURCE_DIR/src/strace" "$DIST_DIR/$ARTIFACT_NAME"
target="$DIST_DIR/$ARTIFACT_NAME"

file "$target" | grep -Fq 'ELF 64-bit'
file "$target" | grep -Fq 'x86-64'

if readelf -l "$target" | grep -Fq 'Requesting program interpreter'; then
    echo 'strace 仍包含 ELF interpreter，不是完整静态二进制。' >&2
    exit 1
fi

if readelf -d "$target" 2>/dev/null | grep -Fq '(NEEDED)'; then
    echo 'strace 仍包含动态 NEEDED 依赖，不是完整静态二进制。' >&2
    exit 1
fi

printf '%s\n' "$PACKAGE_VERSION" > "$DIST_DIR/version.txt"
(
    cd "$DIST_DIR"
    sha256sum "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$STRACE_TAG" "$STRACE_COMMIT"
