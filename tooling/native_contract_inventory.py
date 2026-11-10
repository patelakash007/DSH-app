#!/usr/bin/env python3
"""Generate/check the Flutter client to native Go contract inventory.

The extractor intentionally accepts only literal endpoints. A dynamically
constructed local endpoint must be added as a literal declaration before CI
will treat it as part of the supported contract.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
GO_ROOT_DEFAULT = ROOT.parent / "DSH-go-rewrite"
OUTPUT = ROOT / "docs" / "native-contract.json"
OVERRIDES = ROOT / "tooling" / "native_contract_overrides.json"

RPC_RE = re.compile(r"(?:\brpc|\.rpc)\.call\(\s*r?['\"]([^'\"]+/[^'\"]+)['\"]")
MUX_RE = re.compile(r"(?:\bmux|\.mux)\.open\(\s*r?['\"]([^'\"]+/[^'\"]+|\$events)['\"]")
RESILIENT_RE = re.compile(r"\b_resilient\(\s*r?['\"]([^'\"]+/[^'\"]+|\$events)['\"]")
ITEMS_RE = re.compile(r"\b_items\(\s*r?['\"]([^'\"]+/[^'\"]+|\$events)['\"]")
HTTP_RE = re.compile(r"r?['\"](/api/[^'\"?$ {}]+)['\"]")
CASE_RE = re.compile(r'^\s*case\s+(.+?):\s*$', re.MULTILINE)
QUOTED_RE = re.compile(r'"([^"]+)"')
SERVER_STREAM_RE = re.compile(r'endpoint\s*==\s*"([^"]+)"')
SERVER_ROUTE_RE = re.compile(r'HandleFunc\("([^"]+)"')


def dart_sources() -> list[Path]:
    roots = [ROOT / "packages" / "dsh_client" / "lib", ROOT / "app" / "lib"]
    return sorted(path for base in roots for path in base.rglob("*.dart"))


def references(pattern: re.Pattern[str], sources: list[Path]) -> dict[str, list[str]]:
    found: dict[str, set[str]] = {}
    for path in sources:
        text = path.read_text(encoding="utf-8", errors="ignore")
        for match in pattern.finditer(text):
            found.setdefault(match.group(1), set()).add(path.relative_to(ROOT).as_posix())
    return {key: sorted(value) for key, value in sorted(found.items())}


def server_methods(main: str) -> set[str]:
    start = main.index("func (s *Server) dispatchRPC")
    end = main.index("// Broadcast an event", start)
    methods: set[str] = set()
    for case in CASE_RE.finditer(main[start:end]):
        methods.update(value for value in QUOTED_RE.findall(case.group(1)) if "/" in value or value.startswith("$"))
    return methods


def classify(
    kind: str,
    client: dict[str, list[str]],
    implemented: set[str],
    overrides: dict[str, dict[str, str] | str],
) -> list[dict[str, object]]:
    statuses = overrides.get(kind, {})
    assert isinstance(statuses, dict)
    notes = overrides.get("notes", {})
    assert isinstance(notes, dict)
    unknown = set(statuses) - set(client)
    if unknown:
        raise SystemExit(f"{kind} overrides do not exist in the client: {sorted(unknown)}")
    rows: list[dict[str, object]] = []
    for endpoint, files in client.items():
        status = str(statuses.get(endpoint) or ("implemented" if endpoint in implemented else "in-progress"))
        if status not in {"implemented", "placeholder", "in-progress", "blocked"}:
            raise SystemExit(f"invalid status for {endpoint}: {status}")
        test: str | None = None
        if status == "implemented":
            if endpoint.startswith("workspaceFiles/"):
                test = "DSH-go-rewrite/cmd/dsh-server/server_test.go#TestWorkspaceRPCConfinesAndReadsFiles"
            elif endpoint == "$events/result":
                test = "DSH-go-rewrite/cmd/dsh-server/server_test.go#TestNativeAgentToolApprovalAndHistory"
            else:
                test = "packages/dsh_client/test/native_go_contract_test.dart"
        rows.append(
            {
                "endpoint": endpoint,
                "status": status,
                "owner": "native-engine",
                "test": test,
                "clientReferences": files,
                "note": notes.get(endpoint),
            }
        )
    return rows


def build(go_root: Path) -> dict[str, object]:
    sources = dart_sources()
    rpc = references(RPC_RE, sources)
    mux = references(MUX_RE, sources)
    for pattern in (RESILIENT_RE, ITEMS_RE):
        for endpoint, files in references(pattern, sources).items():
            mux.setdefault(endpoint, [])
            mux[endpoint] = sorted(set(mux[endpoint]) | set(files))
    # DshMux owns this stream internally; it is not opened at each call site.
    mux.setdefault("$events", ["packages/dsh_client/lib/src/mux.dart"])
    mux = dict(sorted(mux.items()))

    # HTTP routes belong to the local client package. App-level /api/bot paths
    # target unrelated remote services and are not part of the engine contract.
    client_sources = [path for path in sources if "packages/dsh_client/lib" in path.as_posix()]
    http = references(HTTP_RE, client_sources)

    main_path = go_root / "cmd" / "dsh-server" / "main.go"
    if not main_path.is_file():
        raise SystemExit(f"Go server not found: {main_path}")
    main = main_path.read_text(encoding="utf-8")
    workspace = (go_root / "cmd" / "dsh-server" / "workspace_rpc.go").read_text(encoding="utf-8")
    implemented_rpc = server_methods(main)
    mux_start = main.index("func (s *Server) handleMux")
    mux_end = main.index("func (s *Server) handleSessionDeletionCapability", mux_start)
    implemented_streams = set(SERVER_STREAM_RE.findall(main[mux_start:mux_end]))
    implemented_routes = set(SERVER_ROUTE_RE.findall(main))
    # /api/{rpc} is a dispatcher prefix, not one concrete client route.
    implemented_routes.discard("/api/")
    overrides = json.loads(OVERRIDES.read_text(encoding="utf-8"))

    rows_rpc = classify("rpc", rpc, implemented_rpc, overrides)
    rows_mux = classify("mux", mux, implemented_streams, overrides)
    rows_http = classify("http", http, implemented_routes | set(SERVER_ROUTE_RE.findall(workspace)), overrides)
    counts: dict[str, dict[str, int]] = {}
    for kind, rows in (("rpc", rows_rpc), ("mux", rows_mux), ("http", rows_http)):
        values: dict[str, int] = {"total": len(rows)}
        for row in rows:
            status = str(row["status"])
            values[status] = values.get(status, 0) + 1
        counts[kind] = values
    return {
        "schemaVersion": 1,
        "description": "Literal local-engine contract used by the preserved Flutter/Dart client.",
        "counts": counts,
        "rpc": rows_rpc,
        "mux": rows_mux,
        "http": rows_http,
        "serverOnly": {
            "rpc": sorted(implemented_rpc - set(rpc)),
            "mux": sorted(implemented_streams - set(mux)),
            "http": sorted(implemented_routes - set(http)),
        },
    }


def encoded(document: dict[str, object]) -> str:
    return json.dumps(document, indent=2, ensure_ascii=False) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--go-root", type=Path, default=GO_ROOT_DEFAULT)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--update", action="store_true")
    mode.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = encoded(build(args.go_root.resolve()))
    if args.update:
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(rendered, encoding="utf-8")
        print(f"wrote {OUTPUT.relative_to(ROOT)}")
        return
    current = OUTPUT.read_text(encoding="utf-8") if OUTPUT.exists() else ""
    if current != rendered:
        sys.stdout.writelines(
            difflib.unified_diff(
                current.splitlines(keepends=True), rendered.splitlines(keepends=True),
                fromfile=str(OUTPUT.relative_to(ROOT)), tofile="generated native contract",
            )
        )
        raise SystemExit("native contract inventory is stale; run tooling/native_contract_inventory.py --update")
    document = json.loads(rendered)
    print(json.dumps(document["counts"], sort_keys=True))


if __name__ == "__main__":
    main()
