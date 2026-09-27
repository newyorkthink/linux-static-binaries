# xclipglue 打包记录

| 打包修订 | 说明 |
| --- | --- |
| `r1` | 首个 x86-64 静态单文件构建；每次下载官网正式源码包，读取包内动态版本，核对官方 Git HEAD 的程序内容与 Commit，静态链接 libxcb、libXau、libXdmcp、C++ 运行库和 libc，仅发布 `xclipglue`。 |

目标应用 Version / Commit 不在仓库中持久化为锁定值；每次 Build 从官网正式源码包动态读取当前版本。构建方式或资产结构发生实质变化时递增 `PACKAGE_REVISION`。
