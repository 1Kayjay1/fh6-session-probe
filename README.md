# FH6 Session Probe

An open-source Windows diagnostic for researching automatic session detection for a **Forza Horizon 6 proximity voice chat** project.

The long-term idea is simple: if two players are already in the same FH6 freeroam session and both have the app installed, the app should automatically recognize that and connect proximity voice chat without room codes.

## What this probe does

- observes Windows networking/process metadata while FH6 is running
- uses Windows Packet Monitor (`pktmon`) for flow metadata
- snapshots TCP/UDP ownership by process
- scans recently changed Forza text/config/log files for session-related clues
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

The entire tester is plain PowerShell source and can be opened in Notepad before running it.

## Why does it request Administrator permission?

Windows Packet Monitor requires elevated permission for this type of network-flow capture.

The script intentionally uses packet **metadata only** and does not enable raw packet-byte capture.

## Quick test

1. Launch FH6.
2. Join the same normal freeroam session as another tester.
3. Confirm you can actually see each other's cars.
4. Double-click `RUN FH6 SESSION TESTER.cmd`.
5. Click **Detect Running**.
6. Click **Start capture**.
7. Stay in the same freeroam session for about 45–60 seconds.
8. Select `ONLINE_FREEROAM_A` and click **Mark state**.
9. Click **Stop + build bundle**.
10. Send the generated `Capture_..._SHARE.zip` back to the project maintainer.

For deeper testing, the probe also includes markers for solo/offline, another freeroam session, convoy, online race, solo race, and Eliminator.

## Privacy

The probe does not automatically send anything anywhere.

Generated capture files may contain Windows networking/process diagnostic metadata, so they are ignored by Git and should not be committed to this repository.

## Current research question

We are trying to determine whether two players in the **same FH6 online session** expose a stable shared network/session fingerprint that can be detected externally.

If that works, the future proximity voice client can use the fingerprint only for player discovery while actual voice transport can use encrypted P2P networking where possible.

## Files

- `FH6_Session_Tester.ps1` - full source
- `RUN FH6 SESSION TESTER.cmd` - simple launcher
- `PUSH TO GITHUB.cmd` - creates/pushes this repo with GitHub CLI
- `SECURITY.md` - trust, privacy, and reporting notes

## Requirements

- Windows 10/11
- PowerShell 5.1+
- Forza Horizon 6 (PC)
- Administrator permission for Packet Monitor capture

## Status

Experimental research tool. Expect rough edges while session detection is being mapped.
