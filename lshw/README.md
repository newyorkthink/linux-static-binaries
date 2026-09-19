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

上游 README 明确提供 `src/` 目录下的 `make static` 静态构建目标。本仓库先并行完成上游 `core` 静态库，再以非并行顶层 `make static` 构建 `lshw-static`，避开上游并行依赖竞态；不使用 `-march=native`。同时使用 `NO_VERSION_CHECK=1` 关闭 `lshw -version` 的远程 DNS 版本查询。locale catalog 不是程序启动或硬件扫描的必需文件；目标系统没有对应翻译时，gettext 会回退到源码中的英文文本。

最终只复制静态 ELF 为 `dist/lshw`，并使用 `file` / `readelf` 确认是 x86-64、没有 ELF interpreter、没有动态 `NEEDED` 项。

## 上游附加文件核查

上游默认 `make install` 除主程序外还会安装：

- `lshw.1`：man page，只用于离线帮助文档，不影响硬件扫描。
- ca / es / fr 的 `lshw.mo`：界面文本翻译；单文件不携带这些 locale，缺少翻译时程序使用源码中的英文文本。
- `pci.ids`、`usb.ids`、`oui.txt`、`manuf.txt`、`pnp.ids`、`pnpid.txt`：硬件厂商 / 产品名称数据库，用于把部分数字 ID 解析成更友好的名称。

这些硬件数据库有用，但属于名称解析增强，不是 lshw 扫描 `/sys`、`/proc`、DMI、PCI、USB 等核心硬件信息的必要文件。上游代码会继续从 `/usr/share/lshw/`、`/usr/share/hwdata/`、`/usr/share/misc/` 等系统位置查找现有数据库；目标系统已有相应数据时仍可使用。

上游当前没有提供把这六个数据库直接嵌入 `lshw` ELF 的原生构建开关。真正内嵌需要修改上游数据加载代码并把数 MB 文本转换成编译期资源；本仓库不为此大幅修改上游。目标系统没有任何对应数据库时，单文件仍能扫描硬件，但部分 PCI / USB / PnP 厂商或型号名称可能不如带数据库时完整。

上游 GTK GUI 是独立可选目标，不属于本仓库的 CLI 单文件。

## Release 资产

只发布一个可直接下载执行的静态文件：

```text
lshw
```

旧的 `lshw.tar.xz` 在单文件成功发布后由发布流程删除。所有软件共用 `software_versions.json`，其中 `lshw` 条目记录打包版本、固定资产名和最终 ELF SHA-256。

## 使用

```bash
sudo ./lshw
```

若只需要较少信息：

```bash
sudo ./lshw -short
```

某些硬件信息只有 root 权限下才能完整读取。

## 隐私与安全

lshw 输出可能包含硬件序列号、UUID、MAC 地址等可识别设备的信息。公开粘贴完整输出前应使用上游 `-sanitize` / `-sanitise` 选项或自行检查敏感字段。

## License

lshw 使用 GPL-2.0。仓库保留上游原始 [`COPYING`](./COPYING)。
