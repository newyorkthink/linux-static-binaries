#!/usr/bin/env bash
# 命令执行失败、变量未定义或管道失败时立即退出。
set -Eeuo pipefail

# 定位软件脚本目录，并使用仓库内公共构建入口。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TCPDUMP_URL='https://github.com/the-tcpdump-group/tcpdump.git'
LIBPCAP_URL='https://github.com/the-tcpdump-group/libpcap.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='tcpdump'

# 分别取得 tcpdump 与 libpcap 的官方最新稳定 Tag 及对应 Commit。
TCPDUMP_TAG="$(bash "$SCRIPT_DIR/../common/git/latest_stable_tag.sh" "$TCPDUMP_URL" 'tcpdump-')"
LIBPCAP_TAG="$(bash "$SCRIPT_DIR/../common/git/latest_stable_tag.sh" "$LIBPCAP_URL" 'libpcap-')"
TCPDUMP_VERSION="${TCPDUMP_TAG#tcpdump-}"
LIBPCAP_VERSION="${LIBPCAP_TAG#libpcap-}"
TCPDUMP_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$TCPDUMP_URL" "$TCPDUMP_TAG")"
LIBPCAP_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$LIBPCAP_URL" "$LIBPCAP_TAG")"

PACKAGE_VERSION="$TCPDUMP_VERSION"
WORK_DIR="$BUILD_BASE/tcpdump-$PACKAGE_VERSION"
TCPDUMP_DIR="$WORK_DIR/tcpdump"
LIBPCAP_DIR="$WORK_DIR/libpcap"

# 仅清理当前软件的工作目录与输出目录。
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

MUSL_CFLAGS="-O2 -isystem $LINUX_UAPI_DIR"

# 克隆两份官方源码并分别核对真实 Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$LIBPCAP_URL" "$LIBPCAP_DIR" "$LIBPCAP_COMMIT" "$LIBPCAP_TAG"
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$TCPDUMP_URL" "$TCPDUMP_DIR" "$TCPDUMP_COMMIT" "$TCPDUMP_TAG"

###### 静态编译 ######
# 保留当前软件已经验证的专属编译参数与执行顺序。
(
    cd "$LIBPCAP_DIR"
    ./autogen.sh
    CC=musl-gcc CFLAGS="$MUSL_CFLAGS" ./configure \
        --disable-shared \
        --without-libnl \
        --disable-dbus \
        --disable-rdma
    make -j"$(nproc)" libpcap.a
)

(
    cd "$TCPDUMP_DIR"
    ./autogen.sh
    CC=musl-gcc CFLAGS="$MUSL_CFLAGS" LDFLAGS='-static' ./configure \
        --without-smi \
        --without-crypto \
        --without-cap-ng
    make -j"$(nproc)" tcpdump
)

###### 整理产物 ######
# 将静态主程序复制到 dist 目录。
install -Dm755 "$TCPDUMP_DIR/tcpdump" "$DIST_DIR/$ARTIFACT_NAME"
strip "$DIST_DIR/$ARTIFACT_NAME"

# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" \
    "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

printf 'Built %s (%s; tcpdump %s @ %s; libpcap %s @ %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" \
    "$TCPDUMP_TAG" "$TCPDUMP_COMMIT" \
    "$LIBPCAP_TAG" "$LIBPCAP_COMMIT"
