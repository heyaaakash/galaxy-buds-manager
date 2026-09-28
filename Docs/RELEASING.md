# Releasing

The public DMGs are ad-hoc signed and **not notarized**. They work only when a user chooses to allow the app through macOS Privacy & Security. Make that limitation prominent in every release note. Do not claim Apple has verified the app.

## Prepare a version

1. Update `VERSION`, `CHANGELOG.md`, and `Docs/RELEASE_NOTES.md`; commit the changes to `main`.
2. Check that the release notes accurately name the supported models and [hardware validation](CAPABILITY_MATRIX.md).
3. Confirm the `Verify` workflow passes on both macOS runners. Test installation and actual earbud behavior on a clean Mac when one is available.
4. Create and push a tag `v` followed by the exact value in `VERSION`. The `Release` workflow tests and builds on Apple Silicon and Intel runners, verifies each package, and publishes both DMGs plus `SHA256SUMS.txt` after both jobs pass.
5. Confirm the GitHub release contains both architecture-specific DMGs and the checksum file. Download them and compare their SHA-256 hashes with `SHA256SUMS.txt`. Confirm the release workflow succeeded.

Do not reuse a release tag for different source. If packaging fails, fix the issue in a new commit and create a new version and tag.

## When Developer ID becomes available

Replace ad-hoc signing with hardened-runtime Developer ID Application signing and a secure timestamp. Notarize the app or DMG and staple the ticket to the distributed package. Verify the result on a separate Mac before publishing. Keep the certificate and notary credentials outside Git, using protected secrets if signing is automated. Update the README, release notes, and workflow together.
