#!/usr/bin/env bash
############# 初始化脚本 #############
# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 定义官方上游地址与构建产物名称。
SOURCE_URL='https://www.chiark.greenend.org.uk/~sgtatham/utils/xclipglue.tar.gz'
UPSTREAM_URL='https://git.tartarus.org/simon/xclipglue.git'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
WORK_DIR="$BUILD_BASE/xclipglue-build"
SOURCE_DIR="$WORK_DIR/source"
GIT_DIR="$WORK_DIR/git"
ARTIFACT_NAME='xclipglue'

############# 准备构建目录 #############
# 仅清理当前软件的工作目录与输出目录。
rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$SOURCE_DIR" "$DIST_DIR"

############# 获取官方源码 #############
# 下载官方正式源码包。
# 本程序专属处理：官网 tarball 为正式发布源码，开发 Git 仓库没有稳定 Tag。
bash "$SCRIPT_DIR/../common/download/download_file.sh" "$SOURCE_URL" "$WORK_DIR/xclipglue.tar.gz"
# 解包官方源码包。
# 本程序专属处理：去除归档外层目录，保留真实源码层级。
bash "$SCRIPT_DIR/../common/archive/extract_archive.sh" "$WORK_DIR/xclipglue.tar.gz" "$SOURCE_DIR" 1

# 本程序专属处理：确认正式源码包含编译文件和 man page。
[[ -s "$SOURCE_DIR/xclipglue.cpp" && -s "$SOURCE_DIR/Makefile" && -s "$SOURCE_DIR/xclipglue.1" ]] || {
    echo '上游正式源码包缺少预期文件。' >&2
    exit 1
}

# 本程序专属处理：克隆官方 Git HEAD，并核对实际 Commit。
UPSTREAM_COMMIT="$(bash "$SCRIPT_DIR/../common/git/resolve_git_commit.sh" "$UPSTREAM_URL" HEAD)"
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$UPSTREAM_URL" "$GIT_DIR" "$UPSTREAM_COMMIT"

############# 获取上游版本 #############
# 读取本次构建使用的上游版本。
# 本程序专属处理：核对官网源码、man page 和 Git HEAD，并读取正式版本。
UPSTREAM_VERSION="$(python3 - "$SOURCE_DIR" "$GIT_DIR" <<'PY'
import pathlib
import re
import sys

source, checkout = (pathlib.Path(p) for p in sys.argv[1:])
published = (source / 'xclipglue.cpp').read_text(encoding='utf-8')
git_source = (checkout / 'xclipglue.cpp').read_text(encoding='utf-8')
version_pattern = re.compile(r'"xclipglue, version ([0-9]{8}\.[0-9a-f]{7,40})";')
matches = version_pattern.findall(published)
if len(matches) != 1:
    raise SystemExit('正式源码包中的版本号缺失或格式异常。')
version = matches[0]
if f'xclipglue version {version}' not in (source / 'xclipglue.1').read_text(encoding='utf-8'):
    raise SystemExit('正式源码包的源码和 man page 版本不一致。')
if (source / 'Makefile').read_bytes() != (checkout / 'Makefile').read_bytes():
    raise SystemExit('正式源码包的 Makefile 与官方 Git HEAD 不一致。')

published = version_pattern.sub('"xclipglue, unknown version"; /*---buildsys-replace---*/', published)
if published != git_source:
    raise SystemExit('正式源码包的程序内容与官方 Git HEAD 不一致。')
print(version)
PY
)"

# 本程序专属处理：使用官网正式源码中的版本记录本次构建。
PACKAGE_VERSION="$UPSTREAM_VERSION"

############### 静态编译 ###############
# 按已确认的编译参数构建静态二进制。
# 本程序专属处理：使用 C++ 和 XCB 静态链接参数构建程序。
make -C "$SOURCE_DIR" progs \
    CXX=g++ \
    CXXFLAGS='-O2 -static -s' \
    XCBLIB='-lxcb -lXau -lXdmcp'

############### 整理产物 ###############
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/xclipglue" "$DIST_DIR/$ARTIFACT_NAME"
# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" \
    "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

# 输出本次构建的实际版本和上游 Commit。
printf 'Built %s (%s, upstream commit %s)\n' \
    "$ARTIFACT_NAME" "$UPSTREAM_VERSION" "$UPSTREAM_COMMIT"
