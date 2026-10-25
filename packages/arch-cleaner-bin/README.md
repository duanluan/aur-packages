# arch-cleaner-bin

[arch-cleaner](https://github.com/duanluan/arch-cleaner) 的预编译二进制 AUR 包，源为 GitHub Releases。

## 更新流程

1. 上游发新 release 后，改 `PKGBUILD` 的 `pkgver` 与 `sha256sums`（`curl -sL <tarball-url> | sha256sum`）。
2. `makepkg --printsrcinfo > .SRCINFO`
3. `./sync-aur.sh` 推送到 AUR。
