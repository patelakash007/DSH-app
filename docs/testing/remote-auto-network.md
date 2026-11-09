# Remote Host Auto-Network Discovery Verification

Objective: Automatically detect local network topology changes and reconnect to active remote DSH engine hosts.

## Automated Checks
```bash
(cd packages/dsh_remote && dart analyze && dart test)
(cd packages/dsh_client && dart analyze && dart test)
```

## Physical Device Verification Steps
1. Switch from Wi-Fi to cellular data while connected to a local server; verify graceful offline indicator and transition to polling mode.
2. Reconnect to same Wi-Fi SSID; verify mDNS service discovery re-identifies the target engine host within 5 seconds without manual re-entry of IP address.
3. Test dual-interface situations (Wi-Fi + VPN / Tailscale); verify user-configured host endpoint priority is respected.
