# zcode-desktop-bin

`zcode-desktop-bin` repackages the official macOS ZCode desktop release for
Arch Linux.

## Install

With `paru`:

```bash
paru -S zcode-desktop-bin
```

With `yay`:

```bash
yay -S zcode-desktop-bin
```

Manual install from this repository:

```bash
cd packages/zcode-desktop-bin
makepkg -si
```

## Notes

- The package installs the `zcode` launcher.
- The official macOS package uses Electron 41, so this package runs it with
  Arch Linux's `electron41`.
- The macOS `node-pty` native module is rebuilt for Linux during packaging.
- The bundled macOS `rg` binary is replaced with Arch Linux's `ripgrep`.
- The bundled ZCode agent is launched through Electron's Node runtime.
