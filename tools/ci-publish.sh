#!/usr/bin/env bash
# Publishes CybroidOS's packages (dist/ and dist/extra, built first by
# tools/build-extras.sh) to deb.cybroid.com/cybroid, signed with the archive
# key, when deb.cybroid.com doesn't have this version yet (or FORCE=true).
# Raising the version in brand.toml is a release.
#
# Env (CI secrets): SIGNING_KEY (the archive key, armoured, no passphrase),
# PUBLISH_KEY (an SSH key the server lets write only to /srv/deb-cybroid/cybroid,
# through rrsync), KNOWN_HOSTS (the server's host key), FORCE.
# Needs reprepro, rsync, gpg. The keys live in a temporary folder, removed at
# the end: a self-hosted runner keeps nothing.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -n "${SIGNING_KEY:-}" ] && [ -n "${PUBLISH_KEY:-}" ] || { echo "::warning::No CYBROID_APT_* secrets: packages not published"; exit 0; }
version="$(python3 -c 'import tomllib; print(tomllib.load(open("common/branding/brand.toml","rb"))["identity"]["version"])')"
have="$(curl -fsSL --retry 5 --retry-all-errors --retry-delay 10 https://deb.cybroid.com/cybroid/dists/trixie/main/binary-amd64/Packages 2>/dev/null |
	awk '/^Package: cybroid-plasma$/{p=1;next} p&&/^Version:/{print $2;exit}')"
if [ "${have}" = "${version}" ] && [ "${FORCE:-}" != true ]; then
	echo "deb.cybroid.com already has ${version}"; exit 0
fi

keys="$(mktemp -d)"
trap 'rm -rf "${keys}" apt-repo/db apt-repo/published' EXIT
export GNUPGHOME="${keys}/gnupg"
install -m 700 -d "${GNUPGHOME}"
printf '%s\n' "${SIGNING_KEY}" | gpg --batch --quiet --import
printf '%s\n' "${PUBLISH_KEY}" > "${keys}/publish" && chmod 600 "${keys}/publish"
printf '%s\n' "${KNOWN_HOSTS}" > "${keys}/known_hosts"

# Every package, from scratch: the server's copy is replaced as a whole.
rm -rf apt-repo/db apt-repo/published
tools/build-package.sh --all >/dev/null
debs="$(ls dist/*_"${version}"_all.deb; ls dist/extra/*.deb | grep -v onlyoffice)"
tools/publish-apt-repo.sh ${debs}
cp "dist/cybroid-sources_${version}_all.deb" apt-repo/published/cybroid-sources.deb
rsync -rlt --delete -e "ssh -i ${keys}/publish -o IdentitiesOnly=yes -o UserKnownHostsFile=${keys}/known_hosts -o StrictHostKeyChecking=yes" \
	apt-repo/published/ debpublish@deb.cybroid.com:/
curl -fsSL https://deb.cybroid.com/cybroid/dists/trixie/InRelease | head -12
