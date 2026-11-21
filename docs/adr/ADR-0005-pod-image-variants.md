# ADR-0005: Pod / container image variants

- **Status:** Accepted (2026-10-11)
- **Date:** 2026-10-11
- **Deciders:** Cybroid OS maintainers (Cybroid Technologies (U) Ltd)
- **Related:** ADR-0001 (base distribution), ADR-0003 (desktop environment),
  ADR-0004 (mobile client), `docs/PLAN.md` (Phases 4–5).

## 1. Context

"Pods" are Cybroid's container-based work environments. Owner's direction
(2026-10-11):

- Pods are offered **two ways**:
  1. **without a desktop** — a headless **dev container / dev space**, and
  2. **with a desktop** — **Xfce + remote desktop**, for **development** and other
     GUI work.
- Pods must **double as dev containers / dev spaces AND as remote desktops**.
- **Several container images** are needed (different stacks).

Server/pods already use **Xfce 4.20** (ADR-0003). This ADR fixes the *image
family*, the desktop-in-container mechanism, and the remote-access path. Phase 5
covers the **server VM/ISO + `qcow2`**; Phase 4 covers **Docker** images.

## 2. Decision drivers

1. One vocabulary for "pod" across **container** and **VM** forms.
2. **Dev-container interoperability** (VS Code / devcontainers spec) so engineers'
   existing tooling keeps working (Ground rule 3).
3. A **GUI-in-container** path that works without host privileges and on **both
   amd64 and arm64**.
4. Reuse the **same Xfce branding** as the server/pod VM.
5. Keep images **thin**: branding/config from `<brand>-base`, per-stack images add
   only what that stack needs.

## 3. Verified facts (2026-10-11)

- **Devcontainers spec** (`containers.dev`): `.devcontainer/devcontainer.json` and
  an image label `devcontainer.metadata` are the standard mechanism; VS Code and
  compatible tooling read them.
- The **`desktop-lite`** devcontainer Feature provides a lightweight desktop
  (Fluxbox) reachable via **noVNC/VNC** — proves desktop-in-a-dev-container is a
  supported pattern.
- **Xfce + xrdp** and **Xfce + VNC/noVNC** container images are common and run
  **without privileges** on amd64 and arm64 (e.g. `danchitnis/xrdp` supports Xfce
  on both architectures; `soff/ubuntu-xfce-vnc` pattern: Xfce4 + VNC `:5901` +
  RDP `:3389` + noVNC `:6901`).
- **`kcd`** — a headless **Go** implementation of the KDE Connect protocol (v8) —
  runs on servers/containers **without a GUI or D-Bus**, so pods can expose KDE
  Connect (ADR-0004) without a full KDE stack.
- Base container: `debian:trixie-slim` (ADR-0001), plus `buildx` + QEMU binfmt for
  cross-arch builds.

## 4. Options considered

| Aspect | Options | Decision |
|---|---|---|
| Pod families | (a) headless only, (b) desktop only, (c) **both** | **both** (c) |
| Headless mechanism | plain image vs **devcontainers spec** | **devcontainers spec** |
| Desktop-in-container | Xfce + **xrdp (RDP)** vs Xfce + **VNC/noVNC** | **both**: RDP primary, noVNC for browser |
| Detection | one "magic" image vs **explicit named images** | **explicit named images** |
| KDE Connect in pods | none vs `kdeconnect-kde` (heavy) vs **`kcd` (headless)** | **`kcd`** |

## 5. Decision

Pods come in **two families**, built on a shared base:

1. **`cybroidos-pod-base`** — `debian:trixie-slim` + `<brand>-base` + `kcd` + SSH +
   common tooling. No desktop.
2. **`cybroidos-pod-dev-<stack>`** — **headless dev spaces** (one per stack; e.g.
   generic, Python, Node, .NET, Go, Rust). Each is a **devcontainer**:
   ships `.devcontainer/devcontainer.json` + the `devcontainer.metadata` label.
3. **`cybroidos-pod-desktop`** — **Xfce 4.20** + **xrdp (RDP, primary)** +
   **noVNC (browser fallback)**, same Xfce branding as the server/pod VM, plus
   `kcd`. This is the **remote-desktop dev space** for GUI development.

Conventions:

- **Multi-arch:** all pod images build for **amd64 and arm64**.
- **Naming:** `cybroidos-pod-*` (a pod is the container form of the server/pod target).
- Two ways to use a pod = **the same base + the desktop layer, or not** — selected
  by tag/image, not by a runtime flag.
- The **server VM/ISO + `qcow2`** (Phase 5) reuse the **same Xfce + remote-access
  configuration** as `cybroidos-pod-desktop`.
- Remote access path for the Xfce session is **RDP (xrdp)** primary with
  **VNC/noVNC** fallback — resolving PLAN open item #13 for pods; the server VM
  uses the same choice.

## 6. Consequences

**Positive**
- "Pod" means one thing; the same Xfce/remote config serves containers and VMs.
- Engineers keep using **devcontainers** in VS Code (Ground rule 3).
- GUI-in-container works **rootless** on amd64/arm64.
- `kcd` lets pods participate in the ADR-0004 mobile-control story cheaply.

**Negative / risks**
- More images to build/test (one dev image per stack) → CI matrix grows.
- RDP/VNC in containers needs correct port exposure and (for RDP) TLS/auth setup.
- arm64 GUI images pull large layers; keep them lean and cache aggressively.

**Out of scope:** the server VM/ISO build itself (Phase 5) and the mobile app
(ADR-0004).

## 7. Open questions

| # | Question | Default until answered |
|---|---|---|
| 1 | Which exact dev stacks to ship first? | generic + Python + Node first |
| 2 | RDP vs VNC as the *internal* server-VM default too? | RDP (matches pods) |
| 3 | Do pods get *pull-based* KDE Connect pairing or a broker? | pairing via `kcd` + relay (ADR-0004) |
| 4 | Registry: GHCR vs self-hosted? | GHCR (PLAN §8) |

## 8. Verification log

Devcontainers spec + `devcontainer.metadata` label and the `desktop-lite` Feature
(VNC/noVNC) confirmed against `containers.dev`. Rootless Xfce+RDP/VNC container
patterns and amd64/arm64 support confirmed against published images
(`danchitnis/xrdp`, `soff/ubuntu-xfce-vnc`). `kcd` headless KDE Connect v8
confirmed against its repository. Base image `debian:trixie-slim` per ADR-0001.
Nothing asserted from memory alone.
