#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/version.conf"

: "${PACKAGE_REVISION:?PACKAGE_REVISION 未设置}"

UPSTREAM_URL='https://github.com/lyonel/lshw.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='lshw.tar.xz'

stable_tags="$(
    git ls-remote --tags --refs "$UPSTREAM_URL" 'refs/tags/B.*' |
        awk '$2 ~ /^refs\/tags\/B\.[0-9]+(\.[0-9]+)+$/ {sub(/^refs\/tags\//, "", $2); print $2}'
)"
[[ -n "$stable_tags" ]] || {
    echo '无法从上游解析 lshw 最新稳定 B.* Tag。' >&2
    exit 1
}

LSHW_TAG="$(printf '%s\n' "$stable_tags" | sort -V | tail -n 1)"
LSHW_VERSION="${LSHW_TAG#B.}"
[[ "$LSHW_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || {
    echo "解析出的 lshw 稳定版本格式异常：$LSHW_TAG" >&2
    exit 1
}

LSHW_COMMIT="$(git ls-remote --tags "$UPSTREAM_URL" "refs/tags/$LSHW_TAG^{}" | awk 'NR == 1 {print $1}')"
if [[ -z "$LSHW_COMMIT" ]]; then
    LSHW_COMMIT="$(git ls-remote --tags --refs "$UPSTREAM_URL" "refs/tags/$LSHW_TAG" | awk 'NR == 1 {print $1}')"
fi
[[ "$LSHW_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "无法解析 $LSHW_TAG 对应的上游 Commit。" >&2
    exit 1
}

PACKAGE_VERSION="${LSHW_VERSION}-r${PACKAGE_REVISION}"
WORK_DIR="$BUILD_BASE/lshw-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"
STAGE_DIR="$WORK_DIR/stage"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR" "$STAGE_DIR"

git clone --quiet --depth=1 --branch "$LSHW_TAG" \
    "$UPSTREAM_URL" \
    "$SOURCE_DIR"

ACTUAL_COMMIT="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
if [[ "$ACTUAL_COMMIT" != "$LSHW_COMMIT" ]]; then
    printf '上游 Commit 不匹配：动态解析 %s，实际 Checkout %s\n' "$LSHW_COMMIT" "$ACTUAL_COMMIT" >&2
    exit 1
fi

make -C "$SOURCE_DIR/src" \
    -j"$(nproc)" \
    VERSION="$LSHW_TAG" \
    NO_VERSION_CHECK=1 \
    core

make -C "$SOURCE_DIR/src" \
    VERSION="$LSHW_TAG" \
    NO_VERSION_CHECK=1 \
    static

install -Dm755 "$SOURCE_DIR/src/lshw-static" "$STAGE_DIR/usr/sbin/lshw"
install -Dm644 "$SOURCE_DIR/src/lshw.1" "$STAGE_DIR/usr/share/man/man1/lshw.1"

for data_file in pci.ids usb.ids oui.txt manuf.txt pnp.ids pnpid.txt; do
    install -Dm644 \
        "$SOURCE_DIR/src/$data_file" \
        "$STAGE_DIR/usr/share/lshw/$data_file"
done

make -C "$SOURCE_DIR/src/po" \
    DESTDIR="$STAGE_DIR" \
    DATADIR=/usr/share \
    PACKAGENAME=lshw \
    install

target="$STAGE_DIR/usr/sbin/lshw"

file "$target" | grep -Fq 'ELF 64-bit'
file "$target" | grep -Fq 'x86-64'

if readelf -l "$target" | grep -Fq 'Requesting program interpreter'; then
    echo 'lshw 仍包含 ELF interpreter，不是完整静态二进制。' >&2
    exit 1
fi

if readelf -d "$target" 2>/dev/null | grep -Fq '(NEEDED)'; then
    echo 'lshw 仍包含动态 NEEDED 依赖，不是完整静态二进制。' >&2
    exit 1
fi

expected_paths='
usr/sbin/lshw
usr/share/locale/ca/LC_MESSAGES/lshw.mo
usr/share/locale/es/LC_MESSAGES/lshw.mo
usr/share/locale/fr/LC_MESSAGES/lshw.mo
usr/share/lshw/manuf.txt
usr/share/lshw/oui.txt
usr/share/lshw/pci.ids
usr/share/lshw/pnp.ids
usr/share/lshw/pnpid.txt
usr/share/lshw/usb.ids
usr/share/man/man1/lshw.1
'

actual_paths="$(
    cd "$STAGE_DIR"
    find usr \( -type f -o -type l \) -print | sort
)"

if [[ "$(printf '%s\n' "$expected_paths" | sed '/^$/d' | sort)" != "$actual_paths" ]]; then
    echo 'lshw 标准 CLI 运行时安装集与已核查布局不一致，禁止发布不完整归档。' >&2
    printf '已核查布局：\n%s\n' "$(printf '%s\n' "$expected_paths" | sed '/^$/d' | sort)" >&2
    printf '本次实际安装树：\n%s\n' "$actual_paths" >&2
    exit 1
fi

tar -C "$STAGE_DIR" -cJf "$DIST_DIR/$ARTIFACT_NAME" usr

printf '%s\n' "$PACKAGE_VERSION" > "$DIST_DIR/version.txt"

(
    cd "$DIST_DIR"
    sha256sum "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$LSHW_TAG" "$LSHW_COMMIT"
