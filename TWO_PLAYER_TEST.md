# Two-PC same-session test

This is the highest-value test for the current research question.

## Goal

Determine whether two independent FH6 PCs in the **same normal freeroam session** expose a stable shared network/session fingerprint.

The first test should be intentionally boring. Do not switch game modes, join/leave a convoy mid-capture, or fast-travel between activities. We want one clean baseline before adding more variables.

## Before starting

Both testers should:

1. Be on PC.
2. Launch FH6 normally.
3. Join the same normal freeroam session.
4. Confirm they can physically see each other's cars in-game.
5. If a convoy was used to get into the same session, leave the convoy first, confirm both cars are still visible, then wait about 20 seconds before starting the probe. The baseline is meant to measure ordinary freeroam, not convoy-specific traffic.
6. Download the same current revision of this repository.
7. Optionally run `PRE-FLIGHT CHECK.cmd`.
8. Open `README.html` or `README.md` if anything is unclear.
9. For the cleanest baseline, disable VPN/Tailscale/ZeroTier-style tunnels during the capture.
10. Do not use Discord voice, Xbox party voice, Steam voice, or another shared voice call during the capture. Shared voice traffic could create a false common endpoint.
11. Avoid large downloads or video streams while the 60-second capture is running.

## Capture procedure

Do these steps on **both PCs**:

1. Double-click `RUN FH6 SESSION TESTER.cmd`.
2. Approve the Windows Administrator prompt. This is needed for Windows Packet Monitor metadata collection.
3. Click **Detect Running**.
4. Confirm the UI says FH6 is detected/running.
5. If automatic detection fails, use **Choose Folder**, select the FH6 install folder, then make sure FH6 is running.
6. Click **Start capture**.
7. Stay together in the same freeroam session for **45–60 seconds**.
8. Select `ONLINE_FREEROAM_A`.
9. Click **Mark state** once.
10. Wait another 5–10 seconds.
11. Click **Stop + build bundle**.
12. Keep the generated `Capture_..._SHARE.zip`.

The two captures do not need to start on the exact same millisecond. They only need to overlap while both players remain in the same unchanged freeroam session.

## Send back

Send only the generated `Capture_..._SHARE.zip`.

Do **not** send the local raw `.etl` unless the maintainer specifically asks for a follow-up diagnostic and explains why it is needed.

## What counts as a useful result?

We will compare:

- high-volume public UDP endpoints
- exact remote IP + port matches
- same-IP / different-port patterns
- repeated endpoint clusters
- socket/process metadata around the `ONLINE_FREEROAM_A` marker
- any session-related identifiers independently present in both bundles

### Result A: exact endpoint match

If both machines repeatedly communicate with the same public endpoint during the shared freeroam window, that becomes a strong candidate signal.

It is **not automatically a session ID**. It could still be a shared relay or service endpoint, so it must be tested again across different sessions.

### Result B: same IP, different ports

This can still be useful. It may indicate the same relay/server allocation with per-client ports. We would then look for another correlated signal to make the fingerprint stable.

### Result C: completely different endpoints

That does not kill the project. It would suggest the relay path is per-client, so the next step would be looking for a different shared signal or a multi-signal fingerprint.

## Follow-up test only after the baseline

If the first same-freeroam test produces a promising signal, repeat with one controlled variable at a time:

1. Same freeroam session, second fresh capture.
2. Leave and reconnect to a different freeroam session.
3. Same session + same convoy.
4. Leave convoy while remaining in freeroam.
5. Online race.

Do not combine all of these into the first test. Clean baselines are easier to interpret.

## Important limitation

A green GitHub Actions run proves that the scripts parse and the repository's offline smoke/safety checks pass. It does not prove that FH6 exposes a shared multiplayer identifier.

That is exactly what this two-PC test is designed to determine.
