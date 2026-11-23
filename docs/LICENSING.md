# Licensing policy for the public CybroidOS release

This document records the research and the decision behind the licence split.
It was prepared after reviewing how Red Hat and Zorin handle open code,
commercial value, and components that are not open source.

## Research: Red Hat

Red Hat Enterprise Linux is an open-source distribution: the component source
code is available and the product is built from free/open-source packages. Red
Hat does **not** make the code proprietary. Its protection against exploitation
comes from:

- **Subscriptions/support** — updates, certifications and support are sold, not
  the code.
- **Trademarks** — the Red Hat name and logos cannot be used by derivative
  rebuilds; derivatives must de-brand themselves (AlmaLinux, Rocky, Oracle
  Linux, etc.).
- **Source publication strategy** — the major-version source moved to CentOS
  Stream, while customer contracts discourage redistributing subscription
  source artifacts.

Takeaway: keep code free, protect the name, and put commercial value in
support/certification rather than in license restrictions on code.

Source: <https://en.wikipedia.org/wiki/Red_Hat_Enterprise_Linux>

## Research: Zorin OS

Zorin OS ships a free **Core** edition and a paid **Pro** edition. It is
Ubuntu-based, openly auditable ("Zorin OS is Open Source, so anyone can audit
its source code"), and keeps a clear boundary around:

- optional proprietary device drivers;
- paid Pro themes/apps and support;
- the Zorin name and logo, which remain the company's trademarks.

Takeaway: a free open core plus clearly-separated paid/proprietary extras is a
normal, accepted distribution model.

Sources: <https://zorin.com/os/>,
<https://en.wikipedia.org/wiki/Zorin_OS>

## Decision for CybroidOS

The goal was "open source, but a bit restrictive to fight exploitation", while
accepting that some bundled software (for example Hangar) is not open source.
The clean way to do that is to restrict **brand and trademarks**, not code:

1. **GPL-3.0-or-later** for the build system, scripts, Debian packaging and
   configuration. Contributors keep all standard free-software freedoms.
2. **CC BY-NC 4.0** for logos, icons, wallpapers and the palette. Anyone can
   build and modify CybroidOS; nobody can sell the Cybroid branding itself.
3. **Trademark policy** in [`NOTICE.md`](../NOTICE.md): derivatives must rename
   and de-brand; unmodified branded images need written permission.
4. **Proprietary components register** in
   [`PROPRIETARY-COMPONENTS.md`](PROPRIETARY-COMPONENTS.md). Non-free software
   is never mixed into the source repo; if it is shipped at all it is optional,
   separately licensed, and documented.
5. **Value-add is support, not locks** — following Red Hat and Zorin, revenue
   comes from support, training, and certified images, not from making the
   build code proprietary.

This is more robust than a custom "source-available" licence: the code is
recognisably open source, while the parts actually at risk of exploitation
(identity and branding) are protected.

## Compliance checklist for a release

- [ ] `LICENSE`, `LICENSE-ASSETS`, `NOTICE.md` and this document are present.
- [ ] `common/packages/copyright` matches the licence map.
- [ ] Proprietary components are listed and either absent or opt-in.
- [ ] Debian's copyright files remain in the image (`/usr/share/doc/*/copyright`).
- [ ] `tools/release-manifest.sh` output is attached to the release.
- [ ] Trademark attribution appears in docs and splash/about screens.
