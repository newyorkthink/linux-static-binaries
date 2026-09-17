# Linux Static Binaries

用于从上游源码构建可移植、低依赖的 Linux 静态 ELF 二进制。

> [!IMPORTANT]
> AI coding agents 在读取、修改或提交本仓库前，必须先完整阅读 [AGENTS.md](./AGENTS.md)。

## 仓库说明

- 每个软件使用独立目录维护源码版本、构建脚本、版本历史和说明文档。
- 优先从上游官方源码构建，并固定上游版本、Tag 和对应 Commit，避免构建来源漂移。
- 对适合静态链接的小型 C/C++ 工具，优先使用 musl 生成真正的静态 ELF；不为了“单文件”额外套 AppImage、RunImage、Sharun 或其他运行时包装层。
- Release 采用固定 `latest` Tag 和固定资产名，便于脚本长期引用；具体软件版本在对应目录的版本文件和版本历史中维护。
- 构建产物不提交进 Git 仓库，由 GitHub Actions 生成并发布到 Releases。

## 当前软件

| 软件 | 打包版本 | 上游版本 | 架构 | 构建方式 | Release 资产 |
| --- | --- | --- | --- | --- | --- |
| [MicroSocks](./microsocks/) | `1.0.5-r1` | `1.0.5` | `x86_64` | musl 静态链接 | `microsocks-x86_64-linux` |

## 目录结构

```text
.github/
  actions/build-static/   共享静态二进制构建与发布 Action
  workflows/build.yml     唯一正式构建 Workflow
microsocks/
  build.sh                MicroSocks 构建脚本
  version.conf            固定上游版本、Tag、Commit 和打包修订号
  VERSIONS.md             版本历史
  README.md               软件说明
  COPYING                 上游许可证
```

## Releases

正式产物统一发布到仓库的 `latest` Release，Release 标题固定为 `Latest`。

每个软件使用稳定资产名，不把版本号写进资产文件名；版本更新后覆盖 `latest` 中对应资产，但历史版本必须继续记录在软件目录的 `VERSIONS.md`，并可通过 Git 提交历史追溯对应构建定义。

MicroSocks 当前发布：

```text
microsocks-x86_64-linux
microsocks-x86_64-linux.sha256
microsocks-LICENSE.txt
microsocks-version.txt
```

`microsocks-version.txt` 记录当前打包版本，例如 `1.0.5-r1`。

## 版本管理

每个软件必须同时维护：

1. `version.conf`：当前构建固定使用的上游版本、Tag、Commit，以及仓库自己的打包修订号。
2. `VERSIONS.md`：按版本追加历史记录，不覆盖旧记录。
3. 构建输出中的 `dist/version.txt`：由构建脚本根据 `version.conf` 生成，供 Release 发布流程读取。

上游版本不变但构建方式发生实质变化时，只递增打包修订号，例如 `1.0.5-r1` → `1.0.5-r2`。

## 本地构建

不同软件的依赖和构建方式以各自目录的 README 为准。仓库不会要求宿主系统安装运行时动态库来执行最终静态二进制，但内核、CPU 架构以及软件自身功能仍可能存在平台要求。
