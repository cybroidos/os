#!/usr/bin/env python3
"""The downloads store on Appwrite Storage, for tools/downloads.sh.

Appwrite keeps files flat in a bucket, by id, so downloads.sh's keys
(releases/<version>/<file>, latest.json) map to ids here: a release file's id
is its name without "cybroidos-" and "-amd64" (ids are at most 36 characters),
and its key comes back from its name. Uploads go in 5 MB chunks (Appwrite's
own size for large files), each retried, so a dropped connection resumes
instead of starting a 3 GB ISO again.

  appwrite-store.py list               every file as JSON, shaped like S3's list-objects
  appwrite-store.py put <file> <key>   upload (replacing a file with the same key)
  appwrite-store.py get <key> <dest>   download
  appwrite-store.py rm <key>           delete
  appwrite-store.py url <key>          the public address of a file

Env: APPWRITE_ENDPOINT (https://cloud.novabusiness.one/v1), APPWRITE_PROJECT,
APPWRITE_KEY, APPWRITE_BUCKET (downloads); APPWRITE_PUBLIC_ENDPOINT is the
endpoint written into public links (download.cybroid.com/v1 once that domain
is the project's), by default APPWRITE_ENDPOINT. Python's standard library only.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ENDPOINT = os.environ.get("APPWRITE_ENDPOINT", "https://cloud.novabusiness.one/v1").rstrip("/")
PUBLIC = os.environ.get("APPWRITE_PUBLIC_ENDPOINT", ENDPOINT).rstrip("/")
PROJECT = os.environ["APPWRITE_PROJECT"]
BUCKET = os.environ.get("APPWRITE_BUCKET", "downloads")
CHUNK = 5 * 1024 * 1024
RELEASE = re.compile(r"^cybroidos-([a-z]+)-([0-9]+\.[0-9]+\.[0-9]+)-amd64\.(.+)$")


def key_to_id(key):
    name = key.rsplit("/", 1)[-1]
    m = RELEASE.match(name)
    fid = f"{m.group(1)}-{m.group(2)}.{m.group(3)}" if m else name
    if len(fid) > 36 or not re.match(r"^[A-Za-z0-9][A-Za-z0-9._-]*$", fid):
        sys.exit(f"appwrite-store: no Appwrite id for {key}")
    return fid


def name_to_key(name):
    m = RELEASE.match(name)
    return f"releases/{m.group(2)}/{name}" if m else name


def call(method, path, body=None, headers=None, raw=False, tries=6):
    h = {"X-Appwrite-Project": PROJECT, "X-Appwrite-Key": os.environ["APPWRITE_KEY"]}
    h.update(headers or {})
    if isinstance(body, dict):
        body = json.dumps(body).encode()
        h["Content-Type"] = "application/json"
    for attempt in range(tries):
        req = urllib.request.Request(ENDPOINT + path, data=body, headers=h, method=method)
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                data = r.read()
                return data if raw else (json.loads(data) if data else {})
        except urllib.error.HTTPError as e:
            if e.code in (404, 409) or (400 <= e.code < 500 and e.code != 429):
                raise
            err = e
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            err = e
        time.sleep(min(60, 5 * 2 ** attempt))
    raise SystemExit(f"appwrite-store: {method} {path}: {err}")


def files():
    out, cursor = [], None
    while True:
        q = [json.dumps({"method": "limit", "values": [100]})]
        if cursor:
            q.append(json.dumps({"method": "cursorAfter", "values": [cursor]}))
        page = call("GET", f"/storage/buckets/{BUCKET}/files?" + urllib.parse.urlencode([("queries[]", x) for x in q]))
        out += page["files"]
        if len(page["files"]) < 100:
            return out
        cursor = page["files"][-1]["$id"]


def exists(fid):
    try:
        return call("GET", f"/storage/buckets/{BUCKET}/files/{fid}", tries=3)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def rm(key):
    try:
        call("DELETE", f"/storage/buckets/{BUCKET}/files/{key_to_id(key)}")
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise


def put(path, key):
    fid, name, size = key_to_id(key), os.path.basename(key), os.path.getsize(path)
    if name != os.path.basename(path) and RELEASE.match(os.path.basename(path)):
        sys.exit(f"appwrite-store: {path} would be stored as {name}")
    if exists(fid):
        rm(key)  # Appwrite can't overwrite: an index file replaced, or an unfinished upload
    mime = {".iso": "application/x-iso9660-image", ".json": "application/json", ".md": "text/markdown",
            ".html": "text/html"}.get(os.path.splitext(name)[1], "text/plain")
    total = max(1, -(-size // CHUNK))
    with open(path, "rb") as f:
        for i in range(total):
            start = i * CHUNK
            data = f.read(CHUNK)
            end = start + len(data) - 1
            b = uuid.uuid4().hex
            parts = [f"--{b}\r\nContent-Disposition: form-data; name=\"fileId\"\r\n\r\n{fid}\r\n".encode()]
            if i == 0:
                for p in ['read("any")']:
                    parts.append(f"--{b}\r\nContent-Disposition: form-data; name=\"permissions[]\"\r\n\r\n{p}\r\n".encode())
            parts.append(f"--{b}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{name}\"\r\n"
                         f"Content-Type: {mime}\r\n\r\n".encode() + data + f"\r\n--{b}--\r\n".encode())
            headers = {"Content-Type": f"multipart/form-data; boundary={b}"}
            if total > 1:
                headers["Content-Range"] = f"bytes {start}-{max(end, start)}/{size}"
            if i > 0:
                headers["X-Appwrite-ID"] = fid
            call("POST", f"/storage/buckets/{BUCKET}/files", b"".join(parts), headers)
            if total > 20 and (i + 1) % 100 == 0:
                print(f"  {name}: {(i + 1) * 100 // total}%", file=sys.stderr, flush=True)
    done = exists(fid)
    if not done or done.get("sizeOriginal") != size:
        sys.exit(f"appwrite-store: {name} didn't arrive whole")


def get(key, dest):
    fid = key_to_id(key)
    with open(dest, "wb") as out:
        req = urllib.request.Request(f"{ENDPOINT}/storage/buckets/{BUCKET}/files/{fid}/download",
                                     headers={"X-Appwrite-Project": PROJECT, "X-Appwrite-Key": os.environ["APPWRITE_KEY"]})
        with urllib.request.urlopen(req, timeout=600) as r:
            while chunk := r.read(1 << 20):
                out.write(chunk)


def url(key):
    # ISOs come as a download with their own name; the rest open in the browser.
    how = "download" if key.endswith(".iso") else "view"
    return f"{PUBLIC}/storage/buckets/{BUCKET}/files/{key_to_id(key)}/{how}?project={PROJECT}"


def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "list":
        # In S3's list-objects shape, so downloads.sh reads either store the same way.
        json.dump({"Contents": [{"Key": name_to_key(f["name"]), "Size": f["sizeOriginal"], "LastModified": f["$createdAt"],
                                 "Url": url(name_to_key(f["name"]))}
                                for f in files() if f.get("chunksUploaded", 1) >= f.get("chunksTotal", 1)]}, sys.stdout)
    elif cmd == "put" and len(argv) == 4:
        put(argv[2], argv[3])
    elif cmd == "get" and len(argv) == 4:
        get(argv[2], argv[3])
    elif cmd == "rm" and len(argv) == 3:
        rm(argv[2])
    elif cmd == "url" and len(argv) == 3:
        print(url(argv[2]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv)
