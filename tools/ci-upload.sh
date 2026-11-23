#!/usr/bin/env bash
# Uploads a built image from out/ to Hangar's storage (SeaweedFS, S3 at S3_URL,
# bucket BUCKET) with its sha256, under the key Hangar's image catalogue
# fetches it by (internal/pve/images.go).
#
# Usage: tools/ci-upload.sh <vm|desktop|container|iso>
# Env: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (CI secrets), S3_URL, BUCKET,
# COMMIT; the aws CLI, or docker (then the amazon/aws-cli image).
set -euo pipefail
cd "$(dirname "$0")/.."
image="${1:?usage: $0 <vm|desktop|container|iso>}"

[ -n "${AWS_ACCESS_KEY_ID:-}" ] || { echo "::warning::No CITOS_IMAGES_KEY_ID secret: built but not uploaded"; exit 0; }
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
# Its settings in a temporary folder: a self-hosted runner keeps nothing.
conf="$(mktemp -d)"
trap 'rm -rf "${conf}"' EXIT
export AWS_CONFIG_FILE="${conf}/config"
# Hangar's storage is at home, behind Cloudflare, which gives up on a request
# after 100 s (error 524): the classic transfer engine (no minimum speed),
# small parts, one at a time, and a failed part is sent again by itself
# (max_attempts) instead of the whole 2 GB file starting over.
cat > "${AWS_CONFIG_FILE}" <<CONF
[default]
retry_mode = standard
max_attempts = 10
s3 =
  preferred_transfer_client = classic
  max_concurrent_requests = 1
  multipart_chunksize = 8MB
CONF
if command -v aws >/dev/null; then
	aws() { command aws "$@"; }
else
	aws() {
		docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION -e AWS_CONFIG_FILE=/conf/config \
			-v "${conf}:/conf:ro" -v "${PWD}/out:${PWD}/out" -w "${PWD}" amazon/aws-cli:2.27.0 "$@"
	}
fi
s3() { for try in 1 2 3; do aws --endpoint-url "${S3_URL}" --cli-read-timeout 300 s3 "$@" && return 0; echo "upload try ${try} failed, retrying"; sleep 60; done; return 1; }

case "${image}" in
iso) f=$(ls out/cybroidos-desktop-*-amd64.iso); key=iso/cybroidos-desktop-amd64.iso ;;
vm) f=$(ls out/cybroid-server-*-amd64.qcow2); key=server/citos-server-amd64.qcow2 ;;
desktop) f=$(ls out/cybroid-desktop-*-amd64.qcow2); key=desktop/citos-desktop-amd64.qcow2 ;;
container) f=$(ls out/cybroid-server_*_amd64.tar.zst); key=server/citos-server_amd64.tar.zst ;;
*) echo "unknown image: ${image}" >&2; exit 2 ;;
esac
sum=$(sha256sum "${f}" | cut -d' ' -f1)
s3 cp --only-show-errors "${f}" "s3://${BUCKET}/${key}" --metadata "sha256=${sum},commit=${COMMIT:-}"
echo "${sum}  $(basename "${key}")" > "${f}.sha256"
s3 cp --only-show-errors "${f}.sha256" "s3://${BUCKET}/${key}.sha256"
# The release manifest (checksums and the ISO's packages), when there is one.
if [ -f "${f%.*}.manifest.md" ]; then
	s3 cp --only-show-errors "${f%.*}.manifest.md" "s3://${BUCKET}/${key%.*}.manifest.md"
fi
echo "Uploaded ${key} ($(du -h "${f}" | cut -f1), sha256 ${sum})" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
