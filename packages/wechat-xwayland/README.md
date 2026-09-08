# wechat-xwayland

This package depends on the upstream `wechat-bin` package and adds an XWayland
launcher plus a separate activation command for KDE Plasma shortcuts.

- Launch WeChat with `wechat-xwayland`.
- Bind `/usr/bin/activate-wechat-xwayland` to a KDE custom global shortcut.
- Uninstalling `wechat-xwayland` removes both commands and its desktop entry.

The activation command does not launch a second WeChat process. It activates an
existing XWayland window when one is visible, then falls back to the WeChat
StatusNotifierItem when the window is minimized to the tray.
