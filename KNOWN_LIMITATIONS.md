# Known limitations

This repository is a research probe, not the finished proximity voice client.

## What is already verified

- The probe launches on supported Windows environments when its dependencies are available.
- The repository's Windows CI parses the PowerShell scripts and runs offline smoke/safety checks.
- The probe can collect Windows networking/process diagnostic metadata and build a share ZIP.
- Raw packet-byte capture is intentionally disabled.

## What is not verified yet

The most important unknown is still whether **two different PCs in the same FH6 freeroam session expose a stable shared signal** that can be used for automatic session matching.

One-PC captures cannot answer that.

## A matching network endpoint would not automatically equal a session ID

If two same-session testers see the same remote endpoint, it could represent:

- a shared multiplayer relay
- a regional service endpoint
- a session-specific backend allocation
- another service used by multiple players

So a match would be a candidate signal, not final proof.

The next validation step would be repeating the test across different sessions and controlled state changes.

## Different ports do not automatically mean failure

Two clients may reach the same service/relay IP through different per-client ports. A useful fingerprint may therefore require more than an exact IP:port equality check.

## Completely different endpoints do not automatically kill the project

If the network path is allocated per client, the project can still investigate other externally observable signals or combine multiple weak signals.

## Diagnostic privacy

The share ZIP can contain networking/process diagnostic metadata and excerpts from recently modified Forza-related text/config/log files.

It does not contain packet payloads and nothing uploads automatically.

Testers should review the generated share bundle before sending it if they have privacy concerns.

## Finished voice networking is a separate problem

This probe only researches **session discovery**.

The eventual voice system still needs its own authenticated discovery/signaling design, encrypted audio transport, NAT traversal, relay fallback, abuse controls, and privacy model.
