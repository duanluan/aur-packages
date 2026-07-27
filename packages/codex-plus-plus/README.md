# codex-plus-plus

`codex-plus-plus` packages [Codex++](https://github.com/BigPizzaV3/CodexPlusPlus)
as a manual injection bridge for the Arch Linux `openai-codex-desktop`
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

The package does not take over `openai-codex-desktop` automatically.

Check status:

```bash
codex-plus-plus status
```

Launch the injected app without changing the upstream launcher:

```bash
codex-plus-plus run
```

The package also installs `OpenAI Codex (Codex++)` in the application menu.

Enable or disable injection:

```bash
sudo codex-plus-plus enable
sudo codex-plus-plus disable
```

Use a custom Electron runtime:

```bash
sudo install -dm755 /etc/codex-plus-plus
printf '%s\n' /usr/lib/electron42/electron | sudo tee /etc/codex-plus-plus/electron
sudo codex-plus-plus enable
```

## Notes

- The package depends on `openai-codex-desktop`.
- It leaves `/usr/bin/codex-desktop` on the upstream launcher unless enabled manually.
- The recommended desktop path is `OpenAI Codex (Codex++)`, which runs `codex-plus-plus run`.
- It keeps a backup of the upstream `/usr/bin/codex-desktop` launcher when enabled.
- By default, it follows the Electron runtime used by the upstream `openai-codex-desktop` launcher.
- An `alpm` hook reapplies the injection after `openai-codex-desktop` upgrades only when Codex++ is enabled.
- `codexplusplus` is kept as a compatibility alias.
