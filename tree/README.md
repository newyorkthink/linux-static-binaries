# tree

上游主发布站：[Old Man Programmer - tree](https://oldmanprogrammer.net/source.php?dir=projects/tree)，官方备份 Git 仓库：[Old-Man-Programmer/tree](https://github.com/Old-Man-Programmer/tree)。

`tree` 是 Steve Baker 维护的目录树命令行工具，用缩进树形结构显示目录内容。

## 版本获取规则

上游 README 将 `oldmanprogrammer.net` 标为主发布站，并将 GitHub / GitLab 标为备份 Git 站点。本仓库每次正式 Build：

1. 从官方 GitHub 备份仓库动态读取纯数字稳定 Tag（例如 `2.3.2`），排除带字母后缀的 beta 等非稳定 Tag，并按版本号选择当前最新稳定版本。
2. 使用该版本号下载官方主发布站的 `tree-<版本>.tgz`，不使用第三方二进制或发行版 `.deb` 作为构建输入。
3. 动态解析同版本 Tag 对应的 Commit SHA，Checkout 后再次核对实际 Commit。
4. 对 Makefile 和全部实际参与 `tree` 编译的 C / 头文件逐一比较官方 tarball 与同版本 Git Tag；不一致时停止构建。
5. 动态版本只写入构建生成的 `dist/version.txt` 和 Release `software_versions.json`，不会写回仓库成为后续版本锁定值。

[`version.conf`](./version.conf) 只保存本仓库打包修订号。

## 构建方式

上游 [`INSTALL`](https://github.com/Old-Man-Programmer/tree/blob/master/INSTALL) 的标准 Linux 流程是使用上游 Makefile 执行 `make`，安装时再执行 `make install`；没有 Autoconf / CMake 等额外构建系统。本仓库保持这一构建方式和上游源文件列表，不修改 tree 源码，也不自行重写编译规则。

为了得到真正可跨常见 Linux 发行版使用的静态单文件，只在上游 Makefile 接口上覆盖两项构建变量：

- `CC=musl-gcc`：使用 musl 工具链编译。
- `LDFLAGS=-static -s`：将 libc 静态链接进最终 ELF，并剥离符号。

`tree` 的 Linux ACL / SELinux 显示功能直接使用 libc 提供的 xattr API，不需要额外链接 `libacl` 或 `libselinux`。构建完成后使用 `file` 与 `readelf` 检查：产物必须是 x86-64 静态 ELF，且不得包含 ELF interpreter 或动态 `NEEDED` 项。

## 标准安装集与单文件取舍

上游 `make install` 安装两个主要文件：

- `tree`：主程序，核心运行文件。
- `tree.1`：man page，仅用于本地帮助文档，不参与程序运行。

因此 Release 只发布主程序：

```text
tree
```

源码中的示例 / 文档数据不会作为运行时依赖打包。最终静态 ELF 不要求目标机器安装 Debian/Kali 的 `tree` 包或匹配的 glibc；仍要求目标系统是兼容的 x86-64 Linux，并受 Linux 内核和文件系统自身能力限制。

## 使用

在 Linux 终端执行：

```bash
# 显示当前目录的树形结构。
./tree
```

```bash
# 显示指定目录的树形结构。
./tree <目录>
```

程序按当前用户的文件系统权限读取目录；使用 `-l` 跟随符号链接时，可能遍历到原目录树之外的目标路径。

## License

上游代码声明按 GNU GPL v2 或更高版本授权。本仓库保留上游原始 [`LICENSE`](./LICENSE) 文件。
