# Linux Static Binaries

用于从上游源码构建可移植、低依赖、可直接下载使用的 Linux 静态单文件二进制。

> [!IMPORTANT]
> AI coding agents 在读取、修改或提交本仓库前，必须先完整阅读 [AGENTS.md](./AGENTS.md)。

## 下载产物

[Latest Release](https://github.com/newyorkthink/linux-static-binaries/releases/tag/latest) 提供各软件的静态单文件二进制。资产名称保持稳定，实际版本及 SHA-256 统一记录在 `software_versions.json` 中。

## 手动构建

在 [Build Static Binaries](https://github.com/newyorkthink/linux-static-binaries/actions/workflows/build.yml) 中，可选择单个软件或 `all`，也可输入软件名称进行模糊匹配。构建时动态获取上游最新稳定版本，发布到 `latest` Release。

## 文档导航

- [文档索引](./docs/README.md)：按主题查找构建、发布和维护说明。
- [构建与发布说明](./docs/build-and-release.md)：目录结构、动态版本、并发构建、Release、自愈与 Actions 清理。
- [构建公共注释标准](./docs/build-comments.md)：固定注释、分区标题与软件专属处理规则。
- [公共工具说明](./common/README.md)：源码获取、下载、校验及其他共享入口。
- 各软件的构建参数、运行方法和限制详见对应软件目录的 `README.md`。
