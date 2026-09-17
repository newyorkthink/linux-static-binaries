# socat

上游项目：[socat](https://repo.or.cz/socat.git)

socat 是一个通用双向数据中继工具，可在文件、管道、TTY、UNIX / IPv4 / IPv6 Socket、TCP、UDP、TLS、代理连接和子进程等数据通道之间建立转发。

## 当前版本

```text
打包版本：1.8.1.3-r1
上游版本：1.8.1.3
上游 Tag：tag-1.8.1.3
上游 Commit：af5388c898c7bb60997935aee93c223deba60c4a
```

版本固定值统一维护在 [`version.conf`](./version.conf)，历史记录见 [`VERSIONS.md`](./VERSIONS.md)。

## 标准运行时安装集核查

当前固定上游版本的 `Makefile.in` 中，标准 `make install` 会安装下列运行时文件：

```text
usr/bin/
├── filan
├── procan
├── socat -> socat1
├── socat1
├── socat-broker.sh
├── socat-chain.sh
└── socat-mux.sh

usr/share/man/man1/
├── socat.1 -> socat1.1
└── socat1.1
```

该文件集合也与当前主流发行版的 socat 包文件布局一致。构建脚本会对这 9 个路径做静态完整性核对，缺少任何一个文件或符号链接关系不正确都会直接失败，避免只发布主 `socat` 而遗漏上游附加命令。

## 构建方式

1. 在固定的 Alpine musl 构建环境中安装编译工具链，以及 OpenSSL、readline、ncurses 的开发文件和静态库。
2. 从上游公开 Git 仓库 Checkout `version.conf` 指定的 Tag，并核对实际 Commit 与固定 Commit 完全一致。
3. 通过 `autoreconf` 生成 configure 文件，使用 `-static` 构建 `socat`、`filan`、`procan`，同时保留 OpenSSL 和 readline 支持。
4. 使用上游自己的 `make install DESTDIR=...` 生成标准安装树，不手工重建文件布局。
5. 静态检查 `socat1`、`filan`、`procan`，确认均为 64-bit ELF，且不存在 ELF interpreter 和动态 `NEEDED` 项。
6. 核对完整标准运行时安装集、符号链接和 man page 后，将整个 `usr/` 安装树归档为 `socat.tar.xz`。
7. 生成构建期 SHA-256 和版本文本；共享 GitHub Action 上传归档后，将版本和 SHA-256 合并到统一 `software_versions.json`。

## Release 资产

socat 使用一个完整安装树归档：

```text
socat.tar.xz
```

归档内保留 `usr/bin/`、`usr/share/man/man1/` 和符号链接，不拆掉任何上游标准安装的运行时命令；同时从固定上游源码原样加入 `usr/share/licenses/socat/` 下的许可证文件。

所有软件共用：

```text
software_versions.json
```

其中 `socat` 条目记录当前打包版本、固定资产名和归档 SHA-256。构建目录中的 `dist/version.txt` 与 `*.sha256` 仅作为构建和发布过程的内部元数据，不单独上传到 Release。

## 使用

将归档解压到一个目录后，可直接使用 `usr/bin/` 中的命令。例如：

```bash
./usr/bin/socat TCP-LISTEN:<监听端口>,bind=<监听地址>,reuseaddr,fork TCP:<目标地址>:<目标端口>
```

端口和地址必须按实际环境替换。

## 安全说明

`socat` 可以监听网络端口、执行子进程、访问设备和创建本地 Socket。使用 `EXEC`、`SYSTEM`、`SHELL`、低端口监听或非回环地址时，应根据实际权限边界和网络暴露范围进行配置，不要把可执行任意命令或未受保护的监听端口直接暴露给不受信任网络。

## License

socat 使用 GPL-2.0 系列许可证并包含 OpenSSL 相关许可例外。构建时从固定 Commit 的上游源码原样复制 `COPYING` 和 `COPYING.OpenSSL` 到发布归档的 `usr/share/licenses/socat/`，静态构建继续保留 OpenSSL 支持。
