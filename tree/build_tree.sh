#!/usr/bin/env bash
# 命令执行失败、变量未定义或管道失败时立即退出。
set -Eeuo pipefail

# 定位软件脚本目录，并使用仓库内公共构建入口。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PRIMARY_INDEX='https://oldmanprogrammer.net/tar/tree/'
UPSTREAM_URL='https://github.com/Old-Man-Programmer/tree.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='tree'

# 从官方 Git Tag 动态选择当前最新稳定版本及对应 Commit。
TREE_TAG="$(bash "$SCRIPT_DIR/../common/git/latest_stable_tag.sh" "$UPSTREAM_URL" '')"
TREE_VERSION="$TREE_TAG"
TREE_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$UPSTREAM_URL" "$TREE_TAG")"

PACKAGE_VERSION="$TREE_VERSION"
WORK_DIR="$BUILD_BASE/tree-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"
GIT_DIR="$WORK_DIR/git"
SOURCE_ARCHIVE="$WORK_DIR/tree-$TREE_VERSION.tgz"
SOURCE_URL="${PRIMARY_INDEX}tree-${TREE_VERSION}.tgz"

# 仅清理当前软件的工作目录与输出目录。
rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

# 从官方主发布站下载源码包。
bash "$SCRIPT_DIR/../common/download/download_file.sh" "$SOURCE_URL" "$SOURCE_ARCHIVE"
# 去除官方压缩包外层目录，并解包正式源码。
bash "$SCRIPT_DIR/../common/archive/extract_archive.sh" "$SOURCE_ARCHIVE" "$SOURCE_DIR" 1

for required_file in Makefile LICENSE INSTALL README tree.c tree.h; do
    [[ -s "$SOURCE_DIR/$required_file" ]] || {
        echo "tree 官方源码包缺少预期文件：$required_file" >&2
        exit 1
    }
done

# 克隆对应的官方稳定 Tag 并核对 Checkout Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$UPSTREAM_URL" "$GIT_DIR" "$TREE_COMMIT" "$TREE_TAG"

# 官方主站 tarball 与官方 Git Tag 的实际构建输入必须一致。
for source_file in \
    Makefile \
    color.c file.c filter.c hash.c html.c info.c json.c list.c \
    strverscmp.c tree.c tree.h unix.c util.c xml.c; do
    cmp -s "$SOURCE_DIR/$source_file" "$GIT_DIR/$source_file" || {
        echo "tree 官方 tarball 与 Git Tag 内容不一致：$source_file" >&2
        exit 1
    }
done

###### 静态编译 ######
# 保留当前软件已经验证的专属编译参数与执行顺序。
make -C "$SOURCE_DIR" \
    -j"$(nproc)" \
    CC=musl-gcc \
    LDFLAGS='-static -s'

###### 整理产物 ######
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/tree" "$DIST_DIR/$ARTIFACT_NAME"
# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" \
    "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

printf 'Built %s (%s, tag %s, commit %s)\n' \
    "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$TREE_TAG" "$TREE_COMMIT"
