# Linux Static Binaries

用于从上游源码构建可移植、低依赖的 Linux 静态 ELF 二进制及其完整标准运行时安装集。

> [!IMPORTANT]
> AI coding agents 在读取、修改或提交本仓库前，必须先完整阅读 [AGENTS.md](./AGENTS.md)。

## 仓库说明

- 每个软件使用独立目录维护上游版本、构建脚本、版本历史和说明文档。
- 优先从上游官方源码构建，并固定上游版本、Tag 和对应 Commit，避免构建来源漂移。
- 对适合静态链接的软件优先生成真正的静态 ELF，不为了“单文件”额外套不必要的运行时包装层。
- 新增或更新软件时必须核查上游标准安装目标和发行版包文件列表；若标准运行时安装集包含附加命令、脚本、符号链接或 man page，必须完整保留，不能只发布主程序。
- Release 采用固定 `latest` Tag 和稳定资产名，便于脚本长期引用。
- 单一二进制资产名直接使用软件可执行名；包含完整安装树的软件使用固定 `.tar.xz` 归档名，不追加版本号、架构或平台尾缀。
- 构建产物不提交进 Git 仓库，由 GitHub Actions 生成并发布到 Releases。

## 目录结构

每个软件独立维护，根 README 不维护具体软件清单，避免软件数量增加后重复维护大量条目。

```text
.github/
  actions/build-static/   共享静态构建、发布和版本清单更新 Action
  workflows/build.yml     正式构建 Workflow
<software>/
  build.sh                软件构建脚本
  version.conf            固定上游版本、Tag、Commit 和打包修订号
  VERSIONS.md             版本历史
  README.md               软件说明
  <license files>         上游许可证文件（按上游实际情况保留或由固定源码纳入发布归档）
```

具体软件的构建方式、版本信息、标准运行时安装集、运行方法和限制，以对应软件目录中的 README、`version.conf` 和 `VERSIONS.md` 为准。

## Releases

正式产物统一发布到仓库的 `latest` Release，Release 标题固定为 `Latest`。

单一可执行程序只保留必要的稳定二进制资产；标准运行时安装集包含多个文件的软件使用一个完整保留目录结构和符号链接的稳定归档资产。版本更新后覆盖 `latest` 中对应资产。所有软件的当前版本、资产名和 SHA-256 统一记录在：

```text
software_versions.json
```

统一清单按 `software_key` 保存各软件元数据：

```json
{
  "<software_key>": {
    "asset": "<asset_name>",
    "sha256": "<SHA-256>",
    "version": "<package_version>"
  }
}
```

因此仓库增加软件时，不需要在根 README 继续追加软件表格、版本号、命令或 Release 资产列表。

## 版本管理

每个软件独立维护：

1. `version.conf`：当前构建固定使用的上游版本、Tag、Commit，以及仓库自己的打包修订号。
2. `VERSIONS.md`：按版本追加历史记录，不覆盖旧记录。
3. 构建输出中的 `dist/version.txt`：由构建脚本生成，仅供发布流程更新 `software_versions.json`。

上游版本不变但构建方式、编译参数或 Release 资产结构发生实质变化时，递增对应软件的打包修订号。

## 本地构建

不同软件的依赖和构建方式以各自目录的 README 为准。最终静态二进制仍可能受内核、CPU 架构以及软件自身功能要求限制。
