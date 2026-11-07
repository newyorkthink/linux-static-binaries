# xclipglue

构建脚本：[`build_xclipglue.sh`](./build_xclipglue.sh)。

上游项目：[Simon Tatham 的 xclipglue](https://www.chiark.greenend.org.uk/~sgtatham/utils/)，[官方 Git 仓库](https://git.tartarus.org/simon/xclipglue.git)。

xclipglue 在两个 X11 display 之间双向同步所选的 X selection；默认同步 `PRIMARY` 和 `CLIPBOARD`。不支持 Wayland 原生剪贴板。

## 版本获取规则

上游没有稳定 Git Tag。官网公布的 `xclipglue.tar.gz` 是正式发布源码包，其 `xclipglue.cpp` 和 man page 内包含本次发布版本。每次正式 Build 下载当前官网源码包，从源码读取版本并核对 man page；同时动态解析官方 Git `HEAD` 对应 Commit、Checkout 并核对实际 Commit。正式源码包的程序内容除官网注入的版本字符串以外，必须与本次官方 Git HEAD 相同，否则停止构建，避免将不匹配的源码发布出去。

当前版本直接来自本次实际使用的官方上游源码，静态构建成功后保存至 `dist/version.txt`，不再使用独立版本配置文件。

## 构建方式

上游 `make progs` 只编译 C++ 主程序，依赖 XCB。正式构建在 GitHub-hosted Ubuntu runner 上调用 Docker，使用 Alpine Linux 3.24 的 musl C++ 工具链，以及 Alpine 提供的静态 XCB、Xau、Xdmcp 和相关依赖库；不混用 Ubuntu 上基于 glibc 的 XCB 库。保持上游 `make progs`、`-O2 -static -s` 和原有源码版本校验流程。构建后仍由公共入口通过 `file` 和 `readelf` 检查 ELF interpreter 与动态 `NEEDED` 项，并生成版本及 SHA-256。此方式避免静态 glibc `getaddrinfo` 的 NSS 兼容性警告，保留 X11 的 Unix socket 和 TCP 连接能力；远程连接仍取决于实际网络、名称解析和 X11 认证配置。本地执行构建脚本也需要 Docker。

上游默认 `make install` 还安装 `xclipglue.1` man page，仅用于文档；`make progs` 不需要 `halibut`，主程序无需 man page 即可运行。因此 Release 只发布 `xclipglue` 单文件。虽然链接静态，运行时仍需可访问的 X11 display、相应认证和 X server；远程模式需要用户自行提供远程启动命令。

## Release 资产

```text
xclipglue
```

所有软件共用 `software_versions.json`，其中 `xclipglue` 条目记录本次动态版本、资产名和 SHA-256。

## 使用

在 Linux 终端执行，用第二个 X11 display 名称替换 `<目标显示>`：

```bash
# 将当前 DISPLAY 与目标 X11 display 的选区双向同步。
./xclipglue <目标显示>
```

初次启动时，当前 display 的选区会覆盖目标 display 的同名选区。跨主机时可使用上游 `-remote` / `-stdio` 模式，但远程命令和两端 X11 认证由用户配置；剪贴板数据可能包含敏感内容，只连接信任的 display。

## License

上游在 [`xclipglue.cpp`](https://git.tartarus.org/simon/xclipglue.git) 中以 `--licence` 输出完整 MIT 许可证文本。本仓库保留该原文于 [`LICENSE`](./LICENSE)。
