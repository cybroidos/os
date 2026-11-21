#!/usr/bin/env bash
# Smoke-test a Cybroid OS server/pods qcow2 image.
#
# Offline (SKIP_BOOT=1): inspect a COPY of the qcow2 converted to raw with
# qemu-img and read files through debugfs. No host filesystem or image
# partition is ever mounted. Needs qemu-utils + e2fsprogs.
#
# Live (default): boot the qcow2 with QEMU/KVM plus the cloud-init seed ISO,
# wait for SSH, and assert identity, branding, packages, enabled services and
# the absence of a default password. Needs KVM (/dev/kvm), an SSH private key
# matching the public key used at build time, and the seed ISO.
#
# QEMU is emulation, not hardware validation (docs/PLAN.md ground rule 4).
#
# Usage: tests/server/smoke-test.sh IMAGE.qcow2 [SEED.iso]
# Env: SKIP_BOOT (0/1), SSH_PRIVATE_KEY, QEMU (qemu-system-x86_64),
#      BOOT_TIMEOUT (240), SSH_PORT (2222), RDP_PORT (3389), NOVNC_PORT (6080),
#      KVM (auto|1|0), GUESTFISH (optional), WORK_DIR
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf 'note: %s\n' "$*" >&2; }

image=""
seed=""
for arg in "$@"; do
	case "$arg" in
		-*) die "unknown option: ${arg}" ;;
		"") die "empty argument" ;;
		*)
			if [ -z "${image}" ]; then image="$arg"
			elif [ -z "${seed}" ]; then seed="$arg"
			else die "too many arguments: ${arg}"
			fi ;;
	esac
done
[ -n "${image}" ] || die "usage: $0 IMAGE.qcow2 [SEED.iso]"
[ -f "${image}" ] || die "no such image: ${image}"
if [ -n "${seed}" ] && [ ! -f "${seed}" ]; then die "no such seed ISO: ${seed}"; fi

SKIP_BOOT="${SKIP_BOOT:-0}"
KVM="${KVM:-auto}"
QEMU="${QEMU:-qemu-system-x86_64}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-240}"
SSH_PORT="${SSH_PORT:-2222}"
RDP_PORT="${RDP_PORT:-3389}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
SSH_PRIVATE_KEY="${SSH_PRIVATE_KEY:-}"

fail=0
check() {
	# check DESCRIPTION HAYSTACK REGEX — one failed check marks the run failed.
	local desc="$1" haystack="$2" needle="$3"
	if printf '%s' "${haystack}" | grep -qE "${needle}"; then
		printf '  ok   %s\n' "${desc}"
	else
		printf '  FAIL %s\n' "${desc}"
		fail=1
	fi
}

check_absent() {
	# check_absent DESCRIPTION HAYSTACK REGEX — the pattern must NOT be present.
	local desc="$1" haystack="$2" needle="$3"
	if printf '%s' "${haystack}" | grep -qE "${needle}"; then
		printf '  FAIL %s\n' "${desc}"
		fail=1
	else
		printf '  ok   %s\n' "${desc}"
	fi
}

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

command -v qemu-img >/dev/null 2>&1 || die "qemu-utils (qemu-img) is required"
qemu-img info "${image}" 2>/dev/null | grep -q '^file format: qcow2' \
	|| die "not a qcow2 image: ${image}"

