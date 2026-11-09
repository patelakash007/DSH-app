---
# dsh-go:managed — the dsh-go app keeps this skill up to date; delete this line to keep your own edits.
name: dsh-go-support
description: Troubleshooting and diagnostics analysis for the DSH native mobile app. Reads diagnostic snapshots ($DSH_HOME/dsh-app/diagnostics.md) to isolate issues, verify symptoms, and generate sanitised bug reports.
whenToUse: The user reports issues with lag, heating, battery drain, connectivity, crashes, or phone control failures, or requests assistance filing a bug report.
---

# DSH Troubleshooting & Support

Always obtain concrete diagnostic evidence before drawing conclusions. The app writes diagnostic snapshots locally—inspect them before asking questions.

## 1. Inspect Diagnostics

Read local snapshots using available file reading tools:
- `$DSH_HOME/dsh-app/diagnostics.md` (automatic snapshot)
- `$DSH_HOME/dsh-app/diagnostics-manual.md` (user-generated report via Settings -> Diagnostics -> "Share with AI")

Snapshots contain client versions, device hardware info, runtime status, connection state, and recent error logs with redactions.

## 2. Common Symptom Trees

### UI Stutter / Frame Drops
- Check `performance` (thermal throttling level) and `runtime status` (on-device vs remote).
- Heavy on-device operations (e.g. large file indexing) share device CPU with Flutter UI.
- Test in **Settings -> Performance -> Lightweight Mode** (disables blur, heavy animations, and desktop pets).
- Adjust **Settings -> Performance -> Refresh Rate** to System or Auto on high-refresh screens.

### Heating / Battery Drain
- Active background engines, floating overlay controllers, and desktop pets consume battery.
- Stop on-device engine when idle via **Settings -> Engine -> Stop**, or switch to a remote server host.
- Streaming responses with deep reasoning naturally incur CPU workload.

### Connectivity Failures / Reconnecting
- Verify both devices are logged into the same account and the host bridge is running (`/remote status`).
- Check firewall and network connectivity between phone and host.

## 3. Formatting an Issue Report

Generate a clean sanitized bug report:
1. **Device & OS**: Model, Android version, app build number.
2. **Runtime Engine**: On-device native vs remote host.
3. **Steps to Reproduce**: Minimal sequence of operations leading to failure.
4. **Observed vs Expected**: Clear distinction between actual behavior and expectations.
5. **Relevant Diagnostics**: Scrubbed error stack traces.
