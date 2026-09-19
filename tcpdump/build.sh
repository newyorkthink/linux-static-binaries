#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/version.conf"

: "${PACKAGE_REVISION:?PACKAGE_REVISION 未设置}"

TCPDUMP_URL='https://github.com/the-tcpdump-group/tcpdump.git'
LIBPCAP_URL='https://github.com/the-tcpdump-group/libpcap.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='tcpdump'

latest_stable_tag() {
    local url="$1"
    local prefix="$2"

    git ls-remote --tags --refs "$url" "refs/tags/$prefix*" |
        awk -v prefix="$prefix" '
            {
                tag=$2
                sub(/^refs\/tags\//, "", tag)
                version=tag
                sub("^" prefix, "", version)
                if (version ~ /^[0-9]+([.][0-9]+)+$/)
                    print version "\t" tag
            }
        ' |
        sort -t $'\t' -k1,1V |
        tail -n 1 |
        cut -f2-
}

resolve_tag_commit() {
    local url="$1"
    local tag="$2"
    local commit

    commit="$(git ls-remote --tags "$url" "refs/tags/$tag^{}" | awk 'NR == 1 {print $1}')"
    if [[ -z "$commit" ]]; then
        commit="$(git ls-remote --tags --refs "$url" "refs/tags/$tag" | awk 'NR == 1 {print $1}')"
    fi
    printf '%s\n' "$commit"
}

TCPDUMP_TAG="$(latest_stable_tag "$TCPDUMP_URL" 'tcpdump-')"
LIBPCAP_TAG="$(latest_stable_tag "$LIBPCAP_URL" 'libpcap-')"

[[ -n "$TCPDUMP_TAG" ]] || {
    echo '无法从官方上游解析 tcpdump 最新稳定 Tag。' >&2
    exit 1
}
[[ -n "$LIBPCAP_TAG" ]] || {
    echo '无法从官方上游解析 libpcap 最新稳定 Tag。' >&2
    exit 1
}

TCPDUMP_VERSION="${TCPDUMP_TAG#tcpdump-}"
LIBPCAP_VERSION="${LIBPCAP_TAG#libpcap-}"

TCPDUMP_COMMIT="$(resolve_tag_commit "$TCPDUMP_URL" "$TCPDUMP_TAG")"
LIBPCAP_COMMIT="$(resolve_tag_commit "$LIBPCAP_URL" "$LIBPCAP_TAG")"

[[ "$TCPDUMP_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "无法解析 $TCPDUMP_TAG 对应的 tcpdump Commit。" >&2
    exit 1
}
[[ "$LIBPCAP_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "无法解析 $LIBPCAP_TAG 对应的 libpcap Commit。" >&2
    exit 1
}

PACKAGE_VERSION="${TCPDUMP_VERSION}-r${PACKAGE_REVISION}"
WORK_DIR="$BUILD_BASE/tcpdump-$PACKAGE_VERSION"
TCPDUMP_DIR="$WORK_DIR/tcpdump"
LIBPCAP_DIR="$WORK_DIR/libpcap"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

git clone --quiet --depth=1 --branch "$LIBPCAP_TAG" "$LIBPCAP_URL" "$LIBPCAP_DIR"
git clone --quiet --depth=1 --branch "$TCPDUMP_TAG" "$TCPDUMP_URL" "$TCPDUMP_DIR"

ACTUAL_LIBPCAP_COMMIT="$(git -C "$LIBPCAP_DIR" rev-parse HEAD)"
ACTUAL_TCPDUMP_COMMIT="$(git -C "$TCPDUMP_DIR" rev-parse HEAD)"

[[ "$ACTUAL_LIBPCAP_COMMIT" == "$LIBPCAP_COMMIT" ]] || {
    printf 'libpcap Commit 不匹配：动态解析 %s，实际 Checkout %s\n' "$LIBPCAP_COMMIT" "$ACTUAL_LIBPCAP_COMMIT" >&2
    exit 1
}
[[ "$ACTUAL_TCPDUMP_COMMIT" == "$TCPDUMP_COMMIT" ]] || {
    printf 'tcpdump Commit 不匹配：动态解析 %s，实际 Checkout %s\n' "$TCPDUMP_COMMIT" "$ACTUAL_TCPDUMP_COMMIT" >&2
    exit 1
}

(
    cd "$LIBPCAP_DIR"
    ./autogen.sh
    ./configure \
        --disable-shared \
        --without-libnl \
        --disable-dbus \
        --disable-rdma
    make -j"$(nproc)" libpcap.a
)

(
    cd "$TCPDUMP_DIR"
    ./autogen.sh
    LDFLAGS='-static' ./configure \
        --without-smi \
        --without-crypto \
        --without-cap-ng
    make -j"$(nproc)" tcpdump
)

install -Dm755 "$TCPDUMP_DIR/tcpdump" "$DIST_DIR/$ARTIFACT_NAME"
strip "$DIST_DIR/$ARTIFACT_NAME"

target="$DIST_DIR/$ARTIFACT_NAME"

file "$target" | grep -Fq 'ELF 64-bit'
file "$target" | grep -Fq 'x86-64'

if readelf -l "$target" | grep -Fq 'Requesting program interpreter'; then
    echo 'tcpdump 仍包含 ELF interpreter，不是完整静态二进制。' >&2
    exit 1
fi

if readelf -d "$target" 2>/dev/null | grep -Fq '(NEEDED)'; then
    echo 'tcpdump 仍包含动态 NEEDED 依赖，不是完整静态二进制。' >&2
    exit 1
fi

printf '%s\n' "$PACKAGE_VERSION" > "$DIST_DIR/version.txt"

(
    cd "$DIST_DIR"
    sha256sum "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

printf 'Built %s (%s; tcpdump %s @ %s; libpcap %s @ %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" \
    "$TCPDUMP_TAG" "$TCPDUMP_COMMIT" \
    "$LIBPCAP_TAG" "$LIBPCAP_COMMIT"
