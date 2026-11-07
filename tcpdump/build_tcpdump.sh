#!/usr/bin/env bash
############# 初始化脚本 #############
# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 定义官方上游地址与构建产物名称。
TCPDUMP_URL='https://github.com/the-tcpdump-group/tcpdump.git'
LIBPCAP_URL='https://github.com/the-tcpdump-group/libpcap.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='tcpdump'

############# 获取上游版本 #############
# 读取本次构建使用的上游版本。
# 本程序专属处理：分别获取 tcpdump 与 libpcap 的稳定 Tag 和 Commit。
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

############# 准备构建目录 #############
# 仅清理当前软件的工作目录与输出目录。
rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

############# 准备构建环境 #############
# 本程序专属处理：查找 Linux UAPI 头文件，供 musl 静态编译使用。
MULTIARCH="$(dpkg-architecture -qDEB_HOST_MULTIARCH)"
LINUX_UAPI_DIR="$WORK_DIR/linux-uapi"
LINUX_UAPI_ARCH_DIR="/usr/include/$MULTIARCH/asm"

# 本程序专属处理：检查编译所需的 Linux UAPI 头文件目录。
for required_dir in /usr/include/linux /usr/include/asm-generic "$LINUX_UAPI_ARCH_DIR"; do
    [[ -d "$required_dir" ]] || {
        echo "缺少 Linux UAPI 头目录：$required_dir" >&2
        exit 1
    }
done

# 本程序专属处理：将 Linux UAPI 头文件复制到独立构建目录。
mkdir -p "$LINUX_UAPI_DIR"
cp -aL /usr/include/linux "$LINUX_UAPI_DIR/"
cp -aL /usr/include/asm-generic "$LINUX_UAPI_DIR/"
cp -aL "$LINUX_UAPI_ARCH_DIR" "$LINUX_UAPI_DIR/asm"

MUSL_CFLAGS="-O2 -isystem $LINUX_UAPI_DIR"

############# 获取官方源码 #############
# 本程序专属处理：分别克隆 tcpdump 与 libpcap，并核对各自的 Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$LIBPCAP_URL" "$LIBPCAP_DIR" "$LIBPCAP_COMMIT" "$LIBPCAP_TAG"
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$TCPDUMP_URL" "$TCPDUMP_DIR" "$TCPDUMP_COMMIT" "$TCPDUMP_TAG"

############### 静态编译 ###############
# 按已确认的编译参数构建静态二进制。
# 本程序专属处理：先生成 libpcap.a，供 tcpdump 静态链接使用。
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

# 本程序专属处理：将 tcpdump 与本次构建的静态 libpcap 链接。
(
    cd "$TCPDUMP_DIR"
    ./autogen.sh
    CC=musl-gcc CFLAGS="$MUSL_CFLAGS" LDFLAGS='-static' ./configure \
        --without-smi \
        --without-crypto \
        --without-cap-ng
    make -j"$(nproc)" tcpdump
)

############### 整理产物 ###############
# 将静态主程序复制到 dist 目录。
install -Dm755 "$TCPDUMP_DIR/tcpdump" "$DIST_DIR/$ARTIFACT_NAME"
# 本程序专属处理：去除最终二进制中的可剥离符号。
strip "$DIST_DIR/$ARTIFACT_NAME"

# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" \
    "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

# 输出本次构建的实际版本和上游 Commit。
printf 'Built %s (%s; tcpdump %s @ %s; libpcap %s @ %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" \
    "$TCPDUMP_TAG" "$TCPDUMP_COMMIT" \
    "$LIBPCAP_TAG" "$LIBPCAP_COMMIT"
