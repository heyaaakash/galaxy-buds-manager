# Repository instructions

- Preserve the existing Galaxy Buds2 Pro behavior when adding support for other models. Use model-specific protocol handling; do not send SM-R510 commands to other Buds.
- Classify macOS Bluetooth connection events from cached device information. Ignore unrelated devices. Never deliberately request a Bluetooth connection to a disconnected device. Open the Buds settings channel only after macOS reports that device connected, and check the system connection again before SDP and RFCOMM calls.
- Build release deliverables with `./build_app.sh`. Both `dist/Galaxy Buds2 Pro Manager.app` and `dist/GalaxyBuds2-Pro-Manager.dmg` must be produced and verified before reporting a release build complete.
- Treat `.build/` as disposable compiler output and temporary packaging space. Do not leave the release app, DMG, or other important deliverables there. Keep user-facing build artifacts in `dist/`.
- `./run.sh` builds and launches a disposable debug app from `.build/`; it must not overwrite the release app in `dist/`.
- Use `swift test` for protocol regressions. If the default macOS SDK or module cache fails, select an installed compatible SDK and place the module cache under `/private/tmp`.
- Verify release builds with `codesign --verify --deep --strict` on the app, `plutil -lint` on its Info.plist, and `hdiutil verify` on the DMG. If sandboxed `iconutil` rejects a valid generated icon set, rerun the packaging script with the needed macOS tool access.