# --- Seed ISO checks (offline, no mount) -------------------------------------
validate_seed() {
	local iso="$1" iso_info="" user_data="${work}/seed-user-data"
	[ -f "${iso}" ] || die "missing seed ISO: ${iso}"
	if command -v isoinfo >/dev/null 2>&1; then
		iso_info="$(isoinfo -d -i "${iso}" 2>/dev/null)"
		isoinfo -i "${iso}" -x /user-data > "${user_data}" 2>/dev/null \
			|| isoinfo -i "${iso}" -x '/user-data;1' > "${user_data}" 2>/dev/null \
			|| die "could not read /user-data from ${iso}"
	elif command -v xorriso >/dev/null 2>&1; then
		iso_info="$(xorriso -indev "${iso}" 2>&1)"
		xorriso -indev "${iso}" -osirrox on \
			-extract /user-data "${user_data}" >/dev/null 2>&1 \
			|| die "could not extract /user-data from ${iso}"
	else
		die "genisoimage (isoinfo) or xorriso is required to inspect the seed ISO"
	fi
	echo "cloud-init seed:"
	check "volume id is cidata" "${iso_info}" 'Volume id: *[cC][iI][dD][aA][tT][aA]'
	check "user-data is #cloud-config" "$(head -n 1 "${user_data}")" '^#cloud-config$'
	check "hostname cybroid" "${user_data}" '^hostname: cybroid$'
	check "cybroid admin user" "${user_data}" 'name: cybroid'
	check "SSH key injected from file" "${user_data}" 'ssh_authorized_keys'
	check_absent "no unrendered placeholders" "${user_data}" '__CYBROIDOS_'
	check "first-boot runcmd" "${user_data}" 'cybroidos-first-boot'
}
if [ -n "${seed}" ]; then validate_seed "${seed}"; fi

# --- Offline inspection: qemu-img -> raw -> debugfs (never mount) ------------
if [ "${SKIP_BOOT}" = 1 ]; then
	command -v debugfs >/dev/null 2>&1 || die "SKIP_BOOT=1 needs debugfs (e2fsprogs)"
	raw="${work}/disk.raw"
	echo "Converting image to a raw copy in ${work} (no mounts)"
	qemu-img convert -f qcow2 -O raw "${image}" "${raw}"

	eval "$(python3 - "${raw}" <<'PY'
import struct, sys
path = sys.argv[1]
with open(path, "rb") as fh:
    mbr = fh.read(512)
if mbr[510:512] != b"\x55\xaa":
    sys.exit("error: no protective MBR signature")
fh = open(path, "rb")
fh.seek(512)
hdr = fh.read(92)
if hdr[:8] != b"EFI PART":
    sys.exit("error: no GPT header")
entry_size = struct.unpack("<I", hdr[84:88])[0]
entry_lba = struct.unpack("<Q", hdr[72:80])[0]
fh.seek(entry_lba * 512)
entries = fh.read(entry_size * 4)
for i in range(4):
    e = entries[i * entry_size:(i + 1) * entry_size]
    name = e[56:128].decode("utf-16-le", "replace").split("\x00", 1)[0]
    first, last = struct.unpack("<QQ", e[32:48])
    if name == "root" and last > first:
        print(f"root_start={first * 512}")
        print(f"root_size={(last - first + 1) * 512}")
        break
else:
    sys.exit("error: no GPT partition named 'root'")
