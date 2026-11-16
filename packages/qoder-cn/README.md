# qoder-cn

`qoder-cn` repackages the official Qoder CN Linux release (`.deb`) for
Arch Linux. Qoder CN is Alibaba's mainland-China build of the Qoder
agentic coding workbench ("Qoder 全新形态"); it is proprietary freeware
with no published source code.

## Install

With `paru`:

```bash
paru -S qoder-cn
```

With `yay`:

```bash
yay -S qoder-cn
```

Manual install from this repository:

```bash
cd packages/qoder-cn
makepkg -si
```

## Notes

- Source is the versioned official deb:
  `https://qoder-app.oss-cn-beijing.aliyuncs.com/qoder-app/releases/<version>/Qoder-CN-linux-amd64.deb`
  (the `latest` directory and the download page both point here; the deb
  control block reports versions such as `1:0.4.4`).
- The app is installed to `/opt/Qoder-CN` with a `/usr/bin/qoder-cn`
  launcher; the desktop entry, hicolor icons, and changelog come straight
  from the deb.
- `chrome-sandbox` keeps the setuid bit required by Electron sandboxed
  renderers.
- Upstream ships x86_64 and aarch64 Linux builds; both are packaged.
- The AUR package `qoder-cn-bin` (maintained separately) packages the same
  closed-source build; this package conflicts with it.
- The in-app updater cannot install updates on Arch; update through this
  package instead.
