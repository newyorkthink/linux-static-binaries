# common

本目录保存静态二进制构建的公共入口，不复制图形打包和 AppImage 专属实现。

| 文件 | 用途 |
| --- | --- |
| `github/github_api.sh` | 统一访问官方 GitHub API |
| `github/latest_stable_release_tag.sh` | 动态取得正式 Release Tag |
| `git/latest_stable_tag.sh` | 动态选择稳定数字 Tag |
| `git/resolve_git_commit.sh` | 从 Tag 或 HEAD 解析 Commit |
| `git/clone_verified_source.sh` | 克隆官方源码并核对实际 Commit |
| `download/download_file.sh` | 复用公共 HTTPS 文件下载 |
| `archive/extract_archive.sh` | 通用解包，并兼容 tar 外层目录剥离 |
| `build/finalize_static_binary.sh` | 静态 ELF 核验及版本、摘要输出 |

软件的官方来源规则和静态编译参数只在对应的 `build_<软件名>.sh` 中维护。最终 Release 和 `software_versions.json` 仍由现有共享 Action 负责。

中文注释遵循 [公共注释标准](../docs/build-comments.md)。
