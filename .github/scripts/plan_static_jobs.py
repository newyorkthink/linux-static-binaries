#!/usr/bin/env python3
"""根据 .github/static-binaries.json 决定本次静态二进制构建 Job。"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


CATALOG_PATH = Path(".github/static-binaries.json")
SHARED_BUILD_PATHS = {
    ".github/scripts/plan_static_jobs.py",
    ".github/static-binaries.json",
    ".github/workflows/build.yml",
}


def normalize_search(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.lower())


def git_ok(args: list[str]) -> bool:
    return subprocess.call(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0


def git_out(args: list[str]) -> str:
    return subprocess.check_output(args, text=True)


def load_catalog() -> list[dict]:
    data = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    packages = data.get("packages")
    if not isinstance(packages, list) or not packages:
        raise SystemExit("静态二进制构建清单为空或格式无效。")

    required = {
        "key",
        "name",
        "dir",
        "software_key",
        "build_script",
        "artifact_path",
        "checksum_path",
        "version_file",
        "license_file",
        "asset_name",
        "legacy_asset_names",
        "apt_packages",
        "timeout_minutes",
    }
    seen_keys: set[str] = set()
    seen_dirs: set[str] = set()
    for package in packages:
        if not isinstance(package, dict) or required - package.keys():
            raise SystemExit("静态二进制构建清单存在缺少必需字段的条目。")
        key = package["key"]
        directory = package["dir"]
        if not isinstance(key, str) or not re.fullmatch(r"[a-z0-9._-]+", key):
            raise SystemExit(f"构建 key 无效：{key!r}")
        if package["software_key"] != key or directory != key:
            raise SystemExit(f"{key} 的 key、software_key 和目录名必须一致。")
        if key in seen_keys or directory in seen_dirs:
            raise SystemExit(f"构建清单存在重复条目：{key}")
        if not isinstance(package["timeout_minutes"], int) or package["timeout_minutes"] <= 0:
            raise SystemExit(f"{key} 的 timeout_minutes 无效。")
        seen_keys.add(key)
        seen_dirs.add(directory)
    return packages


def resolve_search(catalog: list[dict], query_raw: str) -> str:
    query = normalize_search(query_raw)
    if not query:
        raise SystemExit(f"模糊输入没有有效字符：{query_raw}")
    if query == "all":
        return "all"

    exact: list[dict] = []
    fuzzy: list[dict] = []
    for package in catalog:
        candidates = (
            package["key"],
            package["name"],
            package["dir"],
            package["build_script"],
        )
        normalized = [normalize_search(value) for value in candidates]
        if query in normalized:
            exact.append(package)
        elif any(query in value for value in normalized):
            fuzzy.append(package)

    matches = exact or fuzzy
    if len(matches) == 1:
        print(f"模糊输入已匹配：{query_raw} -> {matches[0]['key']}", flush=True)
        return matches[0]["key"]
    if not matches:
        raise SystemExit(f"未找到匹配软件：{query_raw}")

    print(f"模糊输入匹配到多个软件：{query_raw}", file=sys.stderr)
    for package in matches:
        print(f"  - {package['key']}", file=sys.stderr)
    raise SystemExit(1)


def changed_files(before_sha: str, after_sha: str) -> list[str]:
    missing_before = (
        not before_sha
        or re.fullmatch(r"0+", before_sha) is not None
        or not git_ok(["git", "cat-file", "-e", f"{before_sha}^{{commit}}"])
    )
    if missing_before:
        output = git_out(["git", "show", "--pretty=", "--name-only", after_sha])
    else:
        output = git_out(["git", "diff", "--name-only", before_sha, after_sha])
    return [line for line in output.splitlines() if line]


def main() -> None:
    catalog = load_catalog()
    by_key = {package["key"]: package for package in catalog}
    dir_key = {package["dir"]: package["key"] for package in catalog}

    event_name = os.environ["EVENT_NAME"]
    selected_target = os.environ.get("SELECTED_TARGET") or "all"
    target_search = os.environ.get("TARGET_SEARCH") or ""
    release_integrity_repair = (
        os.environ.get("RELEASE_INTEGRITY_REPAIR") or ""
    ).lower() == "true"
    before_sha = os.environ.get("BEFORE_SHA") or ""
    after_sha = os.environ["AFTER_SHA"]
    selected: set[str] = set()

    if release_integrity_repair and event_name != "workflow_dispatch":
        raise SystemExit("Release 完整性自愈只能通过 workflow_dispatch 运行。")

    if event_name == "workflow_dispatch":
        if not release_integrity_repair and target_search.strip():
            selected_target = resolve_search(catalog, target_search)
        if selected_target == "all":
            if release_integrity_repair:
                raise SystemExit("Release 完整性自愈禁止扩大为全量构建。")
            selected.update(by_key)
        elif selected_target in by_key:
            selected.add(selected_target)
        else:
            selected_target = resolve_search(catalog, selected_target)
            if selected_target == "all":
                selected.update(by_key)
            else:
                selected.add(selected_target)
    elif event_name == "push":
        files = changed_files(before_sha, after_sha)
        if any(
            path in SHARED_BUILD_PATHS
            or path.startswith(".github/actions/build-static/")
            for path in files
        ):
            selected.update(by_key)
        else:
            for path in files:
                if path.lower().endswith(".md"):
                    continue
                top = path.split("/", 1)[0]
                if top in dir_key:
                    selected.add(dir_key[top])
    else:
        raise SystemExit(f"不支持的触发事件：{event_name}")

    selected_packages = [package for package in catalog if package["key"] in selected]
    matrix = {"include": selected_packages}
    output_path = Path(os.environ["GITHUB_OUTPUT"])
    with output_path.open("a", encoding="utf-8") as output:
        output.write(f"should_build={'true' if selected_packages else 'false'}\n")
        output.write(f"package_count={len(selected_packages)}\n")
        output.write("matrix<<MATRIX_EOF\n")
        output.write(json.dumps(matrix, separators=(",", ":")) + "\n")
        output.write("MATRIX_EOF\n")


if __name__ == "__main__":
    main()
