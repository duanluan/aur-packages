# codepilot-bin

`codepilot-bin` repackages the official Linux `.deb` releases of
[CodePilot](https://github.com/op7418/CodePilot) for Arch Linux on x86_64 and
aarch64.

CodePilot is a multi-model AI agent desktop client with support for multiple
AI providers, MCP servers, reusable skills, scheduled tasks, and remote chat
bridges.

## Install

With `paru`:

```bash
paru -S codepilot-bin
```

With `yay`:

```bash
yay -S codepilot-bin
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/codepilot-bin.git
cd codepilot-bin
makepkg -si
```

## Usage

Start CodePilot from the application menu, or run:

```bash
codepilot
```

## Notes

- This package uses the upstream `.deb` release and does not require FUSE.
- It conflicts with `codepilot-appimage` because both packages provide the
  `codepilot` launcher and desktop entry.
- Application state and configuration are stored in the current user's home
  directory.
- CodePilot is licensed under the Business Source License 1.1. Review the
  upstream license before commercial or organizational use.
