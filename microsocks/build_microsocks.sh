#!/usr/bin/env bash
# 命令执行失败、变量未定义或管道失败时立即退出。
set -Eeuo pipefail

# 定位软件脚本目录，并使用仓库内公共构建入口。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_URL='https://github.com/rofl0r/microsocks.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='microsocks'

# 从 GitHub API 动态解析最新正式 Release 及对应 Commit。
MICROSOCKS_TAG="$(bash "$SCRIPT_DIR/../common/github/latest_stable_release_tag.sh" 'rofl0r/microsocks' 'v[0-9]+([.][0-9]+)+')"
MICROSOCKS_VERSION="${MICROSOCKS_TAG#v}"
MICROSOCKS_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$UPSTREAM_URL" "$MICROSOCKS_TAG")"

PACKAGE_VERSION="$MICROSOCKS_VERSION"
WORK_DIR="$BUILD_BASE/microsocks-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"

# 仅清理当前软件的工作目录与输出目录。
rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

# 从官方稳定 Tag 克隆源码，并核对实际 Checkout Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$UPSTREAM_URL" "$SOURCE_DIR" "$MICROSOCKS_COMMIT" "$MICROSOCKS_TAG"

###### 静态编译 ######
# 保留当前软件已经验证的专属编译参数与执行顺序。
make -C "$SOURCE_DIR" \
    -j"$(nproc)" \
    CC=musl-gcc \
    CFLAGS='-Os -Wall -std=c99' \
    LDFLAGS='-static -s'

###### 整理产物 ######
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/microsocks" "$DIST_DIR/$ARTIFACT_NAME"

# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" \
    "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$MICROSOCKS_TAG" "$MICROSOCKS_COMMIT"
