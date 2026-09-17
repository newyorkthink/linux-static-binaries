# socat

上游项目：[socat](https://repo.or.cz/socat.git)

socat 是一个通用双向数据中继工具，可在文件、管道、TTY、UNIX / IPv4 / IPv6 Socket、TCP、UDP、TLS、代理连接和子进程等数据通道之间建立转发。

## 版本获取规则

目标应用版本不在仓库中锁定。每次正式 Build 都会：

1. 从 socat 官方 Git 仓库读取 Tag。
2. 只接受 `tag-<数字版本>` 形式的稳定 Tag，排除 beta / RC / prerelease 等非稳定命名。
3. 使用版本排序选择当前最新稳定 Tag。
4. 在本次 Build 内动态解析该 Tag 对应的 Commit SHA，Checkout 后再次核对实际 Commit。
5. 仅把本次动态解析出的上游版本与本仓库打包修订号组合后写入 `dist/version.txt` 和 Release 的 `software_versions.json`；Version / Tag / Commit 不回写仓库作为下次 Build 的锁定值。

[`version.conf`](./version.conf) 只保存本仓库打包修订号以及构建环境依赖。固定的 Alpine 镜像属于构建环境依赖，不是 socat 目标应用版本锁定。

## 标准运行时安装集核查

上游当前标准 `make install` 与主流发行版包文件布局表明，运行时安装集至少包含下列用户可调用文件和 man page：

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

构建脚本使用上游自己的 `make install DESTDIR=...` 生成完整安装树，并对上述已核查路径和符号链接关系做静态完整性检查。若未来动态解析出的新稳定版改变标准安装集，构建会因实际安装树与已核查布局不一致而停止，避免静默漏掉新增加的附加命令或脚本；此时必须先重新核查上游 install target 和发行版文件列表，再更新仓库的完整性规则。

## 构建方式

1. 动态解析官方当前最新稳定 Tag 及其 Commit。
2. 在固定的 Alpine musl 构建环境中安装编译工具链，以及 OpenSSL、readline、ncurses 的开发文件和静态库。
3. Checkout 本次动态 Tag，并核对实际 Commit 与本次动态解析值完全一致。
4. 通过 `autoreconf` 生成 configure 文件，使用 `-static` 构建 `socat`、`filan`、`procan`，同时保留 OpenSSL 和 readline 支持。
5. 使用上游自己的 `make install DESTDIR=...` 生成标准安装树，不手工重建文件布局。
6. 静态检查 `socat1`、`filan`、`procan`，确认均为 64-bit ELF，且不存在 ELF interpreter 和动态 `NEEDED` 项。
7. 核对完整标准运行时安装集、符号链接和 man page 后，将整个 `usr/` 安装树归档为 `socat.tar.xz`。
8. 生成构建期 SHA-256 和版本文本；共享 GitHub Action 上传归档后，将版本和 SHA-256 合并到统一 `software_versions.json`。

这里没有为了静态构建而关闭 OpenSSL 或 readline；构建阶段会直接检查两项功能在 `config.h` 中处于启用状态。

## Release 资产

socat 使用一个完整安装树归档：

```text
socat.tar.xz
```

归档内保留 `usr/bin/`、`usr/share/man/man1/` 和符号链接，不拆掉任何上游标准安装的运行时命令；同时从本次动态解析出的上游源码原样加入 `usr/share/licenses/socat/` 下的许可证文件。

所有软件共用：

```text
software_versions.json
```

其中 `socat` 条目记录本次 Build 动态解析出的打包版本、固定资产名和归档 SHA-256。构建目录中的 `dist/version.txt` 与 `*.sha256` 仅作为构建和发布过程的内部元数据，不单独上传到 Release。

## 使用

将归档解压到一个目录后，可直接使用 `usr/bin/` 中的命令。例如：

```bash
./usr/bin/socat TCP-LISTEN:<监听端口>,bind=<监听地址>,reuseaddr,fork TCP:<目标地址>:<目标端口>
```

端口和地址必须按实际环境替换。

## 安全说明

`socat` 可以监听网络端口、执行子进程、访问设备和创建本地 Socket。使用 `EXEC`、`SYSTEM`、`SHELL`、低端口监听或非回环地址时，应根据实际权限边界和网络暴露范围进行配置，不要把可执行任意命令或未受保护的监听端口直接暴露给不受信任网络。

## License

socat 使用 GPL-2.0 系列许可证并包含 OpenSSL 相关许可例外。构建时从本次动态解析出的上游源码原样复制 `COPYING` 和 `COPYING.OpenSSL` 到发布归档的 `usr/share/licenses/socat/`，静态构建继续保留 OpenSSL 支持。
