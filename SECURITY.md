# Security and trust

This project is intentionally transparent.

## Inspect before running

There is no compiled application in this repository. The tester consists of:

- a PowerShell script
- a small CMD launcher

Both can be opened in any text editor before execution.

## Game integrity

The current probe is external to Forza Horizon 6. It does not inject code, patch the game, read process memory, or alter gameplay.

## Network capture

The probe uses Windows Packet Monitor for network **metadata**. Raw packet-byte/payload capture is intentionally not enabled.

## Data handling

Nothing is uploaded automatically.

A user must manually choose to share the generated diagnostic bundle.

Do not publish other people's diagnostic bundles without their permission.

## Reporting

If you notice the probe collecting information outside its stated scope, stop using it and open an issue with the exact behavior observed.
