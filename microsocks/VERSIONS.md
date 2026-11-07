# MicroSocks 打包记录

| 打包修订 | 说明 |
| --- | --- |
| `r3` | 二进制编译方式保持不变；Release 资产名简化为 `microsocks`，统一不再追加架构 / 平台尾缀。 |
| `r2` | 二进制构建方式保持不变；Release 元数据改为统一 `software_versions.json`，停止单独发布版本、SHA-256 和 License 文本资产。 |
| `r1` | 首个静态单文件打包方案；使用 musl 静态链接，发布 x86_64 ELF。 |

目标应用 Version / Tag / Commit 不在仓库中持久化为锁定值；每次 Build 动态解析最新稳定上游版本。构建方式、编译参数或 Release 资产结构发生实质变化时，在本文件追加构建变更记录。

## 现行版本管理

- 构建成功后，使用本次从官方上游动态获得的实际软件版本生成 `dist/version.txt`，不再使用独立 `version.conf`、`PACKAGE_REVISION` 或 `-r` 版本后缀。
- 以上 `rN` 编号与修订号说明保留为历史记录；后续构建方式的变化继续追加在本文件中，不改写旧记录。
