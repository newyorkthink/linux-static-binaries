#!/usr/bin/env bash
############# 初始化脚本 #############
# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 定义官方上游地址与构建产物名称。
STRACE_URL='https://github.com/strace/strace.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='strace'

############# 获取上游版本 #############
# 读取本次构建使用的上游版本。

STRACE_TAG="$(bash "$SCRIPT_DIR/../common/git/latest_stable_tag.sh" "$STRACE_URL" 'v')"
STRACE_VERSION="${STRACE_TAG#v}"
STRACE_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$STRACE_URL" "$STRACE_TAG")"

PACKAGE_VERSION="$STRACE_VERSION"
WORK_DIR="$BUILD_BASE/strace-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"

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

############# 获取官方源码 #############
# 克隆官方源码并核对实际 Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$STRACE_URL" "$SOURCE_DIR" "$STRACE_COMMIT" "$STRACE_TAG"

MUSL_CPPFLAGS="-isystem $LINUX_UAPI_DIR"
MUSL_CFLAGS="-O2 -static"
############### 静态编译 ###############
# 按已确认的编译参数构建静态二进制。
# 本程序专属处理：执行 bootstrap，并保持 mpers 与 stacktrace 禁用。
(
    cd "$SOURCE_DIR"
    ./bootstrap
    CC=musl-gcc CFLAGS="$MUSL_CFLAGS" CPPFLAGS="$MUSL_CPPFLAGS" LDFLAGS='-static' ./configure \
        --enable-mpers=no \
        --enable-stacktrace=no
    make -j"$(nproc)" CPPFLAGS="$MUSL_CPPFLAGS"
)

############### 整理产物 ###############
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/src/strace" "$DIST_DIR/$ARTIFACT_NAME"
# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" \
    "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

# 输出本次构建的实际版本和上游 Commit。
printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$STRACE_TAG" "$STRACE_COMMIT"
