# wechat-xwayland

This package depends on the upstream `wechat-bin` package and adds an XWayland
launcher plus a separate activation command for KDE Plasma shortcuts.

- Launch WeChat with `wechat-xwayland`.
- Bind `/usr/bin/activate-wechat-xwayland` to a KDE custom global shortcut.
- Uninstalling `wechat-xwayland` removes both commands and its desktop entry.

The launcher reuses a running WeChat instance instead of spawning a second
one: duplicate processes grow the memory footprint until the system starts
swapping, and their extra PIDs break the tray matching in the activation
script, which leaves the minimized window unreachable. When WeChat is already
running, `wechat-xwayland` runs the activation command instead.

The activation command does not launch a second WeChat process. It activates an
existing XWayland window when one is visible, then falls back to the WeChat
StatusNotifierItem when the window is minimized to the tray.
