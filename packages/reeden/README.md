# reeden

`reeden` repackages official Linux `.deb` release of
[Reeden](https://reeden.app/cn/download) for Arch Linux.

Reeden is a modern cross-platform local ebook reader with EPUB, MOBI, PDF, and
TXT support.

## Install

With `paru`:

```bash
paru -S reeden
```

With `yay`:

```bash
yay -S reeden
```

Manual install from this repository:

```bash
cd packages/reeden
makepkg -si
```

## Launch

Start it from your application menu, or run:

```bash
reeden
```

## Notes

- package repackages upstream x86_64 `.deb` from the official download page.
- package installs `reeden` launcher.
