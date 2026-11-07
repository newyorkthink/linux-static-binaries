#!/usr/bin/env bash
# 命令执行失败、变量未定义或管道失败时立即退出。
set -Eeuo pipefail

# 定位软件脚本目录，并使用仓库内公共构建入口。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_URL='https://github.com/lyonel/lshw.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='lshw'

# 从官方上游动态取得最新稳定 Tag 和实际 Commit。
LSHW_TAG="$(bash "$SCRIPT_DIR/../common/git/latest_stable_tag.sh" "$UPSTREAM_URL" 'B.')"
LSHW_VERSION="${LSHW_TAG#B.}"
LSHW_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$UPSTREAM_URL" "$LSHW_TAG")"

PACKAGE_VERSION="$LSHW_VERSION"
WORK_DIR="$BUILD_BASE/lshw-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"

# 仅清理当前软件的工作目录与输出目录。
rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$DIST_DIR"

# 从官方稳定 Tag 克隆源码，并核对实际 Checkout Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$UPSTREAM_URL" "$SOURCE_DIR" "$LSHW_COMMIT" "$LSHW_TAG"

###### 静态编译 ######
# 保留当前软件已经验证的专属编译参数与执行顺序。
make -C "$SOURCE_DIR/src" \
    -j"$(nproc)" \
    VERSION="$LSHW_TAG" \
    NO_VERSION_CHECK=1 \
    core

make -C "$SOURCE_DIR/src" \
    VERSION="$LSHW_TAG" \
    NO_VERSION_CHECK=1 \
    static

###### 整理产物 ######
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/src/lshw-static" "$DIST_DIR/$ARTIFACT_NAME"

# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" \
    "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$LSHW_TAG" "$LSHW_COMMIT"