PY
)"
	[ -n "${root_start:-}" ] && [ -n "${root_size:-}" ] \
		|| die "could not locate the root partition"
	ext4="${work}/rootfs.ext4"
	dd if="${raw}" of="${ext4}" bs=512 skip=$((root_start / 512)) \
		count=$((root_size / 512)) status=none

	rd() { debugfs -R "cat $1" "${ext4}" 2>/dev/null; }
	lsdir() { debugfs -R "ls -l $1" "${ext4}" 2>/dev/null; }
	status="$(rd /var/lib/dpkg/status)"
	wants="$(lsdir /etc/systemd/system/multi-user.target.wants)"

	echo "offline identity:"
	check "os-release ID=cybroidos" "$(rd /usr/lib/os-release)" '^ID=cybroidos$'
	check "os-release name" "$(rd /usr/lib/os-release)" 'Cybroid OS'
	check "branded /etc/motd" "$(rd /etc/motd)" 'Cybroid OS'
	check "branded /etc/issue" "$(rd /etc/issue)" 'Cybroid OS'
	check "hostname cybroid" "$(rd /etc/hostname)" '^cybroid$'
	check "brand assets present" "$(lsdir /usr/share/cybroidos/branding)" 'cybroid-logo'

	echo "offline packages and services:"
	for pkg in xfce4 xrdp kcd cloud-init novnc x11vnc openssh-server cybroidos-base cybroidos-server; do
		check "package ${pkg} installed" "${status}" "^Package: ${pkg}$"
	done
	for unit in ssh.service xrdp.service xrdp-sesman.service cloud-init.service \
		cybroidos-first-boot.service cybroidos-xfce-session.service cybroidos-kcd.service; do
		check "service ${unit} enabled" "${wants}" "${unit}"
	done
	check "Xfce launcher for xrdp" "$(rd /etc/xrdp/startwm.sh)" 'startxfce4'
	check "xrdp port 3389" "$(rd /etc/xrdp/xrdp.ini)" '^port=3389$'
	check "noVNC fallback configured" "$(rd /etc/cybroidos/novnc.conf)" '^NOVNC_PORT=6080$'
	check "headless kcd present" "$(rd /etc/systemd/system/cybroidos-kcd.service)" 'kcd daemon'
	check "cloud-init NoCloud datasource" "$(rd /etc/cloud/cloud.cfg.d/90-cybroidos.cfg)" 'NoCloud'
	check "first-boot script installed" "$(lsdir /usr/bin)" 'cybroidos-first-boot'

	echo "offline security assertions:"
	sshd_conf="$(rd /etc/ssh/sshd_config.d/90-cybroidos.conf)"
	check "SSH password auth disabled" "${sshd_conf}" '^PasswordAuthentication no$'
	check "SSH root login disabled" "${sshd_conf}" '^PermitRootLogin no$'
	shadow="$(rd /etc/shadow)"
	check "cybroid password locked" "${shadow}" '^cybroid:!'

	[ "${fail}" -eq 0 ] || die "offline smoke checks failed"
	echo "PASS (offline qcow2 inspection; no host mounts, no boot performed)"
	exit 0
fi

# --- Live QEMU/KVM boot ------------------------------------------------------
[ -n "${seed}" ] || die "live boot requires a cloud-init seed ISO (or use SKIP_BOOT=1)"
[ -n "${SSH_PRIVATE_KEY}" ] || die "live boot needs SSH_PRIVATE_KEY (matching the build-time public key)"
[ -f "${SSH_PRIVATE_KEY}" ] || die "no such SSH private key: ${SSH_PRIVATE_KEY}"
command -v "${QEMU}" >/dev/null 2>&1 || die "${QEMU} is required (or use SKIP_BOOT=1)"
command -v ssh >/dev/null 2>&1 || die "openssh-client is required for live assertions"

kvm_arg=()
case "${KVM}" in
	0) note "KVM disabled: TCG emulation will be very slow (BOOT_TIMEOUT=${BOOT_TIMEOUT}s)" ;;
	1|[yY][eE][sS])
		[ -r /dev/kvm ] || die "KVM requested but /dev/kvm is unavailable"
		kvm_arg=(-enable-kvm) ;;
	auto)
		if [ -r /dev/kvm ]; then kvm_arg=(-enable-kvm)
		else die "/dev/kvm unavailable; use SKIP_BOOT=1 (QEMU is not hardware validation)"; fi ;;
	*) die "KVM must be auto, 1 or 0 (got '${KVM}')" ;;
esac

log="${work}/boot.log"
qemu_args=(
	"${kvm_arg[@]}"
	"-m" "2048" "-smp" "2" "-nographic" "-no-reboot"
	"-drive" "file=${image},if=virtio,format=qcow2"
	"-drive" "file=${seed},media=cdrom,readonly=on"
	"-netdev" "user,id=net0,hostfwd=tcp:127.0.0.1:${SSH_PORT}-:22,hostfwd=tcp:127.0.0.1:${RDP_PORT}-:3389,hostfwd=tcp:127.0.0.1:${NOVNC_PORT}-:6080"
	"-device" "virtio-net-pci,netdev=net0"
)
echo "Booting ${image} with ${QEMU} (timeout ${BOOT_TIMEOUT}s)"
"${QEMU}" "${qemu_args[@]}" > "${log}" 2>&1 &
qemu_pid=$!
cleanup_qemu() { kill "${qemu_pid}" >/dev/null 2>&1 || true; wait "${qemu_pid}" 2>/dev/null || true; }
trap 'cleanup_qemu; rm -rf "${work}"' EXIT

