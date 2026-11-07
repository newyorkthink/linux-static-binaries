# deborphan

构建脚本：[`build_deborphan.sh`](./build_deborphan.sh)。

上游项目：[Debian deborphan](https://tracker.debian.org/pkg/deborphan)，官方 Git 仓库：[salsa.debian.org/debian/deborphan](https://salsa.debian.org/debian/deborphan)。

`deborphan` 读取本机 dpkg 状态，列出没有其他包依赖的已安装包。默认只查 `libs`、`oldlibs` 和 `introspection` 段里的库。

## 版本获取规则

deborphan 是 Debian 原生源码包，没有独立的 GitHub Release。每次正式 Build：

1. 从官方 salsa 仓库动态读取 `debian/` 前缀的纯数字稳定 Tag，排除带字母后缀的非稳定 Tag，并按版本号选择当前最新稳定版本。
2. 用该版本号下载 Debian 源码池的 `deborphan_<版本>.tar.xz`，不使用发行版 `.deb` 或预编译二进制作为构建输入。
3. 动态解析同版本 Tag 对应的 Commit SHA，Checkout 后再次核对实际 Commit。
4. 比较 Debian 源码包与同版本 salsa Tag 的文件内容；不一致时停止构建。
5. 动态版本只写入构建生成的 `dist/version.txt` 和 Release `software_versions.json`，不会写回仓库成为后续版本锁定值。

当前版本直接来自本次实际使用的官方上游源码。上游 `configure.ac` 里的版本字符串可能落后于 salsa Tag，因此 `deborphan --version` 打印的是 `configure.ac` 的字符串；本仓库记录的是本次解析出的稳定 Tag。

## 构建方式

上游使用 Autotools。Debian 包通过 `dh` 执行 `autoreconf` 和 `./configure`，再 `make`。本仓库保持这一配置入口，不修改 deborphan 源码。

为了得到可跨常见 Linux 发行版使用的静态单文件，配置时覆盖这些参数：

- `CC=musl-gcc`、`CFLAGS=-O2 -static`、`LDFLAGS=-static`：用 musl 静态链接 libc。
- `--disable-nls`：不链接 musl 没有的外置 libintl，因此没有翻译。
- `--without-debfoster`：不探测本机 debfoster keep 文件。
- `--prefix=/usr --localstatedir=/var`：状态文件为 `/var/lib/dpkg/status`，保留名单为 `/var/lib/deborphan/keep`。

只编译 `src/deborphan`。构建完成后使用 `file` 与 `readelf` 检查：产物必须是 x86-64 静态 ELF，且不得包含 ELF interpreter 或动态 `NEEDED` 项。

## 标准安装集与单文件取舍

上游 `make install` 还会安装 man page，并可能安装 locale。自 1.7.34 起，上游已经删除 shell 菜单 `orphaner` 和 `editkeep`。更早的包里这两个名字是同一个脚本：`orphaner` 用 `dialog` 或 `whiptail` 勾选后调用 `apt-get` 删除，`editkeep` 用菜单编辑保留名单。它们依赖本机的 `dialog`、`gettext` 和 `apt-get`，不参与读取 dpkg 状态。

因此 Release 只发布主程序：

```text
deborphan
```

没有 man page 时用 `deborphan --help`。保留名单用 `--add-keep`、`--del-keep`、`--list-keep` 和 `--zero-keep`，文件仍是 `/var/lib/deborphan/keep`。要删除包，先看 `deborphan` 的输出，再自行运行 `apt-get remove`。没有 dpkg 状态文件时无法列出孤立包。

## 使用

在安装了 dpkg 的 Linux 上执行：

```bash
# 列出默认库段中的孤立包。
./deborphan
```

```bash
# 列出全部段的孤立包。
./deborphan --all-packages
```

程序只读取 dpkg 状态和 keep 文件，不修改已安装的包。修改 keep 文件需要对应目录的写权限。

## License

上游以 MIT License 发布。本仓库保留上游原始 [`COPYING`](./COPYING) 文件。
