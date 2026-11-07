#!/usr/bin/env bash
set -Eeuo pipefail

# 读取归档路径、目标目录和可选解包层数。
ARCHIVE="${1:-}"
OUTPUT_DIR="${2:-}"
STRIP_COMPONENTS="${3:-0}"

# 本仓库兼容处理：允许 tar 源码包指定去除外层目录层数。
(( $# >= 2 && $# <= 3 )) && [[ "$STRIP_COMPONENTS" =~ ^[0-9]+$ ]] || {
  echo '用法：extract_archive.sh <归档文件> <输出目录> [tar 去除层数]' >&2
  exit 2
}
[[ -f "$ARCHIVE" && -n "$OUTPUT_DIR" ]] || {
  echo "用法：$0 <归档文件> <输出目录>" >&2
  exit 1
}
[[ "$OUTPUT_DIR" != / ]] || {
  echo "错误：禁止把归档解包到根目录。" >&2
  exit 1
}

if (( STRIP_COMPONENTS > 0 )); then
  case "$ARCHIVE" in
    *.tar | *.tar.gz | *.tgz | *.tar.xz | *.txz | *.tar.bz2 | *.tbz2) ;;
    *) echo '错误：仅 tar 归档允许去除目录层数。' >&2; exit 2 ;;
  esac
fi
# 创建本次解包的目标目录。
mkdir -p "$OUTPUT_DIR"

# 归档格式判断和解包命令统一保留在公共入口；项目脚本只传入文件与目标目录。
case "$ARCHIVE" in
  *.zip)
    command -v unzip >/dev/null 2>&1 || {
      echo "错误：解包 ZIP 需要 unzip。" >&2
      exit 1
    }
    unzip -q "$ARCHIVE" -d "$OUTPUT_DIR"
    ;;
  *.exe)
    command -v 7z >/dev/null 2>&1 || {
      echo "错误：解包 NSIS 安装包需要 7z。" >&2
      exit 1
    }
    # 只提取安装包内容，不执行 Windows 安装程序。
    7z x -y -o"$OUTPUT_DIR" "$ARCHIVE" >/dev/null
    ;;
  *.deb)
    command -v dpkg-deb >/dev/null 2>&1 || {
      echo "错误：解包 DEB 需要 dpkg-deb。" >&2
      exit 1
    }
    dpkg-deb -x "$ARCHIVE" "$OUTPUT_DIR"
    ;;
  *.snap)
    command -v unsquashfs >/dev/null 2>&1 || {
      echo "错误：解包 Snap 需要 unsquashfs。" >&2
      exit 1
    }
    unsquashfs -no-progress -d "$OUTPUT_DIR" "$ARCHIVE"
    ;;
  *.distro)
    command -v brotli >/dev/null 2>&1 || {
      echo "错误：解包 distro 需要 brotli。" >&2
      exit 1
    }
    command -v tar >/dev/null 2>&1 || {
      echo "错误：解包 distro 需要 tar。" >&2
      exit 1
    }
    brotli -dc "$ARCHIVE" | tar -x -C "$OUTPUT_DIR"
    ;;
  *.tar | *.tar.gz | *.tgz | *.tar.xz | *.txz | *.tar.bz2 | *.tbz2)
    command -v tar >/dev/null 2>&1 || {
      echo "错误：解包 tar 归档需要 tar。" >&2
      exit 1
    }
    if (( STRIP_COMPONENTS == 0 )); then
      tar -xf "$ARCHIVE" -C "$OUTPUT_DIR"
    elif [[ "$ARCHIVE" == *.tgz || "$ARCHIVE" == *.tar.gz ]]; then
      tar -xzf "$ARCHIVE" --no-same-owner --no-same-permissions \
        --strip-components="$STRIP_COMPONENTS" -C "$OUTPUT_DIR"
    else
      tar -xf "$ARCHIVE" --no-same-owner --no-same-permissions \
        --strip-components="$STRIP_COMPONENTS" -C "$OUTPUT_DIR"
    fi
    ;;
  *)
    echo "错误：不支持的归档格式：$ARCHIVE" >&2
    exit 1
    ;;
esac
