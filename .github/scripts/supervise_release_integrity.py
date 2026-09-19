#!/usr/bin/env python3
"""监督 latest Release 中 software_versions.json 与正式资产 digest 的一致性。"""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path

SHA256_RE = re.compile(r"[0-9a-fA-F]{64}")
SOFTWARE_KEY_RE = re.compile(r"[A-Za-z0-9._-]+")


def read_json(path: Path, label: str) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"无法读取有效的 {label}：{exc}") from exc


def write_output(name: str, value: str) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        raise SystemExit("缺少 GITHUB_OUTPUT。")
    with open(output, "a", encoding="utf-8") as fh:
        fh.write(f"{name}={value}\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--assets", type=Path, required=True)
    args = parser.parse_args()

    manifest = read_json(args.manifest, "software_versions.json")
    asset_pages = read_json(args.assets, "Release Assets 列表")

    if not isinstance(manifest, dict):
        raise SystemExit("software_versions.json 必须是 JSON 对象。")
    if not isinstance(asset_pages, list):
        raise SystemExit("Release Assets 列表格式无效。")

    if asset_pages and all(isinstance(page, list) for page in asset_pages):
        assets = [asset for page in asset_pages for asset in page]
    else:
        assets = asset_pages
    if not all(isinstance(asset, dict) for asset in assets):
        raise SystemExit("Release Assets 列表包含无效条目。")

    assets_by_name: dict[str, list[dict]] = {}
    for asset in assets:
        name = asset.get("name")
        if isinstance(name, str) and name:
            assets_by_name.setdefault(name, []).append(asset)

    mismatches: list[dict[str, str]] = []

    for software_key, entry in sorted(manifest.items()):
        reasons: list[str] = []
        asset_name = entry.get("asset") if isinstance(entry, dict) else None
        manifest_sha256 = entry.get("sha256") if isinstance(entry, dict) else None

        if not isinstance(software_key, str) or not SOFTWARE_KEY_RE.fullmatch(software_key):
            reasons.append("software_key 格式无效")
        if not isinstance(entry, dict):
            reasons.append("条目不是 JSON 对象")
        if not isinstance(asset_name, str) or not asset_name:
            reasons.append("asset 为空或类型无效")
        if not isinstance(manifest_sha256, str) or not SHA256_RE.fullmatch(manifest_sha256):
            reasons.append("sha256 不是 64 位十六进制值")

        matching_assets = assets_by_name.get(asset_name, []) if isinstance(asset_name, str) else []
        release_digest = ""
        release_sha256 = ""
        if len(matching_assets) != 1:
            reasons.append(f"同名 Release Asset 数量为 {len(matching_assets)}")
        else:
            digest = matching_assets[0].get("digest")
            release_digest = digest if isinstance(digest, str) else ""
            if not release_digest.startswith("sha256:") or not SHA256_RE.fullmatch(release_digest[7:]):
                reasons.append("Release Asset digest 不是有效的 sha256 digest")
            else:
                release_sha256 = release_digest[7:].lower()

        if (
            isinstance(manifest_sha256, str)
            and SHA256_RE.fullmatch(manifest_sha256)
            and release_sha256
            and manifest_sha256.lower() != release_sha256
        ):
            reasons.append("software_versions.json sha256 与 Release Asset digest 不一致")

        if reasons:
            mismatches.append(
                {
                    "software_key": software_key if isinstance(software_key, str) else "",
                    "asset": asset_name if isinstance(asset_name, str) else "",
                    "reason": "；".join(reasons),
                    "manifest_sha256": manifest_sha256 if isinstance(manifest_sha256, str) else "",
                    "release_digest": release_digest,
                }
            )

    keys = [row["software_key"] for row in mismatches if SOFTWARE_KEY_RE.fullmatch(row["software_key"])]
    write_output("has_mismatches", "true" if mismatches else "false")
    write_output("mismatch_count", str(len(mismatches)))
    write_output("mismatch_keys", json.dumps(keys, ensure_ascii=False, separators=(",", ":")))

    if not mismatches:
        print(f"software_versions.json 的 {len(manifest)} 个条目全部与 Release Asset digest 一致。")
    else:
        print("发现以下 Release 完整性异常：")
        for row in mismatches:
            print(
                f"- {row['software_key'] or '<无效键>'} / {row['asset'] or '<无资产>'}: "
                f"{row['reason']}；清单={row['manifest_sha256'] or '<无>'}；"
                f"Release={row['release_digest'] or '<无>'}"
            )

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write("## Release 完整性监督\n\n")
            if not mismatches:
                fh.write(f"`software_versions.json` 的 {len(manifest)} 个条目全部一致。\n")
            else:
                fh.write("| software_key | asset | 原因 |\n")
                fh.write("|---|---|---|\n")
                for row in mismatches:
                    fh.write(
                        f"| `{row['software_key'] or '<无效键>'}` | "
                        f"`{row['asset'] or '<无资产>'}` | {row['reason']} |\n"
                    )


if __name__ == "__main__":
    main()
