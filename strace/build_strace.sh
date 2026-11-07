#!/usr/bin/env bash
# 命令执行失败、变量未定义或管道失败时立即退出。
set -Eeuo pipefail

# 定位软件脚本目录，并使用仓库内公共构建入口。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STRACE_URL='https://github.com/strace/strace.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='strace'

# 从官方 Git 最新稳定数字 Tag 动态取得版本及 Commit。
STRACE_TAG="$(bash "$SCRIPT_DIR/../common/git/latest_stable_tag.sh" "$STRACE_URL" 'v')"
STRACE_VERSION="${STRACE_TAG#v}"
STRACE_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$STRACE_URL" "$STRACE_TAG")"

PACKAGE_VERSION="$STRACE_VERSION"
WORK_DIR="$BUILD_BASE/strace-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"

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

# 克隆上游稳定 Tag 并核对实际 Checkout Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$STRACE_URL" "$SOURCE_DIR" "$STRACE_COMMIT" "$STRACE_TAG"

MUSL_CPPFLAGS="-isystem $LINUX_UAPI_DIR"
MUSL_CFLAGS="-O2 -static"
###### 静态编译 ######
# 保留当前软件已经验证的专属编译参数与执行顺序。
(
    cd "$SOURCE_DIR"
    ./bootstrap
    CC=musl-gcc CFLAGS="$MUSL_CFLAGS" CPPFLAGS="$MUSL_CPPFLAGS" LDFLAGS='-static' ./configure \
        --enable-mpers=no \
        --enable-stacktrace=no
    make -j"$(nproc)" CPPFLAGS="$MUSL_CPPFLAGS"
)

###### 整理产物 ######
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/src/strace" "$DIST_DIR/$ARTIFACT_NAME"
# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" \
    "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$STRACE_TAG" "$STRACE_COMMIT"
