# Updates

CybroidOS is built on Debian 13. Installed computers get their updates from
`deb.cybroid.com`:

- Debian's packages and security updates, checked against Debian's signing
  keys;
- CybroidOS's own packages, checked against the CybroidOS archive key
  (shipped in `cybroid-sources`).

Both install by themselves in the background. **Settings → Updates** shows the
last run and can check now. From a terminal:

```sh
sudo apt update
sudo apt full-upgrade
```

Don't add other distributions' repositories (Ubuntu's, for example): their
packages can replace CybroidOS's. Flatpak apps from Flathub are fine; the App
Centre installs them.
