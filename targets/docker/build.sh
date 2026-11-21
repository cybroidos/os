#!/usr/bin/env bash
# Build the Cybroid OS pod/container images (ADR-0005).
#
# Images:
#   cybroidos-pod-base             debian:trixie-slim + branding + kcd + SSH
#   cybroidos-pod-dev-<stack>      headless devcontainer (generic, python, node)
#   cybroidos-pod-desktop          Xfce 4.20 + xrdp + noVNC + kcd
#
# Branding (version, hostname) comes from common/branding/brand.toml. The
# cybroidos-base .deb is built with tools/build-package.sh and staged into each
# build context under targets/docker/.context/ before docker buildx runs.
#
# Requirements: python3, dpkg-buildpackage tooling, and either docker with the
# buildx plugin or podman. Cross-arch builds need binfmt/QEMU registered.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${here}/../.." && pwd)"
brand="${repo_root}/common/branding/brand.toml"
stacks_json="${here}/dev/stacks.json"
devcontainer_json="${here}/dev/devcontainer.json"

die() { echo "error: $*" >&2; exit 1; }
note() { echo "==> $*"; }

usage() {
	cat <<'EOF'
Usage: targets/docker/build.sh [options] [image ...]

Images: base, dev, desktop (default: all)
Options:
  --arch ARCH       Build for amd64 or arm64 (repeatable; default: both)
  --stack STACK     Dev stack: generic, python, node (repeatable; default: all)
  --push            Push to REGISTRY (same as PUSH=1)
  --no-push         Load into the local engine only (same as PUSH=0)
  -h, --help        Show this help

Environment:
  PUSH=0|1          Push result (default: 0)
  TAG=...           Image tag (default: version from brand.toml)
  EDITION=...       Edition metadata/tag suffix (default: core)
  REGISTRY=...      Registry prefix (default: ghcr.io/cybroidtech)
  REBUILD_PACKAGE=1 Force a rebuild of the cybroidos-base .deb

Examples:
  targets/docker/build.sh --arch amd64
  targets/docker/build.sh --stack python dev
  PUSH=1 targets/docker/build.sh
EOF
}

# Normalise PUSH early so callers can use 0/1/true/false/yes/no.
PUSH="${PUSH:-0}"
case "${PUSH}" in
	1|true|TRUE|yes|YES|on|ON) PUSH=1 ;;
	0|false|FALSE|no|NO|off|OFF) PUSH=0 ;;
	*) die "PUSH must be 0 or 1 (got '${PUSH}')" ;;
esac

REGISTRY="${REGISTRY:-ghcr.io/cybroidtech}"
EDITION="${EDITION:-core}"
export RELEASE="${RELEASE:-trixie}"

[ -f "${brand}" ] || die "missing brand file: ${brand}"
[ -f "${stacks_json}" ] || die "missing stack catalogue: ${stacks_json}"

read -r brand_version brand_hostname < <(python3 - "${brand}" <<'PY'
import sys
import tomllib

identity = tomllib.load(open(sys.argv[1], "rb"))["identity"]
print(identity["version"], identity["default_hostname"])
PY
)
[ -n "${brand_version}" ] || die "could not read version from ${brand}"
[ -n "${brand_hostname}" ] || die "could not read default_hostname from ${brand}"

TAG="${TAG:-${brand_version}}"

arches=()
stacks=()
images=()
stacks_requested=0

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
		--stack)
			[ "$#" -ge 2 ] || die "--stack needs a value"
			stacks+=("$2")
			stacks_requested=1
			shift 2
			;;
		--stack=*)
			stacks+=("${1#*=}")
			stacks_requested=1
			shift
			;;
		--push) PUSH=1; shift ;;
		--no-push) PUSH=0; shift ;;
		-h|--help) usage; exit 0 ;;
		-*) die "unknown option: $1" ;;
		*) images+=("$1"); shift ;;
	esac
done

[ "${#arches[@]}" -gt 0 ] || arches=(amd64 arm64)
mapfile -t available_stacks < <(python3 - "${stacks_json}" <<'PY'
import json
import sys

print("\n".join(json.load(open(sys.argv[1]))["stacks"].keys()))
PY
)
if [ "${stacks_requested}" -eq 0 ]; then
	stacks=("${available_stacks[@]}")
fi

for arch in "${arches[@]}"; do
	case "${arch}" in
		amd64|arm64) ;;
		*) die "unsupported architecture '${arch}' (expected amd64 or arm64)" ;;
	esac
