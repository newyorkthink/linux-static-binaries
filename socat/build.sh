#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/version.conf"

: "${PACKAGE_REVISION:?PACKAGE_REVISION 未设置}"
: "${ALPINE_IMAGE:?ALPINE_IMAGE 未设置}"

UPSTREAM_URL='https://repo.or.cz/socat.git'
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='socat.tar.xz'

stable_tags="$(
    git ls-remote --tags --refs "$UPSTREAM_URL" 'refs/tags/tag-*' |
        awk '$2 ~ /^refs\/tags\/tag-[0-9]+(\.[0-9]+)+$/ {sub(/^refs\/tags\//, "", $2); print $2}'
)"
[[ -n "$stable_tags" ]] || {
    echo '无法从上游解析 socat 最新稳定 Tag。' >&2
    exit 1
}

SOCAT_TAG="$(printf '%s\n' "$stable_tags" | sort -V | tail -n 1)"
SOCAT_VERSION="${SOCAT_TAG#tag-}"
[[ "$SOCAT_VERSION" =~ ^[0-9]+([.][0-9]+)+$ ]] || {
    echo "解析出的 socat 稳定版本格式异常：$SOCAT_TAG" >&2
    exit 1
}

SOCAT_COMMIT="$(git ls-remote --tags "$UPSTREAM_URL" "refs/tags/$SOCAT_TAG^{}" | awk 'NR == 1 {print $1}')"
if [[ -z "$SOCAT_COMMIT" ]]; then
    SOCAT_COMMIT="$(git ls-remote --tags --refs "$UPSTREAM_URL" "refs/tags/$SOCAT_TAG" | awk 'NR == 1 {print $1}')"
fi
[[ "$SOCAT_COMMIT" =~ ^[0-9a-f]{40}$ ]] || {
    echo "无法解析 $SOCAT_TAG 对应的上游 Commit。" >&2
    exit 1
}

PACKAGE_VERSION="${SOCAT_VERSION}-r${PACKAGE_REVISION}"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

docker run --rm \
    -e "SOCAT_TAG=$SOCAT_TAG" \
    -e "SOCAT_COMMIT=$SOCAT_COMMIT" \
    -e "PACKAGE_VERSION=$PACKAGE_VERSION" \
    -v "$REPO_ROOT:/workspace" \
    "$ALPINE_IMAGE" \
    /bin/sh -euxc '
        apk add --no-cache \
            autoconf \
            automake \
            build-base \
            file \
            git \
            linux-headers \
            ncurses-dev \
            ncurses-static \
            openssl-dev \
            openssl-libs-static \
            pkgconf \
            readline-dev \
            readline-static \
            tar \
            xz

        SOURCE_DIR=/tmp/socat-source
        STAGE_DIR=/tmp/socat-stage

        rm -rf "$SOURCE_DIR" "$STAGE_DIR"
        git clone --quiet --depth=1 --branch "$SOCAT_TAG" \
            https://repo.or.cz/socat.git \
            "$SOURCE_DIR"

        ACTUAL_COMMIT="$(git -C "$SOURCE_DIR" rev-parse HEAD)"
        if [ "$ACTUAL_COMMIT" != "$SOCAT_COMMIT" ]; then
            printf "上游 Commit 不匹配：动态解析 %s，实际 Checkout %s\n" "$SOCAT_COMMIT" "$ACTUAL_COMMIT" >&2
            exit 1
        fi

        cd "$SOURCE_DIR"
        autoreconf -fi

        CC=gcc \
        CFLAGS="-Os" \
        LDFLAGS="-static -s" \
        LIBS="-lncursesw" \
        ./configure --prefix=/usr

        grep -Eq "^#define WITH_OPENSSL 1$" config.h
        grep -Eq "^#define WITH_READLINE 1$" config.h

        make -j"$(getconf _NPROCESSORS_ONLN)" progs
        make DESTDIR="$STAGE_DIR" install

        install -Dm644 "$SOURCE_DIR/COPYING" "$STAGE_DIR/usr/share/licenses/socat/COPYING"
        if [ -f "$SOURCE_DIR/COPYING.OpenSSL" ]; then
            install -Dm644 "$SOURCE_DIR/COPYING.OpenSSL" "$STAGE_DIR/usr/share/licenses/socat/COPYING.OpenSSL"
        fi

        expected_paths="
usr/bin/filan
usr/bin/procan
usr/bin/socat
usr/bin/socat1
usr/bin/socat-broker.sh
usr/bin/socat-chain.sh
usr/bin/socat-mux.sh
usr/share/man/man1/socat.1
usr/share/man/man1/socat1.1
usr/share/licenses/socat/COPYING
usr/share/licenses/socat/COPYING.OpenSSL
"

        actual_paths="$(
            cd "$STAGE_DIR"
            find usr \( -type f -o -type l \) -print | sort
        )"

        if [ "$(printf "%s\n" "$expected_paths" | sed "/^$/d" | sort)" != "$actual_paths" ]; then
            echo "标准运行时安装集与已核查布局不一致；可能是上游安装集发生变化，禁止静默遗漏或新增文件。" >&2
            printf "已核查布局：\n%s\n" "$(printf "%s\n" "$expected_paths" | sed "/^$/d" | sort)" >&2
            printf "本次上游实际安装：\n%s\n" "$actual_paths" >&2
            exit 1
        fi

        [ -L "$STAGE_DIR/usr/bin/socat" ]
        [ "$(readlink "$STAGE_DIR/usr/bin/socat")" = "socat1" ]
        [ -L "$STAGE_DIR/usr/share/man/man1/socat.1" ]
        [ "$(readlink "$STAGE_DIR/usr/share/man/man1/socat.1")" = "socat1.1" ]

        for binary in socat1 filan procan; do
            target="$STAGE_DIR/usr/bin/$binary"

            file "$target" | grep -Fq "ELF 64-bit"

            if readelf -l "$target" | grep -Fq "Requesting program interpreter"; then
                echo "$binary 仍包含 ELF interpreter，不是完整静态二进制。" >&2
                exit 1
            fi

            if readelf -d "$target" 2>/dev/null | grep -Fq "(NEEDED)"; then
                echo "$binary 仍包含动态 NEEDED 依赖，不是完整静态二进制。" >&2
                exit 1
            fi
        done

        tar -C "$STAGE_DIR" -cJf /workspace/socat/dist/socat.tar.xz usr
    '

printf '%s\n' "$PACKAGE_VERSION" > "$DIST_DIR/version.txt"

(
    cd "$DIST_DIR"
    sha256sum "$ARTIFACT_NAME" > "$ARTIFACT_NAME.sha256"
)

printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$SOCAT_TAG" "$SOCAT_COMMIT"
