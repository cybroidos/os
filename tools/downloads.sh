#!/usr/bin/env bash
# CybroidOS downloads: the latest releases in the downloads store (an Appwrite
# bucket, or Cloudflare R2), every older one on the Internet Archive, every
# version's notes, checksums and links on GitHub Releases. Nothing leaves the
# store before a verified copy is on the Internet Archive.
#
#   tools/downloads.sh publish <file>...   put a release's files (ISOs with their
#                                          .sha256 and .manifest.md) in the store under
#                                          releases/<version>/, then rebuild the index
#   tools/downloads.sh index               rebuild latest.json, releases.json and
#                                          each release's index.html from the store
#   tools/downloads.sh retire              move releases beyond the newest KEEP to
#                                          the Internet Archive (item cybroidos-<version>)
#
# Env: STORE: appwrite (when APPWRITE_KEY is set) or r2.
#      appwrite: APPWRITE_ENDPOINT, APPWRITE_PROJECT, APPWRITE_KEY, APPWRITE_BUCKET,
#      APPWRITE_PUBLIC_ENDPOINT (see tools/appwrite-store.py).
#      r2: R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET,
#      DOWNLOAD_URL (https://download.cybroid.com).
#      KEEP (2)
#      retire also: IA_ACCESS_KEY, IA_SECRET_KEY (archive.org S3 keys),
#      GH_TOKEN and GH_REPO (cybroidos/os) to point each release's notes at its
#      new home.
# Needs python3 and curl; r2 also aws (or docker for the amazon/aws-cli
# image); retire also gh.
set -euo pipefail
cd "$(dirname "$0")/.."

cmd="${1:?usage: $0 publish <file>... | index | retire}"
shift
STORE="${STORE:-$([ -n "${APPWRITE_KEY:-}" ] && echo appwrite || echo r2)}"
DOWNLOAD_URL="${DOWNLOAD_URL:-https://download.cybroid.com}"
KEEP="${KEEP:-2}"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# The store: list (S3's list-objects JSON), put <file> <key> <type> <cache>,
# get <key> <dest> ("-" for stdout), rm <key>, rm_prefix <prefix>.
if [ "${STORE}" = appwrite ]; then
: "${APPWRITE_PROJECT:?}" "${APPWRITE_KEY:?}"
export APPWRITE_ENDPOINT APPWRITE_PROJECT APPWRITE_KEY APPWRITE_BUCKET APPWRITE_PUBLIC_ENDPOINT
aw() { python3 "${PWD}/tools/appwrite-store.py" "$@"; }
store_list() { aw list; }
store_put() { aw put "$1" "$2"; }   # Appwrite sets its own type and caching
store_get() {
	if [ "$2" = - ]; then aw get "$1" "${work}/get.tmp" && cat "${work}/get.tmp"; else aw get "$1" "$2"; fi
}
store_rm_prefix() {
	python3 -c "import json,sys; print('\n'.join(o['Key'] for o in json.load(sys.stdin)['Contents'] if o['Key'].startswith(sys.argv[1])))" "$1" < <(aw list) |
		while IFS= read -r k; do [ -n "$k" ] && aw rm "$k"; done
}
else
: "${R2_ENDPOINT:?}" "${R2_ACCESS_KEY_ID:?}" "${R2_SECRET_ACCESS_KEY:?}" "${R2_BUCKET:?}"
export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}" AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}" AWS_DEFAULT_REGION=auto
export AWS_CONFIG_FILE="${work}/aws-config"
printf '[default]\nretry_mode = standard\nmax_attempts = 10\ns3 =\n  multipart_chunksize = 64MB\n' > "${AWS_CONFIG_FILE}"
if command -v aws >/dev/null; then
	aws() { command aws "$@"; }
else
	aws() {
		docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION -e AWS_CONFIG_FILE=/conf/aws-config \
			-v "${work}:/conf:ro" -v "${work}:${work}" -v "${PWD}:${PWD}" -w "${PWD}" amazon/aws-cli:2.27.0 "$@"
	}
fi
s3() { aws --endpoint-url "${R2_ENDPOINT}" s3 "$@"; }
store_list() { aws --endpoint-url "${R2_ENDPOINT}" s3api list-objects-v2 --bucket "${R2_BUCKET}" --prefix "" --output json; }
store_put() { s3 cp --quiet --content-type "$3" --cache-control "$4" "$1" "s3://${R2_BUCKET}/$2"; }
store_get() { s3 cp --quiet "s3://${R2_BUCKET}/$1" "$2"; }
store_rm_prefix() { s3 rm --quiet --recursive "s3://${R2_BUCKET}/$1"; }
fi

