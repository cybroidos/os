# ADR-0006: Raspberry Pi image builder

- **Status:** Accepted (2026-10-11)
- **Date:** 2026-10-11
- **Deciders:** CIT-OS maintainers (Cybroid Institute of Technology / CIT)
- **Related:** ADR-0001 (base distribution), ADR-0002 (kiosk runtime),
  `docs/PLAN.md` (Phase 3), `docs/research/kiosk-runtime.md`.

## 1. Context

We need to produce a **flashable, branded, arm64 Raspberry Pi image**
(`.img`) based on Raspberry Pi OS (Debian Trixie lineage, ADR-0001) — the first
shippable artefact (Milestone A). Options were `pi-gen` (official) vs
`rpi-image-gen` (arm64-native, newer). The owner chose **pi-gen first**, and wants
the build to run in **GitHub Actions if feasible**.

## 2. Verified facts (2026-10-11)

- **`pi-gen`** is the **official** Raspberry Pi OS image builder (BSD-3-Clause,
  `RPi-Distro/pi-gen`).
- **64-bit/arm64 images are built from the `arm64` branch** (the `master` branch
  builds 32-bit/armhf images). → We use the **`arm64` branch**.
- Build is driven by a sourced **`config`** (e.g. `IMG_NAME`, `RELEASE`,
  `STAGE_LIST`, `DEPLOY_DIR`, `ENABLE_SSH`, `PUBKEY_ONLY_SSH`,
  `ENABLE_CLOUD_INIT`, `PI_GEN_RELEASE`) plus stage directories.
- **`STAGE_LIST`** may reference a stage **outside the pi-gen tree** (relative or
  absolute path), so our `stage-citos` can live in this repo.
- Stage conventions: numbered step subdirectories, each with optional
  `00-packages` and `NN-run.sh` (plus `files/`); `SKIP` skips a stage;
  `EXPORT_IMAGE` marks a stage as producing an image.
- **`build-docker.sh`** runs the build in a **privileged** container (base
  `i386/debian:trixie` on x86_64/aarch64 hosts), so it works from an x86 host with
  `qemu-user-static` — i.e. it is runnable in **CI**.
- **GitHub Actions feasibility:** yes. The main constraint is **disk space**
  (~30 GB needed). The community action **`RaspAP/pi-gen-action`** wraps pi-gen,
  exposes config as inputs (`pi-gen-version: arm64`, `release: trixie`), and
  reclaims ~30 GB; alternatively we run pi-gen's own `build-docker.sh` after
  freeing space. **arm64 GitHub-hosted runners** (public preview) are a future
  native-speed option.

## 3. Decision

- **Builder:** **`pi-gen`** (official), **`arm64` branch**, targeting Debian
  Trixie / arm64 (one image that also runs on Pi 4; see PLAN).
- **Customisation:** a **custom stage `stage-citos`** lives in this repo
  (`targets/rpi/stage-citos/`) and is appended via `STAGE_LIST`; it applies CIT
  branding and installs the kiosk (ADR-0002), then **exports the image**
  (`EXPORT_IMAGE`). Eventually the stage installs the signed **`<brand>-base`**
  package instead of copying files directly (Phase 4).
- **Build harness:** `targets/rpi/build.sh` clones pi-gen (`arm64`), wires in
  `stage-citos`, and runs `build-docker.sh`; the produced image lands in
  `targets/rpi/deploy/`.
- **CI:** a **manual/tag-triggered GitHub Actions workflow**
  (`.github/workflows/pi-image.yml`) frees disk space, runs the build, and uploads
  the `.img` as an artefact. It is **not** run on every push (long, heavy).
  `rpi-image-gen` remains a documented alternative if native arm64 CI becomes
  available.

## 4. Consequences

**Positive**
- Official, well-understood, reproducible builder; arm64 via the `arm64` branch.
- Custom stage keeps CIT changes in our repo (thin overlay).
- Buildable on x86 CI and on x86 dev hosts (E2E).

**Negative / risks**
- **Disk-heavy** and **slow** in hosted CI; needs the space-reclaim step.
- pi-gen's `arm64` branch tracks Raspberry Pi OS; **pin a known-good ref** and
  re-verify on updates.
- `build-docker.sh` needs `--privileged`; acceptable in CI/trusted hosts.
- `rpi-image-gen` may become preferable when native arm64 runners are available.

## 5. Verification log

CPU-branch rule (master = 32-bit, `arm64` branch = 64-bit), `config` variables,
`STAGE_LIST` external-stage support, stage/`EXPORT_IMAGE` conventions, and the
`i386/debian:trixie` base of `build-docker.sh` verified against `RPi-Distro/pi-gen`
(`README.md`, `build-docker.sh`). GitHub-Actions disk constraint and the
`RaspAP/pi-gen-action` wrapper verified against its README (incl.
`pi-gen-version: arm64`, `release: trixie`, ~30 GB reclaim). Nothing asserted from
memory alone.
