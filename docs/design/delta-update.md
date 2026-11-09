# Binary APK Delta Update Architecture

Mechanism for generating and applying compact binary delta patches between APK releases.

## Mechanism
1. **Patch Generation**: Computes byte-level difference using `bsdiff` algorithm combined with `zstd` compression (`tooling/apk_delta.py`).
2. **Patch Delivery**: Server publishes delta patch metadata alongside full APK releases.
3. **Application**: On-device native binary reconstitutes the target APK from the installed base APK and delta patch.
4. **Integrity Verification**: Verifies SHA-256 checksum and Android V2/V3 APK signing certificate before prompting user installation.
