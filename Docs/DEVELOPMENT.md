# Development Guide

This guide covers building, testing, and syncing the repository across multiple development devices.

## Multi-device workflow & private assets

This repository includes a private companion Git submodule at `PrivateAssets/` pointing to [`heyaaakash/galaxy-buds-manager-private-assets`](https://github.com/heyaaakash/galaxy-buds-manager-private-assets). It stores unreleased assets, private design files, and versioned build snapshots across your devices while keeping the main repository open-source.

### 1. Setting up on a new Mac

When cloning the repository on a new development machine:

```bash
git clone --recurse-submodules https://github.com/heyaaakash/galaxy-buds-manager.git
cd galaxy-buds-manager
```

If you already cloned without `--recurse-submodules`, initialize and pull the submodule:

```bash
git submodule update --init --recursive
```

### 2. Automatic submodule syncing

To have Git automatically pull updates in `PrivateAssets/` whenever you `git pull`, and automatically push submodule commits whenever you `git push` from the root repository, configure:

```bash
# Set locally for this repo (or pass --global to configure for all repos on this Mac)
git config submodule.recurse true
git config push.recurseSubmodules on-demand
```

### 3. Storing private files and builds

Store versioned deliverables or sensitive assets inside `PrivateAssets/`:

```bash
# Example: saving a versioned build
mkdir -p PrivateAssets/$(cat VERSION)
cp dist/GalaxyBuds2-Pro-Manager.dmg PrivateAssets/$(cat VERSION)/

# Commit in PrivateAssets
cd PrivateAssets
git add .
git commit -m "Archive $(cat ../VERSION) release build"
cd ..

# Commit and push from parent repo
git add PrivateAssets
git commit -m "Update PrivateAssets for $(cat VERSION)"
git push origin main
```

---

## Local builds and testing

* **Run protocol regression tests:**
  ```bash
  swift test
  ```
* **Build and launch debug app:**
  ```bash
  ./run.sh
  ```
* **Build release app and DMG:**
  ```bash
  ./build_app.sh
  ```
  Produces `dist/Galaxy Buds2 Pro Manager.app` and `dist/GalaxyBuds2-Pro-Manager.dmg`.

