# Releasing

The public repository is source-first. Do not attach the default output of `./build_app.sh` to a GitHub release: it is ad-hoc signed and not notarized.

## Version and validation

1. Update `VERSION` and the changelog, then commit the change.
2. Run `swift test` and `./build_app.sh` from the release commit.
3. Verify the app with `codesign --verify --deep --strict`, its Info.plist with `plutil -lint`, and the DMG with `hdiutil verify`.
4. Confirm the app behaves on a clean Mac and test the supported Mac architectures. Check model claims against `Docs/CAPABILITY_MATRIX.md`.

## Public macOS download

A downloadable release additionally needs an Apple Developer ID Application certificate, hardened-runtime signing with a secure timestamp, Apple notarization, and a stapled ticket on the final DMG. Verify the signed app and stapled DMG on a separate Mac before uploading. Keep signing keys and notary credentials outside Git; use protected secrets if this is later automated.

Tag the tested commit as `v` followed by the exact `VERSION` value. Create the GitHub release from that tag, attach the signed and notarized DMG, record its SHA-256 checksum, and summarize supported models, validation, changes, and known limits in the release notes. Do not mark an experimental model as fully supported without physical-device validation.