done
for stack in "${stacks[@]}"; do
	case " ${available_stacks[*]} " in
		*" ${stack} "*) ;;
		*) die "unknown stack '${stack}' (expected: ${available_stacks[*]})" ;;
	esac
done
[ "${#images[@]}" -gt 0 ] || images=(base dev desktop)
for image in "${images[@]}"; do
	case "${image}" in
		base|dev|desktop) ;;
		*) die "unknown image '${image}' (expected base, dev or desktop)" ;;
	esac
done

edition_config="${repo_root}/editions/${EDITION}/config"
[ -f "${edition_config}" ] || die "unknown edition '${EDITION}' (expected ${edition_config})"

# Build the shared branding package once, then stage a copy into every context.
deb="${repo_root}/dist/cybroidos-base_${brand_version}_all.deb"
if [ ! -f "${deb}" ] || [ "${REBUILD_PACKAGE:-0}" = 1 ]; then
	note "Building cybroidos-base ${brand_version}"
	"${repo_root}/tools/build-package.sh" cybroidos-base
fi
[ -f "${deb}" ] || die "missing staged package: ${deb}"

engine=""
if command -v docker >/dev/null 2>&1 && docker buildx version >/dev/null 2>&1; then
	engine=docker
elif command -v podman >/dev/null 2>&1; then
	engine=podman
else
	die "docker with buildx, or podman, is required"
fi
note "Using ${engine} (PUSH=${PUSH}, EDITION=${EDITION}, TAG=${TAG})"

image_name() {
	local image="$1" stack="${2:-}"
	if [ "${image}" = dev ]; then
		printf 'cybroidos-pod-dev-%s' "${stack}"
	else
		printf 'cybroidos-pod-%s' "${image}"
	fi
}

image_ref() {
	local image="$1" stack="${2:-}"
	printf '%s/%s:%s' "${REGISTRY}" "$(image_name "${image}" "${stack}")" "${TAG}"
}

stage_context() {
	local image="$1" stack="${2:-}"
	local context="${here}/.context/${image}"

	mkdir -p "${context}"
	install -m 0644 "${deb}" "${context}/cybroidos-base.deb"
	rm -rf "${context}/config"
	cp -a "${here}/config" "${context}/config"

	case "${image}" in
		base)
			cp "${here}/base/Dockerfile" "${context}/Dockerfile"
			;;
		dev)
			cp "${here}/dev/Dockerfile" "${context}/Dockerfile"
			cp "${here}/dev/devcontainer.json" "${context}/devcontainer.json"
			python3 - "${stack}" "${stacks_json}" > "${context}/stack-packages.txt" <<'PY'
import json
import sys

stack = sys.argv[1]
packages = json.load(open(sys.argv[2]))["stacks"][stack]["packages"]
print("\n".join(packages))
PY
			;;
		desktop)
			cp "${here}/desktop/Dockerfile" "${context}/Dockerfile"
			# Same branded Xfce theme as the ISO/server. Rendered from
			# brand.toml so the image tag/version stays single-sourced.
			python3 "${repo_root}/tools/render-xfce-brand.py" \
				--brand "${brand}" --release "${RELEASE}" \
				--out "${context}/config/xfce" >/dev/null
			;;
	esac
}

render_devcontainer_metadata() {
	local stack="$1" ref="$2"
	python3 - "${stack}" "${ref}" "${devcontainer_json}" "${stacks_json}" <<'PY'
import json
import sys

stack, ref, template_path, stacks_path = sys.argv[1:5]
template = json.load(open(template_path))
entry = json.load(open(stacks_path))["stacks"][stack]
metadata = dict(template)
metadata.pop("build", None)
metadata["name"] = entry["name"]
metadata["description"] = entry["description"]
metadata["image"] = ref
metadata["remoteUser"] = "cybroid"
print(json.dumps([metadata], separators=(",", ":")))
PY
}

