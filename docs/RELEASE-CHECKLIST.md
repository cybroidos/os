# Release checklist

Before a CybroidOS release is announced. A release is a version bump in
`common/branding/brand.toml`: the ISO job (`.forgejo/workflows/images.yml`)
builds the ISO, its manifest and checksum, and publishes the packages to
`deb.cybroid.com`.

## Versions

CybroidOS is versioned `0.MINOR.PATCH` until the first stable release
(1.0): every package carries the version in `common/branding/brand.toml`.

1. Raise `[identity] version` in `brand.toml`, and turn `## [Unreleased]` in
   `CHANGELOG.md` into `## [<version>] - <date>` (CI fails while the version
   has no section).
2. Push to `main`. The image build (`.forgejo/workflows/images.yml`) builds
   the ISO, its checksum and manifest, and publishes the packages to
   deb.cybroid.com, from where installed computers update.
3. When the checks below pass, tag the same commit and push the tag:
   `git tag -s v<version> -m "CybroidOS <version>" && git push origin v<version>`.
   The release workflow refuses a tag that doesn't match `brand.toml`, and
   publishes the GitHub Release with the changelog's notes. The tag also
   builds the ISO on GitHub's runners and publishes it to
   download.cybroid.com (`.github/workflows/release-images.yml`; "Run
   workflow" there builds it without releasing, or an ISO with one edition
   built in, for a lab without internet).
4. The edition packages, Docker Engine and ONLYOFFICE are on deb.cybroid.com
   at this version (`tools/ci-publish.sh`, from the Server images workflow,
   or `publish-by-hand.sh` in cybroidtech/cybroidos-infra): the welcome
   installs editions from there.

## Downloads

- **The downloads store** keeps the newest two releases: the ISO, its
  `.sha256` and `.manifest.md`; `latest.json` and `releases.json` list
  them for cybroid.com. Today that is the `downloads` bucket in Nova's Appwrite
  (`cloud.novabusiness.one`, project `6b0569ed0033da77b1d7`, 5 GB per file;
  `tools/appwrite-store.py`), used whenever the `CYBROID_APPWRITE_KEY` secret
  is set. Cloudflare R2 (bucket `cybroidos-downloads`) still works the same
  way without it, and there each release also gets an `index.html`. Once
  download.cybroid.com is the Appwrite project's domain, set the repository
  variable `CYBROID_APPWRITE_PUBLIC_ENDPOINT` to `https://download.cybroid.com/v1`
  and run `tools/downloads.sh index` so the links use it.
- **Older releases** move to the Internet Archive (`cybroidos-<version>`)
  every Monday (`.github/workflows/downloads.yml`, `tools/downloads.sh
  retire`): copied, checked against the archive's own MD5, their GitHub
  Release notes pointed at the archive, and only then removed from the store. A file
  that no longer matches its checksum is never copied or removed, and fails
  the run.
- **Every version** keeps its GitHub Release: notes, and links to wherever
  its files are.

## Build

- [ ] CI is green (`ci.yml`: brand, shell, package checks).
- [ ] The ISO built from the tagged commit; its `.manifest.md` names that commit.
- [ ] The packages for this version are on `deb.cybroid.com` and `apt update`
      on an installed machine verifies the signature.

## Test (a real laptop and the test VM)

- [ ] The ISO starts on UEFI and on BIOS; the boot menu shows, and choosing an
      entry leaves the mark in place (no box).
- [ ] Live session: Wi-Fi, sound, displays, both looks (Horizon, Hex), light and dark.
- [ ] Install (whole disk, and alongside Windows); the new account's shell is
      zsh (`getent passwd <name>` ends in `/usr/bin/zsh`).
- [ ] Installed: silent boot, sign-in, updates (**Settings → Updates**),
      firewall on (`sudo nft list ruleset`), SSH and remote desktop off.
- [ ] An earlier install upgrades through `cybroid-update` without errors;
      the account menu appears in its top bar, and its shell is zsh.
- [ ] Account menu: Lock, Sleep, Sign out, Restart and Shut down each work
      (Restart and Shut down ask first); Launchpad's power row too.
- [ ] Office: a .docx, .xlsx and .pptx open in ONLYOFFICE; ONLYOFFICE
      updates from deb.cybroid.com.
- [ ] Tower: on a computer not on Tower, `systemctl is-active tailscaled xrdp ssh`
      are inactive; joining Tower starts them; KDE Connect reaches the computer
      over Tower and on a network marked home, not on others.
- [ ] Idle memory, signed in and idle five minutes on the test VM
      (`smem -tk` or `free -m`): record it here, and compare with the last release.

## Editions

- [ ] The welcome's Editions step installs each edition from deb.cybroid.com
      (and Settings > About > Add an edition opens it); its apps start,
      Flathub's ones included; Developer: `code` opens, `docker run hello-world`
      works after signing in again.
- [ ] Security: "Kali tools" creates the container and opens a shell.
- [ ] Classroom: a lab account's files are gone after a restart; a teacher's
      are not; Veyon Master sees a student computer.

## Legal and documents

- [ ] `LICENSE`, `LICENSE-ASSETS`, `NOTICE.md` and
      `docs/PROPRIETARY-COMPONENTS.md` are current.
- [ ] `common/packages/copyright` matches the licence map in `NOTICE.md`.
- [ ] `docs/user/` matches what ships; `README.md` names the version.
- [ ] Release notes: what changed, the checksum, the manifest, and a link to
      `docs/PROPRIETARY-COMPONENTS.md`.
