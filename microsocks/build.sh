#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/version.conf"

: "${MICROSOCKS_VERSION:?MICROSOCKS_VERSION 未设置}"
: "${MICROSOCKS_TAG:?MICROSOCKS_TAG 未设置}"
: "${MICROSOCKS_COMMIT:?MICROSOCKS_COMMIT 未设置}"
: "${PACKAGE_REVISION:?PACKAGE_REVISION 未设置}"

PACKAGE_VERSION="${MICROSOCKS_VERSION}-r${PACKAGE_REVISION}"
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
WORK_DIR="$BUILD_BASE/microsocks-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='microsocks-x86_64-linux'

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

git clone --quiet --depth=1 --branch "$MICROSOCKS_TAG" \
    https://github.com/rofl0r/microsocks.git \
    "$SOURCE_DIR"

ACTUAL_COMMIT="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
if [[ "$ACTUAL_COMMIT" != "$MICROSOCKS_COMMIT" ]]; then
    printf '上游 Commit 不匹配：期望 %s，实际 %s\n' "$MICROSOCKS_COMMIT" "$ACTUAL_COMMIT" >&2
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

printf 'Built %s (%s)\n' "$ARTIFACT_NAME" "$PACKAGE_VERSION"
