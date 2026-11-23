# Contributing to CybroidOS

Thank you for helping. CybroidOS is built in the open by Cybroid Technologies
(U) Ltd and anyone who wants to improve it.

## Before you start

- **Bugs and ideas:** open an issue. For questions, use Discussions.
- **Security problems:** never in an issue. Follow [docs/SECURITY.md](docs/SECURITY.md).
- **Bigger changes:** open an issue first, so we can agree on the approach
  before you spend time on it.

## Making a change

1. Fork the repository and branch from `main`.
2. Keep each change small and about one thing; say in the pull request what
   it does and how you tested it (on the test VM, real hardware, or both).
3. Build what you touched: `tools/build-package.sh <package>` for a package,
   `targets/desktop/build-iso.sh` for the ISO (see the README).
4. Write for the people who use CybroidOS: plain words in anything they see,
   and comments that say why, not what.

## Sign your work (DCO)

Every commit must be signed off, which says you wrote it or otherwise have
the right to contribute it under the project's licences (the
[Developer Certificate of Origin](https://developercertificate.org/)):

```sh
git commit -s -m "Settings: a clearer name for the Wi-Fi switch"
```

That adds a line like `Signed-off-by: Your Name <you@example.com>`. CI checks
every commit in a pull request for it. Forgot? `git commit --amend -s` for the
last commit, or `git rebase --signoff main` for all of them.

## Licences

Code, packaging and configuration are under the GNU GPL v3 or later
([LICENSE](LICENSE)); the CybroidOS name, mark and artwork under CC BY-NC 4.0
([LICENSE-ASSETS](LICENSE-ASSETS)) and Cybroid's trademark policy
([NOTICE.md](NOTICE.md)). By contributing you agree your work is released
under the licence of the files you change.

## Code of conduct

Everyone taking part follows our [code of conduct](CODE_OF_CONDUCT.md).
