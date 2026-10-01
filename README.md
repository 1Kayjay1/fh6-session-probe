# FH6 Session Probe 🙂

[![Windows tests](https://github.com/1Kayjay1/fh6-session-probe/actions/workflows/tests.yml/badge.svg)](https://github.com/1Kayjay1/fh6-session-probe/actions/workflows/tests.yml)

An open-source Windows diagnostic for researching automatic session detection for a **Forza Horizon 6 proximity voice chat** project.

The long-term idea is simple: if two players are already in the same FH6 freeroam session and both have the future app installed, the app should recognize that automatically and connect proximity voice without room codes.

> Want the easier visual walkthrough? Download/open **[README.html](./README.html)** in a browser.

## Current research question

Can two PC players in the **same FH6 online session** independently expose the same stable session/network fingerprint?

That is the only thing this probe is trying to establish right now. Voice chat itself is not implemented in this repository yet.

## What this probe does

- observes Windows networking/process metadata while FH6 is running
- uses Windows Packet Monitor (`pktmon`) for flow metadata
- snapshots TCP/UDP ownership by process, with shareable CSV rows limited to FH6/Xbox/Gaming-related processes
- scans recently changed FH6 text/config/log files for session-related clues
- creates a shareable diagnostic ZIP after a test

## What it does **not** do

- no DLL injection
- no game-memory reading
- no FH6 file modification
- no gameplay automation
- no teleporting / credits / car modification
- no packet payload capture
- no installer
- no hidden compiled EXE
- no automatic uploads

The tester is plain PowerShell source and can be opened in Notepad before it is run.

## Recommended 1-minute test

1. Launch FH6.
2. Join the same normal freeroam session as the other tester.
3. Confirm you can actually see each other's cars.
4. Double-click **`RUN FH6 SESSION TESTER.cmd`**.
5. Click **Detect Running**.
6. Click **Start capture**.
7. Stay in the same session for about **45–60 seconds**.
8. Select **`ONLINE_FREEROAM_A`** and click **Mark state**.
9. Click **Stop + build bundle**.
10. Send back only the generated **`Capture_..._SHARE.zip`**.

For the first comparison, staying in one unchanged freeroam session is more useful than jumping through multiple game modes.

## Why "Detect Running" first?

The most reliable way to associate network/process metadata with FH6 is to identify the **live FH6 process** while the game is actually running.

The tester re-checks that process immediately before capture starts so it does not accidentally use a stale PID after FH6 has been restarted.

## If automatic detection does not work

Click **Choose Folder** and select the actual FH6 install folder.

The tester searches the selected folder for the FH6 executable and uses that path to help find FH6-related files.

This fallback exists because some Windows Store / Game Pass installations can protect or obscure executable paths from normal process inspection.

**FH6 still has to be running before a capture can begin.**

## Why does it request Administrator permission?

Windows Packet Monitor requires elevation for this type of network-flow capture.

The probe starts Packet Monitor with metadata flags only. The raw-packet-byte flag is intentionally not enabled, so the probe does not capture packet contents. Microsoft documents `0x004` as source/destination information, `0x008` as selected packet metadata, and `0x010` as raw packet data; this probe uses `0x00E`, which excludes `0x010`.

Microsoft reference: https://learn.microsoft.com/windows-server/administration/windows-commands/pktmon-start

## What is in the share ZIP?

Depending on what Windows exposes during the test:

- `capture_manifest.json` — probe/runtime details such as version, timestamps, Windows/PowerShell version, and whether Packet Monitor text was produced
- `probe.log` — timestamped test timeline and FH6/Xbox/Gaming-related socket summaries
- `socket_snapshots.csv` — FH6/Xbox/Gaming-related TCP/UDP ownership snapshots at state marks
- `process_snapshots.csv` — FH6/Xbox/Gaming-related process snapshots; user-profile paths are redacted
- `forza_text_hits.txt` — session-related keyword matches from recently modified Forza-related text/config/log files
- `pktmon_metadata.txt` — Packet Monitor flow metadata
- `README_CAPTURE.txt` — explanation of the capture files

The raw `.etl` Packet Monitor file stays in the local capture folder and is **not** included in the share ZIP.

`pktmon_metadata.txt` is still NIC-level network-flow metadata, so it can include network endpoints unrelated to FH6 even though it contains no packet payloads. Review the ZIP before sharing if that matters to you.

Nothing is uploaded automatically.

## Before a real test

Run:

- **`PRE-FLIGHT CHECK.cmd`** — checks the local Windows environment, Packet Monitor, required PowerShell commands, FH6 process state, and capture-folder write access.
- **`RUN SELF TESTS.cmd`** — parses the PowerShell files, checks capture-safety invariants, verifies the manual-folder fallback, and smoke-tests ZIP creation.

See **[TESTING.md](./TESTING.md)** for details. For the actual two-PC experiment, use **[TWO_PLAYER_TEST.md](./TWO_PLAYER_TEST.md)** and the short **[TESTER_CHECKLIST.txt](./TESTER_CHECKLIST.txt)**.

## Automatic tests

A Windows GitHub Actions workflow runs on every push and pull request.

A green test badge means the scripts parse correctly and the repository's offline smoke/safety checks passed.

It does **not** prove that a shared FH6 session fingerprint exists. That requires two real FH6 clients in the same live session.

## Files

- `FH6_Session_Tester.ps1` — full tester source
- `RUN FH6 SESSION TESTER.cmd` — normal launcher
- `PRE-FLIGHT CHECK.cmd` — one-click environment check
- `RUN SELF TESTS.cmd` — one-click repository test suite
- `README.html` — visual setup/trust guide
- `TESTING.md` — testing methodology
- `TWO_PLAYER_TEST.md` — exact two-PC same-session test protocol
- `TESTER_CHECKLIST.txt` — short checklist to keep both testers in sync
- `KNOWN_LIMITATIONS.md` — what a matching or non-matching result would actually mean
- `SECURITY.md` — trust, privacy, and reporting notes

## Requirements

- Windows 10/11
- Windows PowerShell 5.1+
- Forza Horizon 6 (PC)
- Administrator permission for Packet Monitor capture

## Status

Experimental research tool. Expect the session-detection logic to evolve as more same-session captures are compared.

A matching endpoint is a **candidate signal**, not automatic proof of a session ID. See [KNOWN_LIMITATIONS.md](./KNOWN_LIMITATIONS.md) before interpreting results.
