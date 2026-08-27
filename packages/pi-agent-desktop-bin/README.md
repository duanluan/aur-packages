# pi-agent-desktop-bin

`pi-agent-desktop-bin` repackages the official Linux `.deb` release of
[Pi Agent Desktop](https://github.com/abcwyc/pi-agent-desktop) for Arch Linux.

Pi Agent Desktop is a Tauri-based desktop UI for browsing sessions and working
with the local pi coding agent.

## Install

With `paru`:

```bash
paru -S pi-agent-desktop-bin
```

With `yay`:

```bash
yay -S pi-agent-desktop-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/pi-agent-desktop-bin.git
cd pi-agent-desktop-bin
makepkg -si
```

## Launch

Start Pi Agent from the application menu, or run:

```bash
pi-agent-desktop
```

## Notes

- The package uses the official prebuilt x86_64 `.deb` release.
- The package removes the bundled Node.js runtime and uses system Node.js
  22.19.0 or newer. The `npm` package supplies `npx` for skill management.
- The launcher disables WebKit's DMABUF renderer by default to avoid a blank
  window on affected Linux graphics stacks. Set
  `WEBKIT_DISABLE_DMABUF_RENDERER=0` to override it.
- Application data and configuration are managed by Pi Agent Desktop in the
  current user's home directory.
