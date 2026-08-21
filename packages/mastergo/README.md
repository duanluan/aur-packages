# mastergo

`mastergo` repackages the official macOS MasterGo desktop release
for Arch Linux.

## Install

With `paru`:

```bash
paru -S mastergo
```

With `yay`:

```bash
yay -S mastergo
```

Manual install from this repository:

```bash
cd packages/mastergo
makepkg -si
```

## Notes

- The package installs the `mastergo` launcher.
- The official macOS package uses Electron 31, so this package runs it with
  Arch Linux's `electron31`.
- The packaged app uses MasterGo's macOS Apple chip DMG as the resource source,
  matching the approach used by `zcode`.
- MasterGo's Linux application-level update check is disabled; update this AUR
  package when upstream publishes a new desktop version.
- The bundled macOS `mgmcp` helper is not installed because it cannot run on
  Linux.
