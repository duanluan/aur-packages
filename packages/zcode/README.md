# zcode

`zcode` repackages the official Linux ZCode desktop release for
Arch Linux.

## Install

With `paru`:

```bash
paru -S zcode
```

With `yay`:

```bash
yay -S zcode
```

Manual install from this repository:

```bash
cd packages/zcode
makepkg -si
```

## Notes

- The package installs the official Linux x64 `.deb` build under `/opt/ZCode`.
- The package installs the `zcode` launcher.
- The official Linux package bundles its own Electron runtime.
- The install hook keeps `chrome-sandbox` permissions aligned with local user namespace support.
