# tree 打包记录

| 打包修订 | 说明 |
| --- | --- |
| `r2` | 修复官方 tar 目录索引在 GitHub Actions 中无法稳定解析版本的问题：最新稳定版本改为从官方 GitHub 备份仓库的纯数字 Tag 动态解析；源码仍下载官方主发布站 tarball，并继续与同版本 Tag / Commit 的实际构建源码逐文件交叉核对；静态编译方式和 Release 单文件结构不变。 |
| `r1` | 首个 x86-64 静态单文件构建；每次从 tree 官方发布目录动态解析最新稳定版本，下载官方 tarball，并与官方 Git 同版本 Tag / Commit 的实际构建源码交叉核对；保持上游 Makefile 构建流程，只将编译器切换为 `musl-gcc` 并以 `-static` 完成静态链接，Release 仅发布 `tree`。 |

目标应用 Version / Tag / Commit 不在仓库中持久化为锁定值；每次 Build 动态解析最新稳定上游版本。构建方式、静态链接策略或 Release 资产结构发生实质变化时递增 `PACKAGE_REVISION`。
