# socat 版本记录

| 打包版本 | 上游版本 | 上游 Tag | 上游 Commit | 说明 |
| --- | --- | --- | --- | --- |
| `1.8.1.3-r1` | `1.8.1.3` | `tag-1.8.1.3` | `af5388c898c7bb60997935aee93c223deba60c4a` | 首个完整静态运行时安装集版本；按上游 `make install` 保留 `socat` / `socat1`、`filan`、`procan`、三个 socat 辅助脚本及两份 man page，并以 `socat.tar.xz` 发布完整安装树。 |

规则：上游版本变化时更新上游版本、Tag 和 Commit；上游版本不变但本仓库构建方式、编译参数、标准运行时安装集或 Release 资产结构发生实质变化时，只递增 `PACKAGE_REVISION`，并在本文件追加新记录。
