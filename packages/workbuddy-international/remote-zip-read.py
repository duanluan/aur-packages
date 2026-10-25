#!/usr/bin/env python3
"""Read one file out of a remote zip via HTTP range requests.

Usage: remote-zip-read.py <url> <name-suffix> [--prop CFBundleVersion]

Fetches the zip central directory, finds the first entry whose name ends
with <name-suffix>, range-fetches just that entry and prints its bytes to
stdout. With --prop, parses the bytes as a plist and prints one property.
Used by update.sh to detect the Electron version bundled in the WorkBuddy
darwin zip without downloading the whole archive.
"""
import io
import plistlib
import struct
import sys
import urllib.request
import zlib


def fetch(url, start, end):
    req = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def head_size(url):
    req = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return int(resp.headers["Content-Length"])


def parse_eocd(url, total):
    tail_len = 64 * 1024 + 22
    start = max(0, total - tail_len)
    tail = fetch(url, start, total - 1)
    pos = tail.rfind(b"PK\x05\x06")
    if pos < 0:
        raise SystemExit("EOCD not found")
    eocd = tail[pos:pos + 22]
    entry_count = struct.unpack("<H", eocd[10:12])[0]
    cd_size, cd_offset = struct.unpack("<II", eocd[12:20])
    if entry_count != 0xFFFF and cd_size != 0xFFFFFFFF:
        return entry_count, cd_size, cd_offset
    # zip64: locate EOCD64 record through the EOCD64 locator
    loc_pos = tail.rfind(b"PK\x06\x07")
    if loc_pos < 0:
        raise SystemExit("zip64 locator not found")
    eocd64_offset = struct.unpack("<Q", tail[loc_pos + 8:loc_pos + 16])[0]
    eocd64 = fetch(url, eocd64_offset, eocd64_offset + 56 - 1)
    if eocd64[:4] != b"PK\x06\x06":
        raise SystemExit("EOCD64 signature mismatch")
    entry_count = struct.unpack("<Q", eocd64[32:40])[0]
    cd_size = struct.unpack("<Q", eocd64[40:48])[0]
    cd_offset = struct.unpack("<Q", eocd64[48:56])[0]
    return entry_count, cd_size, cd_offset


def find_entry(url, suffix):
    total = head_size(url)
    entry_count, cd_size, cd_offset = parse_eocd(url, total)
    cd = fetch(url, cd_offset, cd_offset + cd_size - 1)
    pos = 0
    while pos + 46 <= len(cd):
        if cd[pos:pos + 4] != b"PK\x01\x02":
            break
        method = struct.unpack("<H", cd[pos + 10:pos + 12])[0]
        comp_size = struct.unpack("<I", cd[pos + 20:pos + 24])[0]
        name_len, extra_len, comment_len = struct.unpack(
            "<HHH", cd[pos + 28:pos + 34])
        lho = struct.unpack("<I", cd[pos + 42:pos + 46])[0]
        name = cd[pos + 46:pos + 46 + name_len].decode("utf-8", "replace")
        extra = cd[pos + 46 + name_len:pos + 46 + name_len + extra_len]
        if comp_size == 0xFFFFFFFF or lho == 0xFFFFFFFF:
            epos = 0
            while epos + 4 <= len(extra):
                hid, hsize = struct.unpack("<HH", extra[epos:epos + 4])
                if hid == 0x0001:
                    data = extra[epos + 4:epos + 4 + hsize]
                    off = 0
                    if comp_size == 0xFFFFFFFF:
                        comp_size = struct.unpack("<Q", data[off:off + 8])[0]
                        off += 8
                    if lho == 0xFFFFFFFF and off + 8 <= len(data):
                        lho = struct.unpack("<Q", data[off:off + 8])[0]
                    break
                epos += 4 + hsize
        if name.endswith(suffix):
            return name, method, comp_size, lho
        pos += 46 + name_len + extra_len + comment_len
    raise SystemExit(f"entry not found: *{suffix}")


def read_entry(url, name, method, comp_size, lho):
    lh = fetch(url, lho, lho + 29)
    if lh[:4] != b"PK\x03\x04":
        raise SystemExit("local header signature mismatch")
    name_len, extra_len = struct.unpack("<HH", lh[26:30])
    data_start = lho + 30 + name_len + extra_len
    data = fetch(url, data_start, data_start + comp_size - 1)
    if method == 0:
        return data
    if method == 8:
        return zlib.decompress(data, -15)
    raise SystemExit(f"unsupported compression method: {method}")


def main():
    url, suffix = sys.argv[1], sys.argv[2]
    prop = None
    if len(sys.argv) > 3 and sys.argv[3] == "--prop":
        prop = sys.argv[4]
    blob = read_entry(url, *find_entry(url, suffix))
    if prop:
        plist = plistlib.load(io.BytesIO(blob))
        print(plist.get(prop, ""))
    else:
        sys.stdout.buffer.write(blob)


if __name__ == "__main__":
    main()
