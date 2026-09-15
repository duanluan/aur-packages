# zcode-pro

`zcode-pro` is a UI enhancement launcher for the ZCode desktop app.
Launching ZCode through it enables the enhancements automatically; the
official application files stay untouched.

Current feature: custom display aliases for projects in the ZCode sidebar
(pure UI-layer names — directories and all ZCode data remain unchanged).

## Install

With `paru`:

```bash
paru -S zcode-pro
```

With `yay`:

```bash
yay -S zcode-pro
```

Manual install from this repository:

```bash
cd packages/zcode-pro
makepkg -si
```

## Notes

- Depends on the AUR `zcode` package, which installs the ZCode desktop app
  under `/opt/ZCode`.
- After installation, launch **ZCode Pro** from the application menu (or run
  `zcode-pro`) instead of the plain ZCode icon; the enhancements apply for
  that session.
- No Node.js required: the launcher reuses the Node runtime bundled with
  ZCode when the system has none.
- Project home: <https://github.com/duanluan/zcode-pro>
