#!/usr/bin/env bash
############# 初始化脚本 #############
# 启用严格模式，在命令执行失败、引用未定义变量或管道执行失败时退出。
set -Eeuo pipefail

# 获取脚本所在目录的绝对路径。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 定义官方上游地址与构建产物名称。
UPSTREAM_URL='https://salsa.debian.org/debian/deborphan.git'
SOURCE_INDEX='https://deb.debian.org/debian/pool/main/d/deborphan/'
BUILD_BASE="${RUNNER_TEMP:-$SCRIPT_DIR/.build}"
DIST_DIR="$SCRIPT_DIR/dist"
ARTIFACT_NAME='deborphan'

############# 获取上游版本 #############
# 读取本次构建使用的上游版本。
# 本程序专属处理：稳定版本来自 salsa 的 debian/ 数字 Tag，不锁定具体版本。
DEB_TAG="$(bash "$SCRIPT_DIR/../common/git/latest_stable_tag.sh" "$UPSTREAM_URL" 'debian/')"
PACKAGE_VERSION="${DEB_TAG#debian/}"
# 本程序专属处理：salsa 稳定 Tag 含斜杠，公共引用校验不接受该形式，这里解析剥除注解后的 Commit。
DEB_PEELED="$(git ls-remote --tags "$UPSTREAM_URL" "refs/tags/${DEB_TAG}^{}" | awk 'NR==1{print $1}')"
DEB_LIGHT="$(git ls-remote --tags --refs "$UPSTREAM_URL" "refs/tags/${DEB_TAG}" | awk 'NR==1{print $1}')"
DEB_COMMIT="${DEB_PEELED:-$DEB_LIGHT}"

WORK_DIR="$BUILD_BASE/deborphan-$PACKAGE_VERSION"
SOURCE_DIR="$WORK_DIR/source"
GIT_DIR="$WORK_DIR/git"
SOURCE_ARCHIVE="$WORK_DIR/deborphan_${PACKAGE_VERSION}.tar.xz"
SOURCE_URL="${SOURCE_INDEX}deborphan_${PACKAGE_VERSION}.tar.xz"

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

# 克隆官方源码并核对实际 Commit。
bash "$SCRIPT_DIR/../common/git/clone_verified_source.sh" "$UPSTREAM_URL" "$GIT_DIR" "$DEB_COMMIT" "$DEB_TAG"

# 本程序专属处理：Debian 源码包必须与同版本 salsa Tag 的文件内容一致。
diff -rq "$SOURCE_DIR" "$GIT_DIR" --exclude=.git

############### 静态编译 ###############
# 按已确认的编译参数构建静态二进制。
# 本程序专属处理：生成上游配置脚本，用 musl 静态链接，并把 dpkg 状态与 keep 文件放在 /var。
(
    cd "$SOURCE_DIR"
    autoreconf -fi
    CC=musl-gcc CFLAGS='-O2 -static' LDFLAGS='-static' \
        ./configure --disable-nls --without-debfoster --prefix=/usr --localstatedir=/var
    make -C src -j"$(nproc)"
)

############### 整理产物 ###############
# 将静态主程序复制到 dist 目录。
install -Dm755 "$SOURCE_DIR/src/deborphan" "$DIST_DIR/$ARTIFACT_NAME"
# 统一检查静态 ELF，并生成实际版本与 SHA-256。
bash "$SCRIPT_DIR/../common/build/finalize_static_binary.sh" "$DIST_DIR/$ARTIFACT_NAME" "$PACKAGE_VERSION"

# 输出本次构建的实际版本和上游 Commit。
printf 'Built %s (%s, tag %s, commit %s)\n' "$ARTIFACT_NAME" "$PACKAGE_VERSION" "$DEB_TAG" "$DEB_COMMIT"
