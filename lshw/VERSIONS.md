# lshw 打包记录

| 打包修订 | 说明 |
| --- | --- |
| `r3` | 按仓库单文件交付规则改为直接发布静态 ELF `lshw`；不再发布 `lshw.tar.xz`。man page 与 locale 属于文档 / 翻译，六个硬件 ID 数据文件用于名称解析增强而非核心硬件扫描；上游没有原生“把这些数据嵌入 ELF”的构建开关，因此不为单文件大幅修改上游。 |
| `r2` | 修复上游 `static` 目标在并行 Make 下的依赖竞态：先并行完成 `core/liblshw.a`，再以非并行顶层 `make static` 完成 `lshw-static` 链接；不改变静态参数、运行时安装集或 Release 资产结构。 |
| `r1` | 首个完整静态 CLI 运行时安装集方案；使用上游 `make static` 构建 x86_64 静态 ELF，并按上游默认 `make install` 的 CLI 安装集保留 `lshw`、man page、硬件 ID 数据文件和 ca / es / fr 翻译，发布为 `lshw.tar.xz`。上游可选 GTK GUI 使用独立 `install-gui` 目标，不属于默认 CLI 安装集。 |

目标应用 Version / Tag / Commit 不在仓库中持久化为锁定值；每次 Build 动态解析最新稳定 `B.<数字>.<数字>` 系列 Tag。构建方式、编译参数、标准运行时安装集处理或 Release 资产结构发生实质变化时递增 `PACKAGE_REVISION`，并在本文件追加打包变更记录。