# The version in a file's name: cybroidos-<edition>-<version>-amd64.iso…
version_of() { basename "$1" | sed -nE 's/^cybroidos-[a-z]+-([0-9]+\.[0-9]+\.[0-9]+)-amd64\..*$/\1/p'; }

# Every file in the store with its size, and the .sha256 files' contents, as JSON for
# index.py.
listing() {
	store_list > "${work}/list.json"
	python3 - "${work}/list.json" > "${work}/sums.txt" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
for o in d.get("Contents", []):
    if o["Key"].endswith(".sha256"):
        print(o["Key"])
PY
	: > "${work}/sums.json.txt"
	while IFS= read -r key; do
		store_get "${key}" - | head -1 | awk -v k="${key}" '{print k "\t" $1}' >> "${work}/sums.json.txt"
	done < "${work}/sums.txt"
}

index() {
	listing
	python3 - "${work}/list.json" "${work}/sums.json.txt" "${DOWNLOAD_URL}" "${work}/out" "${STORE}" <<'PY'
import html, json, os, re, sys
listing, sums_file, base, out, store = sys.argv[1:]
objs = json.load(open(listing)).get("Contents", [])
# Appwrite's addresses come with the listing; R2's are the key under the domain.
urls = {o["Key"]: o.get("Url") or f"{base}/{o['Key']}" for o in objs}
sums = dict(l.rstrip("\n").split("\t") for l in open(sums_file) if "\t" in l)
names = {"desktop": "CybroidOS", "security": "CybroidOS Security", "developer": "CybroidOS Developer",
         "network": "CybroidOS Network", "engineering": "CybroidOS Engineering", "classroom": "CybroidOS Classroom"}
releases = {}
for o in objs:
    m = re.match(r"^releases/([0-9]+\.[0-9]+\.[0-9]+)/(cybroidos-([a-z]+)-[0-9.]+-amd64\.iso)$", o["Key"])
    if not m:
        continue
    v, f, ed = m.groups()
    releases.setdefault(v, []).append({
        "edition": ed, "name": names.get(ed, "CybroidOS " + ed.title()), "file": f,
        "url": urls[o["Key"]], "size": o["Size"],
        "sha256": sums.get(f"releases/{v}/{f}.sha256", ""),
        "checksum": urls.get(f"releases/{v}/{f}.sha256", ""),
        "manifest": urls.get(f"releases/{v}/{f[:-4]}.manifest.md", ""),
        "date": o["LastModified"][:10]})
key = lambda v: tuple(int(x) for x in v.split("."))
order = ["desktop", "security", "developer", "network", "engineering", "classroom"]
versions = []
for v in sorted(releases, key=key, reverse=True):
    files = sorted(releases[v], key=lambda f: order.index(f["edition"]) if f["edition"] in order else 99)
    versions.append({"version": v, "date": max(f["date"] for f in files), "files": files,
                     "notes": f"https://github.com/cybroidos/os/releases/tag/v{v}",
                     # Appwrite serves HTML as text, so there the notes are the page.
                     "page": f"{base}/releases/{v}/index.html" if store == "r2" else f"https://github.com/cybroidos/os/releases/tag/v{v}"})
os.makedirs(out, exist_ok=True)
json.dump({"versions": versions, "older": "https://github.com/cybroidos/os/releases"}, open(f"{out}/releases.json", "w"), indent=1)
json.dump(versions[0] if versions else {}, open(f"{out}/latest.json", "w"), indent=1)
for r in versions if store == "r2" else []:
    rows = "".join(
        f'<tr><td>{html.escape(f["name"])}</td><td><a href="{html.escape(f["url"])}">{html.escape(f["file"])}</a></td>'
        f'<td>{f["size"] / 1e9:.1f} GB</td><td><code>{f["sha256"]}</code></td>'
        f'<td><a href="{html.escape(f["manifest"])}">packages</a></td></tr>' for f in r["files"])
    page = f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>CybroidOS {r['version']}</title>
<style>body{{font:15px/1.5 system-ui,sans-serif;max-width:60rem;margin:2rem auto;padding:0 1rem;color:#0b1a33}}
table{{border-collapse:collapse;width:100%}}td,th{{text-align:left;padding:.5rem;border-bottom:1px solid #d6deeb;vertical-align:top}}
code{{font-size:.8em;word-break:break-all}}</style>
<h1>CybroidOS {r['version']}</h1>
<p>Released {r['date']}. <a href="{r['notes']}">What's new</a> · <a href="https://github.com/cybroidos/os/blob/v{r['version']}/docs/user/INSTALL.md">Installing</a> ·
Check a download with <code>sha256sum</code> against the value below.</p>
<table><tr><th>Edition</th><th>File</th><th>Size</th><th>SHA-256</th><th></th></tr>{rows}</table>
<p><a href="https://cybroid.com/cybroidos">cybroid.com/cybroidos</a> · <a href="https://github.com/cybroidos/os/releases">Every version</a></p>
</html>
"""
    os.makedirs(f"{out}/releases/{r['version']}", exist_ok=True)
    open(f"{out}/releases/{r['version']}/index.html", "w").write(page)
PY
	# Short-lived caching for the index, so a new release shows within minutes.
	store_put "${work}/out/releases.json" releases.json application/json "public, max-age=300"
	store_put "${work}/out/latest.json" latest.json application/json "public, max-age=300"
	for p in "${work}"/out/releases/*/index.html; do
		[ -f "$p" ] || continue
		store_put "$p" "${p#"${work}/out/"}" "text/html; charset=utf-8" "public, max-age=300"
	done
	echo "index: $(python3 -c 'import json,sys; print(" ".join(v["version"] for v in json.load(open(sys.argv[1]))["versions"]) or "no releases")' "${work}/out/releases.json")"
}

publish() {
	[ "$#" -gt 0 ] || { echo "publish: no files" >&2; exit 2; }
	local files=()
	for f in "$@"; do
		[ -f "$f" ] || { echo "publish: no such file: $f" >&2; exit 1; }
		case "$f" in *.sha256) continue ;; esac   # made here, with the file's own name
		files+=("$f")
		if [[ "$f" == *.iso ]]; then
			(cd "$(dirname "$f")" && sha256sum "$(basename "$f")") > "${work}/$(basename "$f").sha256"
			files+=("${work}/$(basename "$f").sha256")
		fi
	done
	for f in "${files[@]}"; do
		v="$(version_of "$f")"
		[ -n "$v" ] || { echo "publish: not a CybroidOS release file: $f" >&2; exit 1; }
		case "$f" in *.iso) type=application/x-iso9660-image ;; *.md) type="text/markdown; charset=utf-8" ;; *) type="text/plain; charset=utf-8" ;; esac
		# Released files never change: browsers and Cloudflare may keep them.
		store_put "$f" "releases/${v}/$(basename "$f")" "$type" "public, max-age=31536000, immutable"
		echo "published releases/${v}/$(basename "$f")"
	done
	index
}

# One file to the Internet Archive, then checked there: the archive's own MD5
# of it must match ours. Returns non-zero until it does (the archive takes a
# while to register an upload; the next run carries on).
ia_put() {
	local item="$1" file="$2" v="$3" md5
	md5="$(md5sum "$file" | cut -d' ' -f1)"
	if curl -fsS "https://archive.org/metadata/${item}/files" | python3 -c "
import json,sys; fs={f['name']:f.get('md5') for f in json.load(sys.stdin).get('result',[])}; sys.exit(0 if fs.get(sys.argv[1])==sys.argv[2] else 1)" "$(basename "$file")" "$md5" 2>/dev/null; then
		echo "  already on the archive: $(basename "$file")"
		return 0
	fi
	curl -fsS --retry 5 --retry-delay 30 -T "$file" "https://s3.us.archive.org/${item}/$(basename "$file")" \
		-H "authorization: LOW ${IA_ACCESS_KEY}:${IA_SECRET_KEY}" \
		-H "x-archive-auto-make-bucket: 1" -H "x-archive-queue-derive: 0" \
		-H "x-archive-size-hint: $(stat -c %s "$file")" \
		-H "x-archive-meta-mediatype: software" \
		-H "x-archive-meta-collection: open_source_software" \
		-H "x-archive-meta-title: CybroidOS ${v}" \
		-H "x-archive-meta-creator: Cybroid Technologies (U) Ltd" \
		-H "x-archive-meta-date: $(date -u +%Y)" \
		-H "x-archive-meta-subject: CybroidOS; Linux; operating system; Debian; KDE Plasma" \
		-H "x-archive-meta-licenseurl: https://www.gnu.org/licenses/gpl-3.0.html" \
		-H "x-archive-meta-description: CybroidOS ${v}, installer ISOs, checksums and package manifests. Unsupported: install the latest version from https://cybroid.com/cybroidos, or install this one and update. Source: https://github.com/cybroidos/os/releases/tag/v${v}" >/dev/null
	echo "  uploaded to the archive: $(basename "$file")"
	return 1
}

retire() {
	: "${IA_ACCESS_KEY:?}" "${IA_SECRET_KEY:?}"
	listing
	mapfile -t versions < <(python3 - "${work}/list.json" <<'PY'
import json, re, sys
vs = {m.group(1) for o in json.load(open(sys.argv[1])).get("Contents", []) if (m := re.match(r"^releases/([0-9]+\.[0-9]+\.[0-9]+)/", o["Key"]))}
for v in sorted(vs, key=lambda v: tuple(map(int, v.split("."))), reverse=True):
    print(v)
PY
)
	damaged=0
	if [ "${#versions[@]}" -le "${KEEP}" ]; then
		echo "retire: ${#versions[@]} release(s) in the store, keeping up to ${KEEP}: nothing to move"
		return 0
	fi
	for v in "${versions[@]:${KEEP}}"; do
		item="cybroidos-${v}"
		echo "retire ${v} -> https://archive.org/details/${item}"
		done_all=1
		mapfile -t keys < <(python3 -c "
import json,sys; print('\n'.join(o['Key'] for o in json.load(open(sys.argv[1])).get('Contents',[]) if o['Key'].startswith('releases/'+sys.argv[2]+'/') and not o['Key'].endswith('index.html')))" "${work}/list.json" "$v")
		for key in "${keys[@]}"; do
			f="${work}/$(basename "$key")"
			store_get "${key}" "$f"
			# An ISO must still match its published checksum before it is copied.
			if [[ "$key" == *.iso ]]; then
				want="$(store_get "${key}.sha256" - 2>/dev/null | awk '{print $1; exit}')"
				if [ -n "$want" ] && [ "$(sha256sum "$f" | cut -d' ' -f1)" != "$want" ]; then
					echo "::error::${key} doesn't match its checksum; left in the store (replace it from the build, or remove the release by hand)" >&2
					damaged=1; done_all=0; rm -f "$f"; continue
				fi
			fi
			ia_put "$item" "$f" "$v" || done_all=0
			rm -f "$f"
		done
		if [ "$done_all" != 1 ]; then
			echo "  not all files are confirmed on the archive yet; ${v} stays in the store until the next run"
			continue
		fi
		# The release's notes now send people to the archive.
		if [ -n "${GH_TOKEN:-}" ] && command -v gh >/dev/null && gh release view "v${v}" -R "${GH_REPO:-cybroidos/os}" >/dev/null 2>&1; then
			gh release view "v${v}" -R "${GH_REPO:-cybroidos/os}" --json body --jq .body > "${work}/notes.md"
			python3 - "${work}/notes.md" "$v" "${DOWNLOAD_URL}" <<'PY'
import sys
p, v, base = sys.argv[1:]
s = open(p).read()
s = s.replace(f"{base}/releases/{v}/index.html", f"https://archive.org/details/cybroidos-{v}")
s = s.replace(f"{base}/releases/{v}/", f"https://archive.org/download/cybroidos-{v}/")
note = f"> This version is no longer supported. Its files are kept on the Internet Archive: https://archive.org/details/cybroidos-{v}\n\n"
if not s.startswith("> This version is no longer supported"):
    s = note + s
open(p, "w").write(s)
PY
			gh release edit "v${v}" -R "${GH_REPO:-cybroidos/os}" --notes-file "${work}/notes.md" >/dev/null
			echo "  release notes for v${v} point to the archive"
		fi
		store_rm_prefix "releases/${v}/"
		echo "  removed from the store"
	done
	index
	return "${damaged}"
}

case "${cmd}" in
publish) publish "$@" ;;
index) index ;;
retire) retire ;;
*) echo "usage: $0 publish <file>... | index | retire" >&2; exit 2 ;;
esac
