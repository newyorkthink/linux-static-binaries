# tcpdump

上游项目：

- tcpdump：[the-tcpdump-group/tcpdump](https://github.com/the-tcpdump-group/tcpdump)
- libpcap：[the-tcpdump-group/libpcap](https://github.com/the-tcpdump-group/libpcap)

tcpdump 是命令行网络抓包与数据包分析工具。tcpdump 本身依赖 libpcap；本仓库不会依赖目标系统已经安装的动态 `libpcap0.8t64` / `libpcap.so`，而是在每次 Build 中从官方 libpcap 源码生成静态 `libpcap.a` 并直接链接进最终 `tcpdump`。

## 版本获取规则

tcpdump 与 libpcap 的 GitHub 仓库均以稳定 Git Tag 发布正式源码。本仓库每次 Build：

1. 从 tcpdump 官方仓库动态读取 `tcpdump-<数字版本>` Tag，只接受纯数字稳定版本，排除 RC、beta、PRE-GIT 等非稳定标签。
2. 从 libpcap 官方仓库动态读取 `libpcap-<数字版本>` Tag，使用相同的稳定版本筛选规则。
3. 分别解析 Tag 对应的不可变 Commit SHA，Checkout 后再次核对实际 Commit。
4. tcpdump 的动态版本用于生成 `dist/version.txt`；任何目标版本、Tag 或 Commit 都不会写回仓库作为后续 Build 锁定值。

[`version.conf`](./version.conf) 只保存本仓库打包修订号。

## 静态构建

官方 tcpdump 文档明确说明 tcpdump 必须使用 libpcap，并支持把已构建的 libpcap 源码树放在 tcpdump 同级目录；tcpdump 的 Autoconf 逻辑会优先使用该本地 `libpcap.a`。

本仓库按以下方式构建：

1. 从官方源码动态 Checkout 最新稳定 libpcap。
2. 使用 `musl-gcc` 和上游 Autoconf 构建 `libpcap.a`，关闭 shared library。构建前从 `linux-libc-dev` 提供的 Linux UAPI 头中复制 `linux/`、`asm-generic/` 和当前架构 `asm/` 到独立目录，仅把该目录加入 musl 的预处理头搜索路径，不直接加入宿主 glibc 头目录。
3. 为避免最终静态链接被宿主机可选开发库污染，libpcap 显式关闭 libnl、D-Bus 和 RDMA 集成；Linux 原生 packet socket、BPF 过滤、pcap/pcapng 读写等核心能力仍由 libpcap 自身提供。
4. 动态 Checkout 最新稳定 tcpdump，把上述本地 `libpcap.a` 作为抓包库。
5. tcpdump 同样使用 `musl-gcc` 与同一套隔离 Linux UAPI 头，关闭可选 libsmi、libcrypto、libcap-ng 集成，并使用 `LDFLAGS=-static` 完成最终链接。
6. 最终使用 `file` 与 `readelf` 静态检查：必须是 x86-64 ELF，不得存在 ELF interpreter 或动态 `NEEDED` 项。

因此，`linux-libc-dev` 只属于构建时依赖；目标机器**不需要安装**它，也不需要安装 Debian/Kali 的 `libpcap0.8t64`。libpcap 与 musl libc 都链接进同一个静态 ELF 文件中。

## 单文件与功能取舍

最终 Release 只发布：

```text
tcpdump
```

上游标准安装还会包含 `tcpdump.1` man page；它只是文档，不是运行 tcpdump 所需文件，因此不随 Release 发布。

为了保持真正的单文件并避免额外静态依赖，本构建不包含几个上游可选集成：

- libnl：libpcap 的 Linux 802.11 monitor-mode 辅助集成；普通接口抓包不依赖它。
- D-Bus 与 RDMA：特殊抓包后端，不属于普通以太网 / Wi-Fi 接口抓包的核心路径。
- libsmi：tcpdump 的 SNMP MIB 动态加载增强。
- libcrypto：部分 ESP 解密和 TCP MD5 等可选解码能力。
- libcap-ng：Linux capabilities 的可选权限降级集成；抓包权限本身仍由内核权限、root 或文件 capability 决定。

如果未来需要上述可选能力，应单独评估其静态依赖链，而不是让最终二进制回退到目标系统的动态库。

## 使用与权限

读取已有抓包文件通常不需要 root；实时抓取网络接口则需要相应权限。例如：

```bash
sudo ./tcpdump -i <接口>
```

也可以由系统管理员按自己的安全策略配置 Linux file capabilities。不要给不可信用户开放抓包权限，因为抓包可能读取其他网络流量和敏感数据。

## License

tcpdump 与 libpcap 都使用 BSD 风格许可证。仓库分别保留上游原始 [`LICENSE`](./LICENSE) 和 [`LIBPCAP-LICENSE`](./LIBPCAP-LICENSE)；最终二进制静态包含 libpcap 代码，因此两份上游许可证均保留在源码仓库中。
