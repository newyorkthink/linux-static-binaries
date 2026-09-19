# lshw 打包记录

| 打包修订 | 说明 |
| --- | --- |
| `r2` | 修复上游 `static` 目标在并行 Make 下的依赖竞态：先并行完成 `core/liblshw.a`，再以非并行顶层 `make static` 完成 `lshw-static` 链接；不改变静态参数、运行时安装集或 Release 资产结构。 |
| `r1` | 首个完整静态 CLI 运行时安装集方案；使用上游 `make static` 构建 x86_64 静态 ELF，并按上游默认 `make install` 的 CLI 安装集保留 `lshw`、man page、硬件 ID 数据文件和 ca / es / fr 翻译，发布为 `lshw.tar.xz`。上游可选 GTK GUI 使用独立 `install-gui` 目标，不属于默认 CLI 安装集。 |

目标应用 Version / Tag / Commit 不在仓库中持久化为锁定值；每次 Build 动态解析最新稳定 `B.<数字>.<数字>` 系列 Tag。构建方式、编译参数、标准运行时安装集处理或 Release 资产结构发生实质变化时递增 `PACKAGE_REVISION`，并在本文件追加打包变更记录。
