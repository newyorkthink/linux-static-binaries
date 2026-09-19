# tcpdump 打包记录

| 打包修订 | 说明 |
| --- | --- |
| `r2` | 将 libpcap 与 tcpdump 统一改为 `musl-gcc` 静态构建；显式安装 `linux-libc-dev`，并把 Linux UAPI 的 `linux/`、`asm-generic/`、当前架构 `asm/` 解引用复制到隔离目录供 musl 使用，修复 `musl-gcc` 因 `-nostdinc` 找不到 `linux/if.h` 的问题，同时避免把宿主 glibc 头目录混入构建。Release 仍只发布单文件 `tcpdump`。 |
| `r1` | 首个静态单文件方案；每次 Build 动态解析 tcpdump 与 libpcap 的最新稳定 Tag，先从源码构建静态 `libpcap.a`，再以 `-static` 链接 tcpdump，最终 Release 只发布 `tcpdump`。为避免把宿主机可选动态库带入单文件，libpcap 显式关闭 libnl、D-Bus、RDMA，可选 tcpdump 功能关闭 libsmi、libcrypto、libcap-ng。 |

目标应用 tcpdump 的 Version / Tag / Commit 不在仓库中持久化为锁定值；libpcap 作为源码构建依赖同样在每次 Build 动态解析最新稳定 Tag。构建方式、静态依赖策略或 Release 资产结构发生实质变化时递增 `PACKAGE_REVISION`。
