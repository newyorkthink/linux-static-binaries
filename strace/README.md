# strace

上游项目：[strace/strace](https://github.com/strace/strace)。

`strace` 是 Linux 系统调用跟踪工具，用来看一个进程打开了哪些文件、调用了哪些系统调用。

## 版本获取规则

strace 以官方 Git Tag `v<数字版本>` 发布稳定源码。本仓库每次 Build：

1. 从官方仓库动态读取 `v<数字版本>` Tag，只接受纯数字稳定版本，排除 rc、beta 等非稳定标签，并按版本号选择当前最新稳定版本。
2. Checkout 该 Tag，并核对实际 Commit SHA。
3. 动态版本只写入构建生成的 `dist/version.txt` 和 Release `software_versions.json`，不会写回仓库成为后续版本锁定值。

[`version.conf`](./version.conf) 只保存本仓库打包修订号。

## 构建方式

上游构建流程是 `./bootstrap`、`./configure`、`make`。本仓库保持这一流程，不修改 strace 源码。

为了得到可跨常见 Linux 发行版使用的静态单文件，只增加这些构建参数：

- `CC=musl-gcc`，`CFLAGS` 带 `-static`，`LDFLAGS=-static`：把 libc 静态链接进最终 ELF。
- 从 `linux-libc-dev` 复制 `linux/`、`asm-generic/` 和当前架构 `asm/` 到独立目录，只把这个目录加进头文件搜索路径，不把宿主 glibc 头目录混进去。
- `--enable-mpers=no`：不编译 32 位 personality。`musl-gcc` 没有 `-m32`。
- `--enable-stacktrace=no`：不链接 libdw 或 libunwind。因此没有 `strace -k` 的调用栈展开。

构建完成后使用 `file` 与 `readelf` 检查：产物必须是 x86-64 静态 ELF，且不得包含 ELF interpreter 或动态 `NEEDED` 项。

## 单文件取舍

上游还会安装 `strace-log-merge` 和 man page。`strace-log-merge` 是 shell 脚本，不是静态 ELF，跟踪本身不需要它。Release 只发布：

```text
strace
```

## 使用

```bash
./strace -f -o /tmp/trace.txt -e trace=openat <程序>
```

跟踪其他用户的进程通常需要 root。不要给不可信用户开放跟踪权限，因为输出里可能有路径、参数和文件内容。

## License

上游 `strace` 按 GNU LGPL-2.1-or-later 授权。本仓库保留上游原始 [`COPYING`](./COPYING) 文件。
