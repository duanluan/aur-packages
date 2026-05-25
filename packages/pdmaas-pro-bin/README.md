# pdmaas-pro-bin

`pdmaas-pro-bin` repackages the upstream Linux `.deb` release of
[PDMaas Pro](https://www.yonsum.com/) for Arch Linux.

## Local Build

This package currently builds from a local `.deb` file because the public AUR
source for `2.3.0` is not available.

1. Put `PDMaas-Pro-linux_amd64_v2.3.0.deb` in this directory.
2. Run `makepkg -si`.

If your file is still in `~/Downloads`, you can link it here:

```bash
ln -sf /home/njcm/Downloads/PDMaas-Pro-linux_amd64_v2.3.0.deb ./PDMaas-Pro-linux_amd64_v2.3.0.deb
```

## Launch

Start it from your application menu, or run:

```bash
pdmaas-pro
```

## Notes

- The package extracts the original upstream `.deb` into `/opt/PDMaas-Pro`.
- `java-runtime` is required by the bundled backend service.
- To sync this back to AUR later, replace the local source with a public URL and regenerate `.SRCINFO`.
