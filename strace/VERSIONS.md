# strace 打包记录

| 打包修订 | 说明 |
| --- | --- |
| `r1` | 首个 x86-64 静态单文件构建。每次从官方 Git 仓库动态解析最新 `v<数字版本>` Tag，排除 rc 等非稳定标签。使用 `musl-gcc` 和上游 Autotools 构建，关闭 mpers 和 stacktrace，避免 32 位编译器、libdw、libunwind。Release 只发布 `strace`。 |

目标应用 Version / Tag / Commit 不在仓库中持久化为锁定值；每次 Build 动态解析最新稳定上游版本。构建方式、静态链接策略或 Release 资产结构发生实质变化时递增 `PACKAGE_REVISION`。
