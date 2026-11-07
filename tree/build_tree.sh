#!/usr/bin/env bash
############# 初始化脚本 #############
# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 定义官方上游地址与构建产物名称。
PRIMARY_INDEX='https://oldmanprogrammer.net/tar/tree/'
UPSTREAM_URL='https://github.com/Old-Man-Programmer/tree.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='tree'

############# 获取上游版本 #############
# 读取本次构建使用的上游版本。
# 本程序专属处理：根据官方 Git Tag 定位官网正式源码包。
TREE_TAG="$(bash "$SCRIPT_DIR/../common/git/latest_stable_tag.sh" "$UPSTREAM_URL" '')"
TREE_VERSION="$TREE_TAG"
TREE_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$UPSTREAM_URL" "$TREE_TAG")"

PACKAGE_VERSION="$TREE_VERSION"
WORK_DIR="$BUILD_BASE/tree-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"
GIT_DIR="$WORK_DIR/git"
SOURCE_ARCHIVE="$WORK_DIR/tree-$TREE_VERSION.tgz"
SOURCE_URL="${PRIMARY_INDEX}tree-${TREE_VERSION}.tgz"

############# 准备构建目录 #############
# 仅清理当前软件的工作目录与输出目录。
rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

############# 获取官方源码 #############
# 下载官方正式源码包。
bash "$SCRIPT_DIR/../common/download/download_file.sh" "$SOURCE_URL" "$SOURCE_ARCHIVE"
# 解包官方源码包。
# 本程序专属处理：去除归档外层目录，保留真实源码层级。
bash "$SCRIPT_DIR/../common/archive/extract_archive.sh" "$SOURCE_ARCHIVE" "$SOURCE_DIR" 1

# 本程序专属处理：确认官网正式源码包具有预期的构建文件。
for required_file in Makefile LICENSE INSTALL README tree.c tree.h; do
    [[ -s "$SOURCE_DIR/$required_file" ]] || {
        echo "tree 官方源码包缺少预期文件：$required_file" >&2
        exit 1
    }
done

# 克隆官方源码并核对实际 Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$UPSTREAM_URL" "$GIT_DIR" "$TREE_COMMIT" "$TREE_TAG"

# 本程序专属处理：逐文件核对官网源码包与官方 Git Tag 的实际构建输入。
for source_file in Makefile color.c file.c filter.c hash.c html.c info.c json.c list.c \
    strverscmp.c tree.c tree.h unix.c util.c xml.c; do
    cmp -s "$SOURCE_DIR/$source_file" "$GIT_DIR/$source_file" || {
        echo "tree 官方 tarball 与 Git Tag 内容不一致：$source_file" >&2
        exit 1
    }
done

############### 静态编译 ###############
# 按已确认的编译参数构建静态二进制。
# 本程序专属处理：保留 musl-gcc 和静态链接参数。
make -C "$SOURCE_DIR" -j"$(nproc)" CC=musl-gcc LDFLAGS='-static -s'

############### 整理产物 ###############
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/tree" "$DIST_DIR/$ARTIFACT_NAME"
# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

# 输出本次构建的实际版本和上游 Commit。
printf 'Built %s (%s, tag %s, commit %s)\n' "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$TREE_TAG" "$TREE_COMMIT"
