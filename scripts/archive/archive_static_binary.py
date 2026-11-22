#!/usr/bin/env python3
"""预览或执行单个静态二进制项目的本地归档。"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ACTIVE_CATALOG = Path(".github/static-binaries.json")
BUILD_WORKFLOW = Path(".github/workflows/build.yml")
ARCHIVE_DIR = Path("archive")
ARCHIVE_CATALOG = ARCHIVE_DIR / "static-binaries.json"
ARCHIVE_INDEX = ARCHIVE_DIR / "README.md"
INDEX_BEGIN = "<!-- 已归档软件开始 -->"
INDEX_END = "<!-- 已归档软件结束 -->"
KEY_PATTERN = re.compile(r"[a-z0-9][a-z0-9._-]*")
PARENT_LINK = re.compile(r"""(?:\]\(\s*|\]:\s*|\b(?:href|src)\s*=\s*["'])<?(?:\./)*\.\./""", re.I)


# 读取仓库已有的常规文件，拒绝通过符号链接访问目标。
def read_file(path: Path) -> str:
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"缺少常规文件：{path}")
    return path.read_text(encoding="utf-8")


# 校验活动清单和归档清单的本仓库标识，保留完整软件登记。
def read_catalog(content: str, path: Path) -> tuple[dict, dict[str, dict]]:
    catalog = json.loads(content)
    packages = catalog.get("packages") if isinstance(catalog, dict) else None
    if not isinstance(packages, list):
        raise ValueError(f"清单缺少 packages 列表：{path}")

    entries: dict[str, dict] = {}
    for entry in packages:
        key = entry.get("key") if isinstance(entry, dict) else None
        if (
            not isinstance(key, str)
            or not KEY_PATTERN.fullmatch(key)
            or entry.get("dir") != key
            or entry.get("software_key") != key
            or entry.get("asset_name") != key
            or entry.get("build_script") != f"{key}/build_{key}.sh"
            or key in entries
        ):
            raise ValueError(f"软件登记不匹配或重复：{path}，key={key!r}")
        entries[key] = entry
    if list(entries) != sorted(entries):
        raise ValueError(f"软件登记未按 key 排序：{path}")
    return catalog, entries


# 从构建下拉选项和 Push 路径中移除该软件，保留其余行和执行顺序。
def update_workflow(content: str, key: str) -> str:
    entries = (
        f"          - {key}\n",
        f"      - '{key}/**'\n",
        f"      - '!{key}/**/*.md'\n",
    )
    lines = content.splitlines(keepends=True)
    for entry in entries:
        if lines.count(entry) != 1:
            raise ValueError(f"正式构建工作流缺少唯一登记：{entry.strip()}")
    return "".join(line for line in lines if line not in entries)


# 只更新归档说明中的目录列表。
def update_index(content: str, entries: dict[str, dict]) -> str:
    if content.count(INDEX_BEGIN) != 1 or content.count(INDEX_END) != 1:
        raise ValueError("归档索引必须包含唯一的列表起始与结束标记。")
    before, remainder = content.split(INDEX_BEGIN)
    _, end, after = remainder.partition(INDEX_END)
    if not end:
        raise ValueError("归档索引列表标记顺序无效。")
    index = "\n".join(f"- [{key}](./{key}/README.md)" for key in sorted(entries))
    return f"{before}{INDEX_BEGIN}\n{index}\n{INDEX_END}{after}"


# 同目录暂存文本，保留权限并原子替换单个文件。
def replace_file(path: Path, content: str) -> None:
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=path.parent, prefix=f".{path.name}.", delete=False
    ) as stream:
        temp = Path(stream.name)
        try:
            stream.write(content)
            stream.close()
            temp.chmod(path.stat().st_mode & 0o777)
            temp.replace(path)
        finally:
            temp.unlink(missing_ok=True)


