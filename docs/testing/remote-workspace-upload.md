# Remote Workspace File Upload Verification

Objective: Test staged file transfer and directory sync between mobile client and remote engine workspace.

## Test Scenarios
1. Upload single text and binary files (PDF, images, archives) up to 100 MiB; verify SHA-256 integrity check upon completion.
2. Staged directory sync: verify nested folder structures are preserved in workspace without corrupting permissions.
3. Network interruption during transfer: verify partial chunks are discarded and upload can resume cleanly.
