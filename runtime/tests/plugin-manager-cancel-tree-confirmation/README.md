# Process Group Cancellation Verification

Test harness verifying process group tree cancellation and signal propagation for package runtimes.

## Commands
Run local process tree test:
`python3 run.py`

Verifies graceful SIGTERM followed by SIGKILL cleanup for spawned worker subprocesses.
