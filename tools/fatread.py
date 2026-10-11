#!/usr/bin/env python3
"""Minimal read-only FAT32 access inside a disk image partition.

Used by the QEMU boot tests to pull kernel/dtb files out of a Raspberry Pi
image's FAT boot partition without needing root or mtools.

Usage:
    fatread.py <image> <offset-bytes> list [DIR]
    fatread.py <image> <offset-bytes> extract <PATH> <OUTFILE>
"""

import argparse
import struct
import sys


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


class Fat32:
    def __init__(self, fh, offset):
        self.fh = fh
        self.offset = offset
        fh.seek(offset)
        bs = fh.read(512)
        if bs[510:512] != b"\x55\xaa":
            sys.exit("error: not a boot sector at the given offset")
        self.bps = u16(bs, 0x0B)
        self.spc = bs[0x0D]
        self.reserved = u16(bs, 0x0E)
        self.num_fats = bs[0x10]
        self.fat_size = u32(bs, 0x24)
        self.root_cluster = u32(bs, 0x2C)
        if self.bps == 0 or self.spc == 0 or self.fat_size == 0:
            sys.exit("error: not FAT32 (bogus BPB)")
        self.fat_start = self.reserved * self.bps
        self.data_start = (self.reserved + self.num_fats * self.fat_size) * self.bps
        self.cluster_bytes = self.spc * self.bps

    def _cluster_off(self, cluster):
        return self.offset + self.data_start + (cluster - 2) * self.cluster_bytes

    def _next(self, cluster):
        self.fh.seek(self.offset + self.fat_start + cluster * 4)
        return u32(self.fh.read(4), 0) & 0x0FFFFFFF

    def _chain(self, cluster):
        while 2 <= cluster < 0x0FFFFFF8:
            yield cluster
            cluster = self._next(cluster)

    def _read_cluster(self, cluster):
        self.fh.seek(self._cluster_off(cluster))
        return self.fh.read(self.cluster_bytes)

    def _iter_dir(self, cluster):
        for c in self._chain(cluster):
            data = self._read_cluster(c)
            for i in range(0, len(data), 32):
                entry = data[i:i + 32]
                if not entry or entry[0] == 0x00:
                    return
                if entry[0] == 0xE5:
                    continue
                attr = entry[0x0B]
                if attr == 0x0F:
                    continue
                name = entry[0:8].decode("latin-1").rstrip()
                ext = entry[8:11].decode("latin-1").rstrip()
                full = name + ("." + ext if ext else "")
                first = (u16(entry, 0x14) << 16) | u16(entry, 0x1A)
                size = u32(entry, 0x1C)
                yield full, bool(attr & 0x10), first, size

    def _find(self, path, cluster):
        parts = [p for p in path.split("/") if p]
        if not parts:
            return True, self.root_cluster, 0
        for name in parts:
            found = None
            for fname, is_dir, first, size in self._iter_dir(cluster):
                if fname.lower() == name.lower():
                    found = (is_dir, first, size)
                    break
            if found is None:
                sys.exit(f"error: not found in FAT image: {path}")
            is_dir, first, size = found
            if name != parts[-1] and not is_dir:
                sys.exit(f"error: not a directory: {name}")
            if name == parts[-1]:
                return is_dir, first, size
            cluster = first
        raise AssertionError

    def list(self, path):
        _, first, _ = self._find(path, self.root_cluster)
        for fname, is_dir, _first, size in self._iter_dir(first):
            print(f"{'d' if is_dir else '-'} {size:>10} {fname}")

    def extract(self, path, outfile):
        is_dir, first, size = self._find(path, self.root_cluster)
        if is_dir:
            sys.exit(f"error: {path} is a directory")
        with open(outfile, "wb") as out:
            remaining = size
            for c in self._chain(first):
                chunk = self._read_cluster(c)
                out.write(chunk[:remaining])
                remaining -= len(chunk)
                if remaining <= 0:
                    break


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("offset", type=int)
    ap.add_argument("cmd", choices=["list", "extract"])
    ap.add_argument("args", nargs="*")
    ns = ap.parse_args()
    with open(ns.image, "rb") as fh:
        fat = Fat32(fh, ns.offset)
        if ns.cmd == "list":
            fat.list(ns.args[0] if ns.args else "/")
        else:
            if len(ns.args) != 2:
                sys.exit("usage: extract <PATH> <OUTFILE>")
            fat.extract(ns.args[0], ns.args[1])


if __name__ == "__main__":
    main()
