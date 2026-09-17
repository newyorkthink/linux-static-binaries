# socat 打包记录

| 打包修订 | 说明 |
| --- | --- |
| `r3` | 补齐 Git Tag 源码树缺少预生成 `doc/socat.1` 的处理：Alpine 3.22 的 main/community 不提供 `yodl2man`，因此按本次动态解析出的 socat 版本下载同版本官方发布归档，先核对归档 `VERSION` 并确认 `doc/socat.yo` 与已核对 Commit 的 Git 源码完全一致，再仅取官方预生成的 `doc/socat.1` 供上游 `make install` 使用；程序仍从已核对 Commit 的 Git 源码静态编译。 |
| `r2` | Git Tag 源码树不包含生成后的 `configure`，改为按上游 `configure.ac` 的说明直接运行 `autoconf` 生成 `configure`，避免 `autoreconf` 额外调用 `autoheader` 因上游大量未声明模板而失败；其余静态编译参数、完整运行时安装集和 Release 资产结构不变。 |
| `r1` | 首个完整静态运行时安装集打包方案；按上游 `make install` 保留 `socat` / `socat1`、`filan`、`procan`、三个 socat 辅助脚本及两份 man page，并以 `socat.tar.xz` 发布完整安装树。 |

目标应用 Version / Tag / Commit 不在仓库中持久化为锁定值；每次 Build 动态解析最新稳定上游版本。构建方式、编译参数、标准运行时安装集处理或 Release 资产结构发生实质变化时递增 `PACKAGE_REVISION`，并在本文件追加打包变更记录。
