# 归档静态二进制软件

在 Linux 终端进入本仓库根目录，将 `<软件 key>` 替换为 `.github/static-binaries.json` 中对应的活动软件 key。

```bash
# 预览目录移动、构建登记和归档索引的变更。
python3 scripts/archive/archive_static_binary.py '<软件 key>'
```

核对预览并取得本次操作授权后执行：

```bash
# 在本地移动软件目录，并更新活动清单、构建工作流和归档记录。
python3 scripts/archive/archive_static_binary.py '<软件 key>' --apply
```

本地归档把软件完整目录移动到 `archive/<软件 key>/`，从正式构建清单、手动下拉和 Push 路径中移除该软件，并在归档清单中保留原登记。执行前，相关 Git 路径须干净。含有指向上级目录相对链接的软件 README 须先核对归档后的链接。当前活动清单须至少保留一个软件。

完成后核对 Git 差异，按仓库规则提交和推送到 `main`。归档提交命中正式构建工作流的既有 Push 条件，会构建归档后仍然处于活动清单中的软件。归档只处理源码登记，已发布的附件和版本条目作为历史保留。

恢复方式见[归档索引](../../archive/README.md)。
