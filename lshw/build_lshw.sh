#!/usr/bin/env bash
############# 初始化脚本 #############
# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 定义官方上游地址与构建产物名称。
UPSTREAM_URL='https://github.com/lyonel/lshw.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='lshw'

############# 获取上游版本 #############
# 读取本次构建使用的上游版本。

LSHW_TAG="$(bash "$SCRIPT_DIR/../common/git/latest_stable_tag.sh" "$UPSTREAM_URL" 'B.')"
LSHW_VERSION="${LSHW_TAG#B.}"
LSHW_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$UPSTREAM_URL" "$LSHW_TAG")"

PACKAGE_VERSION="$LSHW_VERSION"
WORK_DIR="$BUILD_BASE/lshw-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"

############# 准备构建目录 #############
# 仅清理当前软件的工作目录与输出目录。
rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

############# 获取官方源码 #############
# 克隆官方源码并核对实际 Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$UPSTREAM_URL" "$SOURCE_DIR" "$LSHW_COMMIT" "$LSHW_TAG"

############### 静态编译 ###############
# 按已确认的编译参数构建静态二进制。
# 本程序专属处理：先编译 core 目标。
make -C "$SOURCE_DIR/src" \
    -j"$(nproc)" \
    VERSION="$LSHW_TAG" \
    NO_VERSION_CHECK=1 \
    core

# 本程序专属处理：随后单独构建 static 目标。
make -C "$SOURCE_DIR/src" \
    VERSION="$LSHW_TAG" \
    NO_VERSION_CHECK=1 \
    static

############### 整理产物 ###############
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/src/lshw-static" "$DIST_DIR/$ARTIFACT_NAME"

# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" \
    "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

# 输出本次构建的实际版本和上游 Commit。
printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$LSHW_TAG" "$LSHW_COMMIT"
