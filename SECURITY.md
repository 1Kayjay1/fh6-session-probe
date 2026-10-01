# Security and trust

This project is intentionally transparent.

## Inspect before running

There is no compiled application in this repository. The tester consists of readable PowerShell plus small CMD launchers.

You can inspect the source before executing it.

## Game integrity

The current probe is external to Forza Horizon 6.

It does not:

- inject code
- patch the game
- read or write FH6 process memory
- automate gameplay
- modify cars, credits, position, or game state

## Network capture

The probe uses Windows Packet Monitor for network **metadata**.

Raw packet-byte / packet-payload capture is intentionally not enabled. The probe uses Packet Monitor flag mask `0x00E`; Microsoft documents raw packet bytes under flag `0x010`, which is excluded.

The repository tests check that the expected metadata-only Packet Monitor flags remain present.

## Local FH6 text/config scan

The probe may search recently modified FH6-related `.log`, `.txt`, `.json`, `.xml`, `.ini`, and `.cfg` files for session-related keywords.

The scan is limited to likely FH6 locations, recent files, a small set of text-like extensions, and bounded file sizes/results. The probe no longer treats the entire `Documents\My Games` directory as a scan root; only Forza/Horizon-named child directories are considered there.

A known custom FH6 radio-mod path is explicitly ignored so it does not pollute the research output.

## Data handling

Nothing is uploaded automatically.

The user must manually choose to share the generated diagnostic ZIP.

The raw Packet Monitor ETL stays local and is excluded from the share ZIP.

The shareable process/socket CSVs are narrowed to FH6/Xbox/Gaming-related rows, and user-profile prefixes in shared process paths are redacted. However, `pktmon_metadata.txt` is NIC-level flow metadata and can still contain network endpoints from unrelated traffic. It does not contain packet payloads.

Diagnostic bundles can therefore contain process names, local/remote network addresses, ports, and FH6-related text/config excerpts. Testers should review a bundle before sharing it if they have privacy concerns.

Do not publish another person's diagnostic bundle without their permission.

## Automated checks

The repository includes Windows-based syntax, safety-invariant, and ZIP smoke tests in `tests/Run-Tests.ps1`.

GitHub Actions runs those checks on pushes and pull requests.

Passing tests reduce accidental breakage, but they cannot guarantee compatibility with every PC or future FH6 update.

## Reporting

If you notice the probe collecting information outside its stated scope, stop using it and open an issue with the exact behavior observed.
