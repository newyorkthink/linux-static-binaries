# lshw

上游项目：[lyonel/lshw](https://github.com/lyonel/lshw)

lshw（Hardware Lister）用于读取并整理 Linux 主机的硬件配置信息，可输出文本、JSON、XML、HTML、businfo 等格式。

## 版本获取规则

上游 GitHub 当前没有使用 GitHub Releases 发布稳定版，稳定版本使用 `B.<数字>.<数字>` 系列 Git Tag；`T.*` 等其他系列不作为正式稳定目标。

每次正式 Build 都会：

1. 从官方 Git 仓库动态读取全部 Tag。
2. 只接受 `B.<数字>.<数字>` 或其更多数字段形式的稳定 Tag，并按版本排序选择最新项。
3. 在本次 Build 内解析该 Tag 对应的不可变 Commit SHA，Checkout 后再次核对实际 Commit。
4. 最终版本只写入构建生成的 `dist/version.txt` 和 Release 的 `software_versions.json`；Version / Tag / Commit 不回写仓库作为下次构建锁定值。

[`version.conf`](./version.conf) 只保存本仓库打包修订号。

## 构建方式

上游 README 明确提供 `src/` 目录下的 `make static` 静态构建目标。本仓库：

1. 动态 Checkout 当前最新稳定 Tag 并核对 Commit。
2. 先并行完成上游 `core` 静态库，再以非并行顶层 `make static` 构建 `lshw-static`；这样避开上游 `static` 目标在并行 Make 下的依赖竞态。不使用 `-march=native`，保持通用 x86_64 目标。
3. 使用上游提供的 `NO_VERSION_CHECK=1` 构建选项关闭 `lshw -version` 的远程 DNS 版本查询；硬件扫描功能不受影响，同时减少静态链接依赖和运行时联网行为。
4. 将静态产物按上游默认 CLI 安装布局放为 `usr/sbin/lshw`。
5. 使用 `file` / `readelf` 静态检查最终 ELF，确认是 x86-64、没有 ELF interpreter、没有动态 `NEEDED` 项。
6. 静态核对完整运行时文件清单后，归档为 `lshw.tar.xz`。

## 标准运行时安装集

上游默认 `make install` 的 CLI 安装集包含：

```text
usr/sbin/lshw
usr/share/man/man1/lshw.1
usr/share/lshw/pci.ids
usr/share/lshw/usb.ids
usr/share/lshw/oui.txt
usr/share/lshw/manuf.txt
usr/share/lshw/pnp.ids
usr/share/lshw/pnpid.txt
usr/share/locale/ca/LC_MESSAGES/lshw.mo
usr/share/locale/es/LC_MESSAGES/lshw.mo
usr/share/locale/fr/LC_MESSAGES/lshw.mo
```

上游 GTK GUI 是单独的 `make gui` / `make install-gui` 可选目标，不属于默认 CLI 安装集，因此本仓库不把 `gtk-lshw` 混入静态 CLI 资产。

Debian 的 CLI 包同样将 GUI 分开处理，并提供 `lshw`、man page 和 locale；PCI / USB ID 数据在 Debian 中由外部数据包提供。为了保持上游默认安装语义，本仓库的归档继续携带上游 `make install` 所列出的六个数据文件。

## Release 资产

lshw 使用完整安装树归档：

```text
lshw.tar.xz
```

所有软件共用：

```text
software_versions.json
```

其中 `lshw` 条目记录本次 Build 动态解析出的打包版本、固定资产名和归档 SHA-256。

如果只需要可执行文件，可从归档中单独取出：

```text
usr/sbin/lshw
```

该 ELF 本身是静态链接的；但单独取出时不会同时携带归档里的 man page、翻译和硬件 ID 数据文件。

## 使用

完整安装树解压后，可直接运行其中的静态程序：

```bash
sudo ./usr/sbin/lshw
```

若只需要较少信息，可使用上游参数，例如：

```bash
sudo ./usr/sbin/lshw -short
```

某些硬件信息只有 root 权限下才能完整读取。

## 隐私与安全

lshw 输出可能包含硬件序列号、UUID、MAC 地址等可识别设备的信息。公开粘贴完整输出前应使用上游 `-sanitize` / `-sanitise` 选项或自行检查敏感字段。

## License

lshw 使用 GPL-2.0。仓库保留上游原始 [`COPYING`](./COPYING)。
