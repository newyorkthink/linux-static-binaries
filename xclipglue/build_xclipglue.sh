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

############### 准备构建环境 ###############
# 本程序专属处理：使用经官方 SHA-256 校验的 Zig 工具链原生构建 musl 静态二进制。
ZIG_VERSION='0.15.2'
ZIG_DIR="$WORK_DIR/zig"
MUSL_PREFIX="$WORK_DIR/musl-prefix"
bash "$SCRIPT_DIR/../common/download/download_file.sh" \
    "https://ziglang.org/download/$ZIG_VERSION/zig-x86_64-linux-$ZIG_VERSION.tar.xz" "$WORK_DIR/zig.tar.xz" \
    '02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239'
bash "$SCRIPT_DIR/../common/archive/extract_archive.sh" "$WORK_DIR/zig.tar.xz" "$ZIG_DIR" 1

# 本程序专属处理：下载带有固定校验摘要的 X.Org 静态依赖源码，保持目标软件版本动态解析。
bash "$SCRIPT_DIR/../common/download/download_file.sh" \
    'https://www.x.org/releases/individual/lib/libXau-1.0.12.tar.xz' "$WORK_DIR/libXau.tar.xz" \
    '74d0e4dfa3d39ad8939e99bda37f5967aba528211076828464d2777d477fc0fb'
bash "$SCRIPT_DIR/../common/download/download_file.sh" \
    'https://www.x.org/releases/individual/lib/libXdmcp-1.1.5.tar.xz' "$WORK_DIR/libXdmcp.tar.xz" \
    'd8a5222828c3adab70adf69a5583f1d32eb5ece04304f7f8392b6a353aa2228c'
bash "$SCRIPT_DIR/../common/download/download_file.sh" \
    'https://xorg.freedesktop.org/releases/individual/proto/xcb-proto-1.17.0.tar.xz' "$WORK_DIR/xcb-proto.tar.xz" \
    '2c1bacd2110f4799f74de6ebb714b94cf6f80fb112316b1219480fd22562148c'
bash "$SCRIPT_DIR/../common/download/download_file.sh" \
    'https://xorg.freedesktop.org/releases/individual/lib/libxcb-1.17.0.tar.xz' "$WORK_DIR/libxcb.tar.xz" \
    '599ebf9996710fea71622e6e184f3a8ad5b43d0e5fa8c4e407123c88a59a6d55'

# 使用仓库公共解包入口展开本次构建的依赖源码。
bash "$SCRIPT_DIR/../common/archive/extract_archive.sh" "$WORK_DIR/libXau.tar.xz" "$WORK_DIR/libXau" 1
bash "$SCRIPT_DIR/../common/archive/extract_archive.sh" "$WORK_DIR/libXdmcp.tar.xz" "$WORK_DIR/libXdmcp" 1
bash "$SCRIPT_DIR/../common/archive/extract_archive.sh" "$WORK_DIR/xcb-proto.tar.xz" "$WORK_DIR/xcb-proto" 1
bash "$SCRIPT_DIR/../common/archive/extract_archive.sh" "$WORK_DIR/libxcb.tar.xz" "$WORK_DIR/libxcb" 1

# 本程序专属处理：全部依赖使用同一 musl ABI，优先链接独立前缀中的静态库。
ZIG="$ZIG_DIR/zig"
export CC="$ZIG cc -target x86_64-linux-musl"
export CXX="$ZIG c++ -target x86_64-linux-musl"
export PKG_CONFIG_PATH="$MUSL_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export CPPFLAGS="-I$MUSL_PREFIX/include -idirafter /usr/include"
export LDFLAGS="-L$MUSL_PREFIX/lib"

############### 静态编译 ###############
# 根据 X.Org 官方依赖关系，先构建 Xau、Xdmcp，再安装 XCB 协议文件并编译 XCB。
for dependency in libXau libXdmcp; do
    (
        cd "$WORK_DIR/$dependency"
        ./configure --host=x86_64-linux-musl --prefix="$MUSL_PREFIX" --disable-shared --enable-static
        make -j"$(nproc)"
        make install
    )
done

# 安装与 libxcb 对应的协议描述及 Python 代码生成器。
(
    cd "$WORK_DIR/xcb-proto"
    PYTHON=python3 ./configure --prefix="$MUSL_PREFIX"
    make install
)

# 使用本次安装的协议生成器编译静态 XCB，避免链接 Ubuntu 的 glibc 版本。
export PYTHONPATH="$(pkg-config --variable=pythondir xcb-proto)${PYTHONPATH:+:$PYTHONPATH}"
(
    cd "$WORK_DIR/libxcb"
    ./configure --host=x86_64-linux-musl --prefix="$MUSL_PREFIX" --disable-shared --enable-static --without-doxygen
    make -j"$(nproc)"
    make install
)

# 本程序专属处理：保留上游 make progs 目标，使用 musl C++ 工具链和本次编译的静态 XCB 库。
make -C "$SOURCE_DIR" progs CXX="$CXX" CXXFLAGS="-O2 -static -s -I$MUSL_PREFIX/include" \
    XCBLIB="-L$MUSL_PREFIX/lib -lxcb -lXau -lXdmcp"

############### 整理产物 ###############
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/xclipglue" "$DIST_DIR/$ARTIFACT_NAME"
# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

# 输出本次构建的实际版本和上游 Commit。
printf 'Built %s (%s, upstream commit %s)\n' "$ARTIFACT_NAME" "$UPSTREAM_VERSION" "$UPSTREAM_COMMIT"
