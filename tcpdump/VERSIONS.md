# tcpdump 打包记录

| 打包修订 | 说明 |
| --- | --- |
| `r1` | 首个静态单文件方案；每次 Build 动态解析 tcpdump 与 libpcap 的最新稳定 Tag，先从源码构建静态 `libpcap.a`，再以 `-static` 链接 tcpdump，最终 Release 只发布 `tcpdump`。为避免把宿主机可选动态库带入单文件，libpcap 显式关闭 libnl、D-Bus、RDMA，可选 tcpdump 功能关闭 libsmi、libcrypto、libcap-ng。 |

目标应用 tcpdump 的 Version / Tag / Commit 不在仓库中持久化为锁定值；libpcap 作为源码构建依赖同样在每次 Build 动态解析最新稳定 Tag。构建方式、静态依赖策略或 Release 资产结构发生实质变化时递增 `PACKAGE_REVISION`。
