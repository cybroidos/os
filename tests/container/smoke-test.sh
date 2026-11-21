#!/usr/bin/env bash
# Smoke-test the Cybroid OS pod images (ADR-0005).
#
# For each selected image and architecture this script builds (unless
# --skip-build is given), starts a short-lived container, and checks:
#   - /etc/os-release has ID=cybroidos
#   - /etc/hostname is the branded hostname (cybroid)
#   - /usr/share/cybroidos/branding exists
#   - no default password is set and sshd is disabled without a key
#   - kcd is installed
#   - desktop images also carry xrdp, Xvfb, x11vnc and noVNC/websockify
#
# Only the docker CLI is required; no sudo/root-only assumptions are made.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
build_script="${repo_root}/targets/docker/build.sh"
brand="${repo_root}/common/branding/brand.toml"
docker_bin="${DOCKER:-docker}"

REGISTRY="${REGISTRY:-ghcr.io/cybroidtech}"
EDITION="${EDITION:-core}"

die() { echo "error: $*" >&2; exit 1; }
note() { echo "==> $*"; }

usage() {
	cat <<'EOF'
Usage: tests/container/smoke-test.sh [options]

Options:
  --arch ARCH       Test amd64 or arm64 (repeatable; default: both, or $ARCH)
  --image IMAGE     base, dev, desktop or all (default: all)
  --stack STACK     Dev stack generic/python/node (repeatable; default: all)
  --skip-build      Use images already loaded by targets/docker/build.sh
  -h, --help        Show this help

Environment:
  ARCH=amd64|arm64  Shortcut for a single architecture
  REGISTRY, TAG, EDITION  Must match the values used by build.sh
EOF
}

arches=()
images=()
stacks=()
skip_build=0
current_cid=""

while [ "$#" -gt 0 ]; do
	case "$1" in
		--arch)
			[ "$#" -ge 2 ] || die "--arch needs a value"
			arches+=("$2")
			shift 2
			;;
		--arch=*)
			arches+=("${1#*=}")
			shift
			;;
		--image)
			[ "$#" -ge 2 ] || die "--image needs a value"
			images+=("$2")
			shift 2
			;;
		--image=*)
			images+=("${1#*=}")
			shift
			;;
		--stack)
			[ "$#" -ge 2 ] || die "--stack needs a value"
			stacks+=("$2")
			shift 2
			;;
		--stack=*)
			stacks+=("${1#*=}")
			shift
			;;
		--skip-build) skip_build=1; shift ;;
		-h|--help) usage; exit 0 ;;
		-*) die "unknown option: $1" ;;
		*) die "unexpected argument: $1" ;;
	esac
done

command -v "${docker_bin}" >/dev/null 2>&1 || die "docker CLI not found (set DOCKER)"
[ -f "${brand}" ] || die "missing brand file: ${brand}"

read -r brand_version brand_hostname < <(python3 - "${brand}" <<'PY'
import sys
import tomllib

identity = tomllib.load(open(sys.argv[1], "rb"))["identity"]
print(identity["version"], identity["default_hostname"])
PY
)
TAG="${TAG:-${brand_version}}"

if [ "${#arches[@]}" -eq 0 ]; then
	read -r -a arches <<< "${ARCH:-amd64 arm64}"
fi
[ "${#images[@]}" -gt 0 ] || images=(all)
[ "${#stacks[@]}" -gt 0 ] || stacks=(generic python node)

if [ "${images[0]}" = all ]; then
	images=(base dev desktop)
fi
for arch in "${arches[@]}"; do
	case "${arch}" in
		amd64|arm64) ;;
		*) die "unsupported architecture '${arch}'" ;;
	esac
done
for image in "${images[@]}"; do
	case "${image}" in
		base|dev|desktop) ;;
		*) die "unknown image '${image}'" ;;
	esac
done
for stack in "${stacks[@]}"; do
	case "${stack}" in
		generic|python|node) ;;
		*) die "unknown stack '${stack}'" ;;
	esac
done

failures=0

