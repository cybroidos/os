#!/usr/bin/env bash
# Render and package a cloud-init NoCloud seed ISO from the checked-in templates.
#
# Usage: render-seed.sh CONFIG_DIR PUBKEY_FILE VERSION HOSTNAME SEED_DIR SEED_ISO ISO_TOOL
# The SSH key comes from a file; no key is ever hardcoded in this repository.
set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$#" -eq 7 ] || die "usage: $0 CONFIG_DIR PUBKEY_FILE VERSION HOSTNAME SEED_DIR SEED_ISO ISO_TOOL"
config_dir="$1"; pubkey_file="$2"; version="$3"; hostname="$4"
seed_dir="$5"; seed_iso="$6"; iso_tool="$7"
[ -f "${config_dir}/user-data.tmpl" ] || die "missing user-data.tmpl in ${config_dir}"
[ -f "${config_dir}/meta-data.tmpl" ] || die "missing meta-data.tmpl in ${config_dir}"
[ -f "${pubkey_file}" ] || die "SSH public key not found: ${pubkey_file}"
mkdir -p "${seed_dir}"

echo "Rendering cloud-init seed (key from ${pubkey_file})"
python3 - "${config_dir}/user-data.tmpl" "${config_dir}/meta-data.tmpl" \
	"${pubkey_file}" "${version}" "${hostname}" \
	"${seed_dir}/user-data" "${seed_dir}/meta-data" <<'PY'
import json
import pathlib
import sys

user_tmpl, meta_tmpl, key_file, version, hostname, user_out, meta_out = sys.argv[1:]
key = " ".join(pathlib.Path(key_file).read_text().split())
if not key.startswith(("ssh-", "ecdsa-", "sk-")):
    sys.exit(f"error: no OpenSSH public key in {key_file}")

user = pathlib.Path(user_tmpl).read_text()
for token, value in (
    ("__CYBROIDOS_SSH_PUBLIC_KEY__", json.dumps(key)),
    ("__CYBROIDOS_VERSION__", version),
    ("__CYBROIDOS_HOSTNAME__", hostname),
):
    user = user.replace(token, value)
if "__CYBROIDOS" in user:
    sys.exit("error: unrendered placeholder left in user-data")
for required in ("#cloud-config", f"hostname: {hostname}", "ssh_authorized_keys", "runcmd", "cybroidos-first-boot"):
    if required not in user:
        sys.exit(f"error: user-data is missing {required!r}")
pathlib.Path(user_out).write_text(user)

meta = pathlib.Path(meta_tmpl).read_text()
meta = meta.replace("__CYBROIDOS_VERSION__", version).replace("__CYBROIDOS_HOSTNAME__", hostname)
if "__CYBROIDOS" in meta or "instance-id:" not in meta:
    sys.exit("error: meta-data template was not rendered correctly")
pathlib.Path(meta_out).write_text(meta)

# Optional strict validation when PyYAML is installed; basic checks above are
# the fallback on hosts without it.
try:
    import yaml
except ImportError:
    print("note: PyYAML unavailable; skipped YAML parse (basic sanity passed)")
else:
    doc = yaml.safe_load(user)
    if not isinstance(doc, dict) or doc.get("hostname") != hostname:
        sys.exit("error: user-data did not parse as a cloud-config mapping")
    print("cloud-init user-data parsed successfully")
PY

case "${iso_tool}" in
	genisoimage)
		genisoimage -quiet -output "${seed_iso}" -volid cidata \
			-joliet -rock "${seed_dir}/user-data" "${seed_dir}/meta-data" ;;
	xorriso)
		xorriso -as mkisofs -output "${seed_iso}" -volid cidata \
			-joliet -rock "${seed_dir}/user-data" "${seed_dir}/meta-data" ;;
	*) die "unsupported ISO tool: ${iso_tool}" ;;
esac
[ -s "${seed_iso}" ] || die "seed ISO was not created: ${seed_iso}"
echo "Seed ISO written to ${seed_iso} (volume id cidata)"
