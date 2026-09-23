# mimo-desktop

`mimo-desktop` repackages the official Xiaomi MiMo Linux desktop
release for Arch Linux.

## Install

With `paru`:

```bash
paru -S mimo-desktop
```

With `yay`:

```bash
yay -S mimo-desktop
```

Manual install from this repository:

```bash
cd packages/mimo-desktop
makepkg -si
```

## Notes

- The package installs the official Linux x64 `.deb` build under
  `/opt/Xiaomi MiMo`.
- The package installs the `mimo-desktop` launcher and registers the
  `xiaomi-mimo://` URL scheme handler.
- The upstream download page only links Windows and macOS builds; the
  Linux `.deb` and its checksums come from the vendor CDN manifest
  (`manifest.json`), which also drives `update.sh`.
- The official package bundles its own Electron, Node.js, and Python
  runtimes (about 940 MB installed).
