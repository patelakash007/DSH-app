#!/usr/bin/env python3
"""Generate the runtime manifest for one reproducibly-built native engine."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lock", required=True, type=Path)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--abi", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    lock = json.loads(args.lock.read_text(encoding="utf-8"))
    required = ("repository", "revision", "engineVersion", "protocolVersion", "goVersion")
    missing = [key for key in required if not lock.get(key)]
    if missing:
        raise SystemExit(f"engine lock is missing: {', '.join(missing)}")
    revision = lock["revision"]
    if len(revision) != 40 or any(char not in "0123456789abcdef" for char in revision.lower()):
        raise SystemExit("engine revision must be a full 40-character Git commit")

    binary = args.binary.read_bytes()
    digest = hashlib.sha256(binary).hexdigest()
    manifest = {
        "runtimeVersion": f"native-{lock['engineVersion']}",
        "abi": args.abi,
        "rootfs": "",
        "rootfsBytes": 0,
        "rootfsSha256": "",
        "uncompressedBytes": 0,
        "dshVersion": f"{lock['engineVersion']}-native",
        "nodeVersion": "none",
        "launch": {"argv": [], "env": {}},
        "engine": {
            "repository": lock["repository"],
            "revision": revision,
            "sha256": digest,
            "bytes": len(binary),
            "protocolVersion": lock["protocolVersion"],
            "goVersion": lock["goVersion"],
            "sourceDirty": False,
            "capabilities": [
                "agent-tools-v1",
                "approvals-v1",
                "attachments-v1",
                "goals-v1",
                "background-jobs-v1",
                "message-feedback-v1",
                "reference-discovery-v1",
                "reference-snapshots-v1",
                "account-state-v1",
                "cot-translation-v1",
                "custom-providers-v1",
                "prompt-queue-v1",
                "schedules-v1",
                "session-export-v1",
                "subagents-v1",
                "user-questions-v1",
                "session-control-v1",
                "session-fork-v1",
                "settings-v1",
                "skills-v1",
                "terminal-shell-v1",
                "workspaces-v1",
                "workspace-files-v1",
                "workspace-watch-v1",
            ],
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"{args.abi} {digest} {len(binary)} {revision}")


if __name__ == "__main__":
    main()
