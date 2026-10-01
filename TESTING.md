# Testing

This repository has two different test layers.

## 1. Local preflight

Run **PRE-FLIGHT CHECK.cmd** before a real FH6 capture.

It checks:

- Windows and PowerShell availability
- WinForms support
- TCP/UDP networking cmdlets
- `Compress-Archive`
- Windows Packet Monitor (`pktmon`)
- Administrator state
- whether FH6 is currently running
- whether the local capture folder is writable

Warnings do not necessarily block the tester. For example, not being elevated is expected before the main tester requests Administrator permission.

## 2. Repository self-tests

Run **RUN SELF TESTS.cmd**.

These tests do not need FH6 installed. They:

- parse the PowerShell files with the Windows PowerShell parser
- verify the metadata-only Packet Monitor flags
- check that raw-packet capture is not enabled
- check that the manual FH6-folder fallback exists
- check that the capture re-validates the live FH6 process
- check for common process-injection API names
- smoke-test ZIP creation
- verify the visual HTML guide contains the required trust and fallback instructions

## Automatic GitHub tests

The same repository tests run automatically on a Windows GitHub Actions runner for every push and pull request.

A green workflow means the scripts parse correctly and the offline smoke/safety checks passed. It does **not** prove that FH6 multiplayer session discovery works on every PC. That part still requires real FH6 captures from testers.

## Real-world test order

For the current research question, the most useful test is:

1. Two PC players join the same normal FH6 freeroam session.
2. Both confirm they can see each other.
3. Both start a capture.
4. Wait 45–60 seconds without changing sessions.
5. Mark `ONLINE_FREEROAM_A`.
6. Stop and create the share bundle.
7. Compare the two bundles.

The key question is whether both clients expose a stable shared session/network fingerprint.\n\nFor the exact step-by-step protocol and interpretation guidance, see [TWO_PLAYER_TEST.md](./TWO_PLAYER_TEST.md). The short operator version is [TESTER_CHECKLIST.txt](./TESTER_CHECKLIST.txt).
