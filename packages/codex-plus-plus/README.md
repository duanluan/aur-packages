# codex-plus-plus

`codex-plus-plus` packages [Codex++](https://github.com/BigPizzaV3/CodexPlusPlus)
as a manual injection bridge for the Arch Linux ChatGPT desktop app. It uses
the [`chatgpt-desktop`](https://aur.archlinux.org/packages/chatgpt-desktop) package.

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

The package does not take over the ChatGPT launcher automatically.

Check status:

```bash
codex-plus-plus status
```

Launch the injected app without changing the upstream launcher:

```bash
codex-plus-plus run
```

The package also installs `ChatGPT (Codex++)` in the application menu.

Enable or disable injection:

```bash
sudo codex-plus-plus enable
sudo codex-plus-plus disable
```

## Notes

- The package depends on `chatgpt-desktop`.
- It leaves `/usr/bin/chatgpt` on the upstream launcher unless enabled manually.
- The recommended desktop path is `ChatGPT (Codex++)`, which runs `codex-plus-plus run`.
- It keeps a backup of the upstream `/usr/bin/chatgpt` launcher when enabled.
- It reuses the official ChatGPT launcher and native `/usr/lib/chatgpt/ChatGPT` app.
- An `alpm` hook reapplies the injection after ChatGPT package upgrades only when Codex++ is enabled.
- `/usr/bin/codex-desktop` remains supported through the upstream compatibility alias.
- `codexplusplus` is kept as a compatibility alias.
