# Linux Static Binaries

用于从上游源码构建可移植、低依赖、可直接下载使用的 Linux 静态单文件二进制。

> [!IMPORTANT]
> AI coding agents 在读取、修改或提交本仓库前，必须先完整阅读 [AGENTS.md](./AGENTS.md)。

## 仓库说明

- 每个软件使用独立目录维护构建脚本、打包修订记录和说明文档。
- 目标应用本身禁止锁定 Version / Tag / Commit；每次正式 Build 必须从官方上游动态解析当前最新稳定版本 / Tag，并在本次构建内解析和核对对应 Commit。
- 构建环境或依赖项如果确有必要可以单独固定版本，但不得借此固定目标应用本身。
- 对适合静态链接的软件优先生成真正的静态 ELF，不为了“单文件”额外套不必要的运行时包装层。
- 新增或更新软件时仍会核查上游标准安装目标和附加运行时文件，但默认只发布主程序单文件；man page、locale、文档和可选数据增强文件不会触发压缩打包。
- Release 采用固定 `latest` Tag 和稳定资产名，便于脚本长期引用。
- 默认资产名直接使用软件可执行名；不追加版本号、架构或平台尾缀，也不默认发布 `.tar.xz` / `.zip` 等压缩包。
- 构建产物不提交进 Git 仓库，由 GitHub Actions 生成并发布到 Releases。

## 目录结构

每个软件独立维护，根 README 不维护具体软件清单，避免软件数量增加后重复维护大量条目。

```text
.github/
  actions/build-static/                 共享静态构建、发布和版本清单更新 Action
  static-binaries.json                  软件构建参数清单
  scripts/plan_static_jobs.py           手动选择、模糊匹配和 Push 变更规划
  scripts/supervise_release_integrity.py Release 完整性检查逻辑
  workflows/build.yml                   正式构建 Workflow
  workflows/supervise-release-integrity.yml  Release 完整性监督与单次自愈
  workflows/cleanup-actions-runs.yml    七天前已完成 Actions 记录自动清理
<software>/
  build.sh                软件构建脚本；动态解析最新稳定上游版本
  version.conf            仅保存打包修订号或必要的构建环境 / 依赖固定值，不得锁目标应用版本
  VERSIONS.md             本仓库打包方式历史
  README.md               软件说明
  <license files>         上游许可证文件（按软件实际情况保存在对应软件目录中）
```

具体软件的构建方式、动态版本解析方式、上游附加文件用途、单文件取舍、运行方法和限制，以对应软件目录中的 README、构建脚本和 `VERSIONS.md` 为准。

## Releases

正式产物统一发布到仓库的 `latest` Release，Release 标题固定为 `Latest`。

默认每个软件只保留一个可直接下载使用的稳定单文件资产。上游附带的 man page、locale、文档和非核心数据文件不单独发布，也不因为这些内容自动改成压缩包；若核心功能确实无法脱离多文件运行，则先说明并由用户决定例外方案。版本更新后覆盖 `latest` 中对应资产。所有软件的当前版本、资产名和 SHA-256 统一记录在：

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

版本清单写入采用短期互斥锁：每个 Build 先独立完成构建、Release 资产上传及资产 digest 校验，取得锁后通过唯一 Release Asset ID 读取当前 `software_versions.json`，只合并自己的条目，再以固定资产名覆盖上传并重新按唯一 Asset ID 校验 digest、下载内容和当前条目。锁只覆盖版本清单读改写临界区，不串行软件构建。

### 构建选择与并发解耦

`.github/workflows/build.yml` 先由规划 Job 读取 `.github/static-binaries.json`，再通过 matrix 为每个选中软件创建独立构建 Job。各软件并发编译，某个软件失败不会取消其他软件；只有共享 `software_versions.json` 的读改写阶段使用短时间互斥锁。

手动触发时可从下拉列表选择单个软件或 `all`，也可在模糊输入框填写软件名称；模糊输入优先于下拉选择。`all` 固定在下拉列表首项，其余软件按小写命令名的字母顺序排列；matrix Job 直接使用小写命令资产名显示。输入会在 key、目录名、命令资产名和构建脚本路径中匹配，匹配不到或同时匹配多个软件时直接报错，不会猜测目标。Push 触发时只构建实际发生非文档变更的软件；共享 Action、规划脚本、构建清单或正式 Workflow 改动时构建全部软件。

### Release 完整性监督与单次自愈

`.github/workflows/supervise-release-integrity.yml` 会在实际运行过软件构建的 **Build Static Binaries** 完成后检查 `latest` Release。监督读取唯一的 `software_versions.json`，逐项比较清单中的 `sha256` 与对应 Release Asset 的 GitHub SHA-256 digest。

全部一致时不修改 Release，也不触发构建。发现单个异常且 `software_key` 能安全映射到同名软件目录和 `workflow_dispatch.target` 时，只通过本仓库正式 `build.yml` 触发一次对应软件自愈构建；自愈完成后再次监督，仍异常则停止并报错，不继续循环。监督 Workflow 本身不写版本清单。

手动触发的 Build 首次失败时，监督只重新运行失败 Job 一次；Push 触发的失败不自动重跑。

因此仓库增加软件时，不需要在根 README 继续追加软件表格、版本号、命令或 Release 资产列表。

### Actions 运行记录清理

`.github/workflows/cleanup-actions-runs.yml` 每天自动删除七天前已经结束的 Actions 运行记录及其日志，也支持在 Actions 页面手动触发。清理不处理运行中或排队中的任务，不修改 Release、二进制资产、标签或提交。

## 版本管理

每个软件按以下方式管理版本：

1. `build.sh`：每次 Build 从官方上游动态解析当前最新稳定 Version / Tag，并在当次构建内解析和核对对应 Commit。
2. `version.conf`：若存在，只保存本仓库打包修订号或确有必要固定的构建环境 / 依赖项；禁止保存目标应用 Version / Tag / Commit。
3. `VERSIONS.md`：记录本仓库打包方式和资产结构变化，不作为目标应用版本锁定来源。
4. `dist/version.txt`：构建时根据动态上游版本生成，仅供发布流程更新 `software_versions.json`，不提交仓库。

上游发布新稳定版本后无需提交“改版本号”才能跟随；下一次正式 Build 会重新动态解析。构建方式、编译参数或 Release 资产结构发生实质变化时，再递增对应软件的打包修订号。

## 本地构建

不同软件的依赖和构建方式以各自目录的 README 为准。最终静态二进制仍可能受内核、CPU 架构以及软件自身功能要求限制。
