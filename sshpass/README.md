# sshpass

构建脚本：[`build_sshpass.sh`](./build_sshpass.sh)。

上游项目：[sshpass](https://sourceforge.net/projects/sshpass/)，[官方 Git 仓库](https://sourceforge.net/p/sshpass/code-git/ci/main/tree/)。

sshpass 通过伪终端向 SSH 客户端提供密码，适合必须使用密码认证的非交互式 SSH 操作。程序本身不包含 SSH 客户端。

## 版本获取规则

sshpass 上游通过 `v<数字版本>` Git Tag 发布稳定版本。每次正式 Build 都从官方 Git 仓库动态选择最新稳定 Tag，排除非数字版本和预发布标签，再解析对应的真实 Commit。源码 Checkout 后通过公共入口核对 Commit，版本号不固定写入仓库。

构建成功后，实际版本保存至 `dist/version.txt`，并由共享 Action 更新 Release 的 `software_versions.json`。

## 构建方式

官方 Git 源码包含 `bootstrap`、`configure.ac` 和 `Makefile.am`。构建脚本依次执行 `./bootstrap`、`./configure` 和 `make`，保留上游构建流程，使用 `musl-gcc`、`-static` 与 `-s` 生成静态单文件。构建所需的 Autoconf、Automake 由软件专属构建依赖安装，公共脚本负责 Git 来源及 Commit 核对、最终静态 ELF、版本和 SHA-256 检查。

构建直接在 GitHub Actions 的 Ubuntu Runner 上执行，不使用 Docker 或其他封装层。

## 标准安装集与单文件取舍

上游 `make install` 安装 `sshpass` 主程序和 `sshpass.1` man page。man page 仅用于文档，不参与程序运行，因此 Release 只发布主程序：

```text
sshpass
```

sshpass 需要调用目标系统中已有的 `ssh`、`scp` 等 SSH 客户端；静态链接只消除了 sshpass 自身对动态链接库的依赖，不会把 SSH 客户端一同打包。

## 使用

在 Linux 终端执行，按实际环境替换密码文件、用户名和主机地址：

```bash
# 从密码文件读取密码并启动 SSH 客户端。
./sshpass -f <密码文件> ssh <用户名>@<主机地址>
```

密码文件应限制读取权限。不建议使用 `-p` 在命令行直接传递密码，因为参数可能被其他进程读取或写入历史记录。sshpass 不会绕过 SSH 主机密钥校验；连接前仍需确认目标主机身份。

## License

sshpass 按 GNU GPLv2 授权；许可证原文见 [`COPYING`](./COPYING)，具体适用条款以官方源码的授权声明为准。
