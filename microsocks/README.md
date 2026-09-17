# MicroSocks

上游项目：[rofl0r/microsocks](https://github.com/rofl0r/microsocks)

MicroSocks 是一个轻量级多线程 SOCKS5 服务端。上游支持 IPv4、IPv6、DNS 和 SOCKS5 用户名 / 密码认证；当前不支持 UDP。

## 当前版本

```text
打包版本：1.0.5-r3
上游版本：1.0.5
上游 Tag：v1.0.5
上游 Commit：98421a21c4adc4c77c0cf3a5d650cc28ad3e0107
```

版本固定值统一维护在 [`version.conf`](./version.conf)，历史记录见 [`VERSIONS.md`](./VERSIONS.md)。

## 构建方式

当前版本直接从固定的上游 Git Tag 构建：

1. Checkout `version.conf` 指定的 Tag。
2. 核对实际 Commit 与固定 Commit 完全一致。
3. 使用 `musl-gcc` 和 `-static` 编译。
4. 使用 `file` / `readelf` 静态检查最终 ELF，确认不存在 ELF interpreter 和动态 `NEEDED` 项。
5. 生成构建期 SHA-256 和版本文本；共享 GitHub Action 上传二进制后，将版本和 SHA-256 合并到统一 `software_versions.json`。

MicroSocks 上游本身明确适合使用 musl 静态链接，因此这里不使用 AppImage、RunImage 或其他动态库打包层。

## Release 资产

MicroSocks 自己只占一个二进制资产：

```text
microsocks
```

所有软件共用：

```text
software_versions.json
```

其中 `microsocks` 条目记录当前打包版本、固定资产名和最终二进制 SHA-256。构建目录中的 `dist/version.txt` 与 `*.sha256` 仅作为构建和发布过程的内部元数据，不再单独上传到 Release。

## 运行

```bash
./microsocks -i <监听地址> -p <监听端口>
```

需要认证时按上游参数增加用户名和密码选项。监听到非回环地址会允许其他网络设备连接，应根据实际网络边界配置认证和防火墙，不要把未认证的 SOCKS 服务直接暴露到不受信任网络。

## 功能限制

当前上游 SOCKS5 实现支持 TCP，不支持 UDP ASSOCIATE。因此依赖 SOCKS5 UDP 转发的程序不能仅靠 MicroSocks 完成 UDP 代理。

## License

MicroSocks 上游使用 MIT License。仓库保留上游 [`COPYING`](./COPYING)；许可证正文不再重复拆成独立 Release 资产。