build_with_docker() {
	local image="$1" stack="${2:-}"
	local context="${here}/.context/${image}"
	local ref edition_ref metadata platform_list arch
	local -a args tag_args local_tag_args

	ref="$(image_ref "${image}" "${stack}")"
	edition_ref="${ref}-${EDITION}"

	args=(
		--file "${context}/Dockerfile"
		--build-arg "VERSION=${TAG}"
		--build-arg "HOSTNAME=${brand_hostname}"
		--build-arg "EDITION=${EDITION}"
		--label "org.opencontainers.image.title=$(image_name "${image}" "${stack}")"
		--label "org.opencontainers.image.version=${TAG}"
		--label "org.cybroidos.edition=${EDITION}"
		--label "org.cybroidos.vendor=Cybroid Technologies (U) Ltd"
		--label "org.cybroidos.stack=${stack:-none}"
	)
	if [ "${image}" = dev ]; then
		metadata="$(render_devcontainer_metadata "${stack}" "${ref}")"
		args+=(
			--build-arg "STACK=${stack}"
			--build-arg "DEVCONTAINER_METADATA=${metadata}"
		)
	fi

	if [ "${PUSH}" -eq 1 ]; then
		tag_args=(--tag "${ref}" --tag "${edition_ref}")
		if [ "${#arches[@]}" -gt 1 ]; then
			platform_list="$(local IFS=,; printf '%s' "${arches[*]/#/linux/}")"
			note "Building and pushing ${ref} for ${platform_list}"
			docker buildx build --platform "${platform_list}" \
				"${args[@]}" "${tag_args[@]}" --push "${context}"
		else
			arch="${arches[0]}"
			note "Building and pushing ${ref} for linux/${arch}"
			docker buildx build --platform "linux/${arch}" \
				"${args[@]}" "${tag_args[@]}" \
				--tag "${ref}-${arch}" --tag "${edition_ref}-${arch}" \
				--push "${context}"
		fi
	else
		for arch in "${arches[@]}"; do
			local_tag_args=(
				--tag "${ref}-${arch}"
				--tag "${edition_ref}-${arch}"
			)
			note "Building ${ref}-${arch}"
			docker buildx build --platform "linux/${arch}" \
				"${args[@]}" "${local_tag_args[@]}" --load "${context}"
		done
	fi
}

build_with_podman() {
	local image="$1" stack="${2:-}"
	local context="${here}/.context/${image}"
	local ref edition_ref metadata arch
	local -a args tag_args

	ref="$(image_ref "${image}" "${stack}")"
	edition_ref="${ref}-${EDITION}"

	args=(
		--file "${context}/Dockerfile"
		--build-arg "VERSION=${TAG}"
		--build-arg "HOSTNAME=${brand_hostname}"
		--build-arg "EDITION=${EDITION}"
		--label "org.opencontainers.image.title=$(image_name "${image}" "${stack}")"
		--label "org.opencontainers.image.version=${TAG}"
		--label "org.cybroidos.edition=${EDITION}"
		--label "org.cybroidos.vendor=Cybroid Technologies (U) Ltd"
		--label "org.cybroidos.stack=${stack:-none}"
	)
	if [ "${image}" = dev ]; then
		metadata="$(render_devcontainer_metadata "${stack}" "${ref}")"
		args+=(
			--build-arg "STACK=${stack}"
			--build-arg "DEVCONTAINER_METADATA=${metadata}"
		)
	fi

	for arch in "${arches[@]}"; do
		tag_args=(--tag "${ref}-${arch}" --tag "${edition_ref}-${arch}")
		if [ "${PUSH}" -eq 1 ] && [ "${#arches[@]}" -eq 1 ]; then
			tag_args+=(--tag "${ref}" --tag "${edition_ref}")
		fi
		note "Building ${ref}-${arch} with podman"
		podman build --platform "linux/${arch}" \
			"${args[@]}" "${tag_args[@]}" "${context}"
		if [ "${PUSH}" -eq 1 ]; then
			podman push "${ref}-${arch}"
			podman push "${edition_ref}-${arch}"
			if [ "${#arches[@]}" -eq 1 ]; then
				podman push "${ref}"
				podman push "${edition_ref}"
			fi
		fi
	done
	if [ "${PUSH}" -eq 1 ] && [ "${#arches[@]}" -gt 1 ]; then
		note "podman fallback pushes per-arch tags only; use docker buildx for a multi-arch manifest"
	fi
}

for image in "${images[@]}"; do
	if [ "${image}" = dev ]; then
		for stack in "${stacks[@]}"; do
			stage_context "${image}" "${stack}"
			if [ "${engine}" = docker ]; then
				build_with_docker "${image}" "${stack}"
			else
				build_with_podman "${image}" "${stack}"
			fi
		done
	else
		stage_context "${image}"
		if [ "${engine}" = docker ]; then
			build_with_docker "${image}"
		else
			build_with_podman "${image}"
		fi
	fi
done

note "Done. Images are named cybroidos-pod-* (edition suffix: ${EDITION})."
