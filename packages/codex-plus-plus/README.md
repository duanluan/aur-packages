# codex-plus-plus

`codex-plus-plus` packages [Codex++](https://github.com/BigPizzaV3/CodexPlusPlus)
as an automatic injection bridge for the Arch Linux `openai-codex-desktop`
package.

## Install

With `paru`:

```bash
paru -S codex-plus-plus
```

With `yay`:

```bash
yay -S codex-plus-plus
```

Manual install from AUR:

```bash
git clone https://aur.archlinux.org/codex-plus-plus.git
cd codex-plus-plus
makepkg -si
```

## Usage

The package enables the Codex++ injection automatically after install.

Check status:

```bash
codex-plus-plus status
```

Disable or re-enable injection:

```bash
sudo codex-plus-plus disable
sudo codex-plus-plus enable
```

## Notes

- The package depends on `openai-codex-desktop`.
- It keeps a backup of the upstream `/usr/bin/codex-desktop` launcher.
- An `alpm` hook reapplies the injection after `openai-codex-desktop` upgrades.
- `codexplusplus` is kept as a compatibility alias.
