#!/usr/bin/env bash
# Install the toolchain for one headless dev stack.
# The package list is generated from targets/docker/dev/stacks.json by
# targets/docker/build.sh and staged into the build context.
set -euo pipefail

package_file="/usr/local/lib/cybroidos/stack-packages.txt"

die() { echo "error: $*" >&2; exit 1; }

main() {
	[ "$#" -eq 1 ] || die "usage: cybroid-install-stack STACK"
	local stack="$1"
	case "${stack}" in
		generic|python|node) ;;
		*) die "unknown stack '${stack}'" ;;
	esac
	[ -r "${package_file}" ] || die "missing ${package_file}"

	local -a packages=()
	mapfile -t packages < "${package_file}"
	[ "${#packages[@]}" -gt 0 ] || die "${package_file} is empty"

	local -a common=(
		build-essential cmake pkg-config git curl wget ca-certificates
		jq less procps vim-tiny python3 python3-venv openssh-client sudo
	)

	apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		"${common[@]}" "${packages[@]}"
	rm -rf /var/lib/apt/lists/*
	echo "installed dev stack '${stack}'"
}

main "$@"