# 仅在明确执行时要求所涉及的文件和软件目录均处于干净的 Git 状态。
def apply_archive(
    source: Path, destination: Path, originals: dict[Path, str], updates: dict[Path, str]
) -> None:
    paths = [str(source), str(destination), *(str(path) for path in originals)]
    status = subprocess.check_output(
        [
            "git", "--no-optional-locks", "status", "--porcelain",
            "--untracked-files=all", "--ignored=matching", "--", *paths,
        ],
        text=True,
    )
    if status:
        raise ValueError("归档涉及的路径包含未提交、未跟踪或忽略的内容，请先核对：\n" + status)
    tracked = subprocess.check_output(
        ["git", "ls-files", "--", str(source / f"build_{source.name}.sh"), str(source / "README.md")],
        text=True,
    ).splitlines()
    if len(tracked) != 2:
        raise ValueError(f"正式脚本和说明文档必须已经由 Git 跟踪：{source}")
    if any(read_file(path) != original for path, original in originals.items()):
        raise ValueError("检查期间归档登记发生变化，请重新预览。")
    if destination.exists() or destination.is_symlink():
        raise ValueError(f"归档目录已经存在：{destination}")

    # 先移动软件目录，写入失败时恢复已经修改的文件和原目录。
    touched: list[Path] = []
    source.rename(destination)
    try:
        for path, content in updates.items():
            replace_file(path, content)
            touched.append(path)
    except (OSError, KeyboardInterrupt):
        for path in reversed(touched):
            replace_file(path, originals[path])
        destination.rename(source)
        raise


# 先完整规划目录与登记变更，默认只输出预览。
def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("key", help="活动构建清单中的软件 key")
    parser.add_argument("--apply", action="store_true", help="执行本次已确认的本地归档变更")
    args = parser.parse_args()
    if not KEY_PATTERN.fullmatch(args.key):
        parser.error("软件 key 格式无效。")

    root = Path.cwd()
    if Path(__file__).resolve().parents[2] != root or not (root / ".git").exists():
        parser.error("请在包含本脚本的 Git 仓库根目录运行。")

    key = args.key
    source = Path(key)
    destination = ARCHIVE_DIR / key
    if ARCHIVE_DIR.is_symlink() or Path(".github").is_symlink():
        raise ValueError("归档和工作流目录必须位于当前仓库内。")
    if Path(".github/workflows").is_symlink():
        raise ValueError("工作流目录必须是当前仓库中的常规目录。")
    if source.is_symlink() or not source.is_dir() or destination.is_symlink() or destination.exists():
        raise ValueError(f"软件目录不存在、类型无效或归档目录已存在：{key}")

    originals = {
        path: read_file(path) for path in (ACTIVE_CATALOG, BUILD_WORKFLOW, ARCHIVE_CATALOG, ARCHIVE_INDEX)
    }
    active, active_entries = read_catalog(originals[ACTIVE_CATALOG], ACTIVE_CATALOG)
    archived, archived_entries = read_catalog(originals[ARCHIVE_CATALOG], ARCHIVE_CATALOG)
    if active_entries.keys() & archived_entries.keys():
        raise ValueError("活动清单与归档清单存在重复软件。")
    if key not in active_entries:
        raise ValueError(f"活动清单中找不到软件：{key}")
    if len(active_entries) == 1:
        raise ValueError("当前构建清单必须至少保留一个活动软件。")

    selected = active_entries.pop(key)
    for path in (Path(selected["build_script"]), source / "README.md"):
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"缺少软件构建脚本或说明文档：{path}")

    # 含外部相对链接的说明移动后需要调整，交由维护者先处理。
    if PARENT_LINK.search(read_file(source / "README.md")):
        raise ValueError(f"{source / 'README.md'} 含有指向上级目录的相对链接，移动后需重新核对。")

    archived_entries[key] = selected
    active["packages"] = list(active_entries.values())
    archived["packages"] = [archived_entries[name] for name in sorted(archived_entries)]
    updates = {
        ACTIVE_CATALOG: json.dumps(active, ensure_ascii=False, indent=2) + "\n",
        BUILD_WORKFLOW: update_workflow(originals[BUILD_WORKFLOW], key),
        ARCHIVE_CATALOG: json.dumps(archived, ensure_ascii=False, indent=2) + "\n",
        ARCHIVE_INDEX: update_index(originals[ARCHIVE_INDEX], archived_entries),
    }

    print(f"目录移动：{source}/ → {destination}/", flush=True)
    for path in updates:
        print(f"更新文件：{path}", flush=True)
    if args.apply:
        apply_archive(source, destination, originals, updates)
        print("本地归档完成，请核对 Git 差异。")
    else:
        print("预览完成。使用 --apply 执行已确认的本地变更。")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"归档失败：{exc}", file=sys.stderr)
        raise SystemExit(1) from exc