ssh_opts=(
	-o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=no
	-o UserKnownHostsFile="${work}/known_hosts" -o LogLevel=ERROR
	-i "${SSH_PRIVATE_KEY}" -p "${SSH_PORT}"
)
ready=0
deadline=$((SECONDS + BOOT_TIMEOUT))
while [ "${SECONDS}" -lt "${deadline}" ]; do
	if ssh "${ssh_opts[@]}" cybroid@127.0.0.1 true >/dev/null 2>&1; then
		ready=1
		break
	fi
	kill -0 "${qemu_pid}" 2>/dev/null || break
	sleep 2
done
if [ "${ready}" -ne 1 ]; then
	echo "----- serial console tail -----" >&2
	tail -n 80 "${log}" >&2 || true
	die "guest did not become reachable over SSH"
fi

ssh "${ssh_opts[@]}" cybroid@127.0.0.1 'bash -s' > "${work}/remote.out" <<'REMOTE'
set -u
. /etc/os-release
printf 'OS_ID %s\n' "${ID}"
printf 'HOSTNAME %s\n' "$(hostname)"
if grep -q 'Cybroid OS' /etc/motd; then printf 'MOTD ok\n'; else printf 'MOTD fail\n'; fi
if grep -q 'Cybroid OS' /etc/issue; then printf 'ISSUE ok\n'; else printf 'ISSUE fail\n'; fi
for pkg in xfce4 xrdp kcd cloud-init novnc openssh-server; do
	if dpkg-query -W -f='${Status}' "${pkg}" 2>/dev/null | grep -q 'install ok installed'; then
		printf 'PKG %s ok\n' "${pkg}"
	else
		printf 'PKG %s fail\n' "${pkg}"
	fi
done
for unit in ssh.service xrdp.service cloud-init.service cybroidos-kcd.service; do
	if systemctl is-enabled "${unit}" >/dev/null 2>&1; then
		printf 'UNIT %s ok\n' "${unit}"
	else
		printf 'UNIT %s fail\n' "${unit}"
	fi
done
if /usr/sbin/sshd -T 2>/dev/null | grep -q '^passwordauthentication no'; then
	printf 'SSHD password-auth disabled\n'
else
	printf 'SSHD password-auth fail\n'
fi
if passwd -S cybroid 2>/dev/null | grep -Eq ' (L|NP) '; then
	printf 'PASSWORD no-default-password\n'
else
	printf 'PASSWORD fail\n'
fi
REMOTE

out="$(cat "${work}/remote.out")"
echo "live guest assertions:"
check "os-release ID=cybroidos" "${out}" '^OS_ID cybroidos$'
check "hostname cybroid" "${out}" '^HOSTNAME cybroid$'
check "branded motd" "${out}" '^MOTD ok$'
check "branded issue" "${out}" '^ISSUE ok$'
for pkg in xfce4 xrdp kcd cloud-init novnc openssh-server; do
	check "package ${pkg} installed" "${out}" "^PKG ${pkg} ok\$"
done
for unit in ssh.service xrdp.service cloud-init.service cybroidos-kcd.service; do
	check "service ${unit} enabled" "${out}" "^UNIT ${unit} ok\$"
done
check "password SSH disabled" "${out}" '^SSHD password-auth disabled$'
check "no default password login" "${out}" '^PASSWORD no-default-password$'
check "first boot completed" "$(cat "${log}")" 'cybroidos-first-boot: complete'

[ "${fail}" -eq 0 ] || { tail -n 80 "${log}" >&2 || true; die "live smoke checks failed"; }
echo "PASS (QEMU/KVM boot + cloud-init + branding/services/security assertions)"
echo "NOTE: QEMU does not validate real hardware or GPU/RDP client behaviour."
