# MicroSocks 版本记录

| 打包版本 | 上游版本 | 上游 Tag | 上游 Commit | 说明 |
| --- | --- | --- | --- | --- |
| `1.0.5-r3` | `1.0.5` | `v1.0.5` | `98421a21c4adc4c77c0cf3a5d650cc28ad3e0107` | 二进制编译方式保持不变；Release 资产名从 `microsocks-x86_64-linux` 简化为 `microsocks`，统一不再追加架构 / 平台尾缀。 |
| `1.0.5-r2` | `1.0.5` | `v1.0.5` | `98421a21c4adc4c77c0cf3a5d650cc28ad3e0107` | 二进制构建方式保持不变；Release 元数据改为统一 `software_versions.json`，停止单独发布版本、SHA-256 和 License 文本资产。 |
| `1.0.5-r1` | `1.0.5` | `v1.0.5` | `98421a21c4adc4c77c0cf3a5d650cc28ad3e0107` | 首个静态单文件版本；使用 musl 静态链接，发布 x86_64 ELF。 |

规则：上游版本变化时更新上游版本、Tag 和 Commit；上游版本不变但本仓库构建方式、编译参数或 Release 资产结构发生实质变化时，只递增 `PACKAGE_REVISION`，并在本文件追加新记录。
