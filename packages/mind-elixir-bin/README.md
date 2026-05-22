# mind-elixir-bin

`mind-elixir-bin` packages the prebuilt Linux release of
[Mind Elixir](https://app.mind-elixir.com/) for Arch Linux.

Mind Elixir is a lightweight, privacy-focused desktop mind mapping tool.

## Install

With `paru`:

```bash
paru -S mind-elixir-bin
```

With `yay`:

```bash
yay -S mind-elixir-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/mind-elixir-bin.git
cd mind-elixir-bin
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
mind-elixir
```

## Notes

- The package repackages the upstream amd64 `.deb` release for Arch Linux.
- Runtime dependencies currently match the upstream Debian package metadata.
- The launcher defaults `WEBKIT_DISABLE_DMABUF_RENDERER=1` to avoid WebKitGTK
  blank-window rendering failures on affected GPU/driver setups.
