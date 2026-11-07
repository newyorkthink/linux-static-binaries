#!/usr/bin/env bash
############# 初始化脚本 #############
# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 定义官方上游地址与构建产物名称。
UPSTREAM_URL='https://git.code.sf.net/p/sshpass/code-git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='sshpass'

############# 获取上游版本 #############
# 读取本次构建使用的上游版本。
# 本程序专属处理：从官方 Git 仓库动态选择最新的稳定 v 数字 Tag。
SSHPASS_TAG="$(bash "$SCRIPT_DIR/../common/git/latest_stable_tag.sh" "$UPSTREAM_URL" 'v')"
SSHPASS_VERSION="${SSHPASS_TAG#v}"
SSHPASS_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$UPSTREAM_URL" "$SSHPASS_TAG")"

PACKAGE_VERSION="$SSHPASS_VERSION"
WORK_DIR="$BUILD_BASE/sshpass-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"

############# 准备构建目录 #############
# 仅清理当前软件的工作目录与输出目录。
rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

############# 获取官方源码 #############
# 克隆官方源码并核对实际 Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$UPSTREAM_URL" "$SOURCE_DIR" "$SSHPASS_COMMIT" "$SSHPASS_TAG"

############### 静态编译 ###############
# 按已确认的编译参数构建静态二进制。
# 本程序专属处理：先执行上游 bootstrap，再用 musl-gcc 原生编译并静态链接。
(
    cd "$SOURCE_DIR"
    ./bootstrap
    CC=musl-gcc CFLAGS='-O2 -static' LDFLAGS='-static -s' ./configure
    make -j"$(nproc)"
)

############### 整理产物 ###############
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/sshpass" "$DIST_DIR/$ARTIFACT_NAME"
# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

# 输出本次构建的实际版本和上游 Commit。
printf 'Built %s (%s, tag %s, commit %s)\n' "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$SSHPASS_TAG" "$SSHPASS_COMMIT"
