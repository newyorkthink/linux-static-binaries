# socat 打包记录

| 打包修订 | 说明 |
| --- | --- |
| `r1` | 首个完整静态运行时安装集打包方案；按上游 `make install` 保留 `socat` / `socat1`、`filan`、`procan`、三个 socat 辅助脚本及两份 man page，并以 `socat.tar.xz` 发布完整安装树。 |

目标应用 Version / Tag / Commit 不在仓库中持久化为锁定值；每次 Build 动态解析最新稳定上游版本。构建方式、编译参数、标准运行时安装集处理或 Release 资产结构发生实质变化时递增 `PACKAGE_REVISION`，并在本文件追加打包变更记录。
