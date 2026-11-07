#!/usr/bin/env bash
############# 初始化脚本 #############
# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 定义官方上游地址与构建产物名称。
UPSTREAM_URL='https://github.com/rofl0r/microsocks.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='microsocks'

############# 获取上游版本 #############
# 读取本次构建使用的上游版本。
# 本程序专属处理：只接受官方 GitHub 最新正式 Release 的稳定 Tag。
MICROSOCKS_TAG="$(bash "$SCRIPT_DIR/../common/github/latest_stable_release_tag.sh" 'rofl0r/microsocks' 'v[0-9]+([.][0-9]+)+')"
MICROSOCKS_VERSION="${MICROSOCKS_TAG#v}"
MICROSOCKS_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$UPSTREAM_URL" "$MICROSOCKS_TAG")"

PACKAGE_VERSION="$MICROSOCKS_VERSION"
WORK_DIR="$BUILD_BASE/microsocks-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"

############# 准备构建目录 #############
# 仅清理当前软件的工作目录与输出目录。
rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

############# 获取官方源码 #############
# 克隆官方源码并核对实际 Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$UPSTREAM_URL" "$SOURCE_DIR" "$MICROSOCKS_COMMIT" "$MICROSOCKS_TAG"

############### 静态编译 ###############
# 按已确认的编译参数构建静态二进制。
# 本程序专属处理：使用 musl-gcc 与上游原有编译选项进行静态链接。
make -C "$SOURCE_DIR" \
    -j"$(nproc)" \
    CC=musl-gcc \
    CFLAGS='-Os -Wall -std=c99' \
    LDFLAGS='-static -s'

############### 整理产物 ###############
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/microsocks" "$DIST_DIR/$ARTIFACT_NAME"

# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" \
    "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

# 输出本次构建的实际版本和上游 Commit。
printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$MICROSOCKS_TAG" "$MICROSOCKS_COMMIT"