cleanup() {
	if [ -n "${current_cid}" ]; then
		"${docker_bin}" rm -f "${current_cid}" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

ok() { echo "  ok   $*"; }
bad() {
	echo "  FAIL $*"
	failures=$((failures + 1))
}

check_eq() {
	local desc="$1" actual="$2" expected="$3"
	if [ "${actual}" = "${expected}" ]; then
		ok "${desc}"
	else
		bad "${desc} (expected '${expected}', got '${actual}')"
	fi
}

check_has() {
	local desc="$1" haystack="$2" needle="$3"
	if printf '%s\n' "${haystack}" | grep -qF "${needle}"; then
		ok "${desc}"
	else
		bad "${desc} (missing '${needle}')"
	fi
}

check_absent() {
	local desc="$1" haystack="$2" needle="$3"
	if printf '%s\n' "${haystack}" | grep -qF "${needle}"; then
		bad "${desc} (unexpected '${needle}')"
	else
		ok "${desc}"
	fi
}

run_image() {
	local image="$1" stack="$2" arch="$3"
	local name ref local_ref cid exec_out
	local -a build_args=(--arch "${arch}")
	local -a run_args=(
		--detach
		--rm
		--hostname "${brand_hostname}"
		--name "cybroid-smoke-$$-${image}-${stack:-none}-${arch}"
	)

	if [ "${image}" = dev ]; then
		name="cybroidos-pod-dev-${stack}"
		build_args+=(--stack "${stack}" dev)
	else
		name="cybroidos-pod-${image}"
		build_args+=("${image}")
	fi
	ref="${REGISTRY}/${name}:${TAG}"
	local_ref="${ref}-${arch}"

	note "${local_ref}: build and smoke test"
	if [ "${skip_build}" -eq 0 ]; then
		PUSH=0 "${build_script}" "${build_args[@]}" >&2
	fi

	cid="$("${docker_bin}" run "${run_args[@]}" "${local_ref}")"
	current_cid="${cid}"

	# Wait for first-boot identity setup to finish.
	local i
	for i in {1..20}; do
		if "${docker_bin}" exec "${cid}" test -f /var/lib/cybroidos/.identity-ready >/dev/null 2>&1; then
			break
		fi
		sleep 0.5
	done

	exec_out="$("${docker_bin}" exec "${cid}" sh -c 'grep "^ID=" /etc/os-release | head -n 1 | cut -d= -f2' 2>/dev/null || true)"
	check_eq "os-release ID=cybroidos" "${exec_out}" "cybroidos"

	exec_out="$("${docker_bin}" exec "${cid}" cat /etc/hostname 2>/dev/null || true)"
	check_eq "hostname ${brand_hostname}" "${exec_out}" "${brand_hostname}"

	exec_out="$("${docker_bin}" exec "${cid}" test -d /usr/share/cybroidos/branding && echo present 2>/dev/null || true)"
	check_eq "branding assets present" "${exec_out}" "present"

	exec_out="$("${docker_bin}" exec "${cid}" sh -c 'command -v kcd || true' 2>/dev/null || true)"
	check_eq "kcd installed" "${exec_out}" "/usr/bin/kcd"

	exec_out="$("${docker_bin}" exec "${cid}" passwd -S cybroid 2>/dev/null || true)"
	case " ${exec_out} " in
		*" P "*|*" PS "*) bad "no default password for cybroid (${exec_out})" ;;
		*) ok "no default password for cybroid" ;;
	esac
	exec_out="$("${docker_bin}" exec "${cid}" passwd -S root 2>/dev/null || true)"
	case " ${exec_out} " in
		*" P "*|*" PS "*) bad "root password is locked (${exec_out})" ;;
		*) ok "root password is locked" ;;
	esac

	exec_out="$("${docker_bin}" exec "${cid}" cat /etc/ssh/sshd_config 2>/dev/null || true)"
	check_has "sshd: PasswordAuthentication no" "${exec_out}" "PasswordAuthentication no"
	check_has "sshd: PermitRootLogin no" "${exec_out}" "PermitRootLogin no"
	check_has "sshd: pubkey-only" "${exec_out}" "AuthenticationMethods publickey"

	if "${docker_bin}" exec "${cid}" pgrep -x sshd >/dev/null 2>&1; then
		bad "sshd is disabled without a supplied key"
	else
		ok "sshd is disabled without a supplied key"
	fi
	exec_out="$("${docker_bin}" exec "${cid}" sh -c 'if [ -s /home/cybroid/.ssh/authorized_keys ]; then echo present; else echo absent; fi' 2>/dev/null || true)"
	check_eq "no baked-in authorized_keys" "${exec_out}" "absent"

	if [ "${image}" = desktop ]; then
		for binary in /usr/sbin/xrdp /usr/bin/Xvfb /usr/bin/x11vnc \
			/usr/bin/websockify /usr/bin/startxfce4; do
			exec_out="$("${docker_bin}" exec "${cid}" test -x "${binary}" && echo present 2>/dev/null || true)"
			check_eq "desktop binary ${binary}" "${exec_out}" "present"
		done
		exec_out="$("${docker_bin}" exec "${cid}" test -f /usr/share/novnc/vnc.html && echo present 2>/dev/null || true)"
		check_eq "noVNC web assets" "${exec_out}" "present"
		exec_out="$("${docker_bin}" exec "${cid}" test -f /etc/xrdp/xrdp.ini && echo present 2>/dev/null || true)"
		check_eq "xrdp configuration" "${exec_out}" "present"
	fi

	"${docker_bin}" rm -f "${cid}" >/dev/null 2>&1 || true
	current_cid=""
}

for arch in "${arches[@]}"; do
	for image in "${images[@]}"; do
		if [ "${image}" = dev ]; then
			for stack in "${stacks[@]}"; do
				run_image "${image}" "${stack}" "${arch}"
			done
		else
			run_image "${image}" "" "${arch}"
		fi
	done
done

if [ "${failures}" -ne 0 ]; then
	die "${failures} smoke-test check(s) failed"
fi
echo "All container smoke tests passed."
