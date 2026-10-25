#!/usr/bin/env python3

from __future__ import annotations

import struct
import sys
import tempfile
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

RT_ICON = 3
RT_GROUP_ICON = 14


class PEFormatError(RuntimeError):
    pass


@dataclass(frozen=True)
class Section:
    name: str
    virtual_address: int
    virtual_size: int
    raw_size: int
    raw_ptr: int


@dataclass(frozen=True)
class IconEntry:
    width: int
    height: int
    color_count: int
    planes: int
    bit_count: int
    bytes_in_res: int
    resource_id: int


def u16(data: bytes, offset: int) -> int:
    return struct.unpack_from("<H", data, offset)[0]


def u32(data: bytes, offset: int) -> int:
    return struct.unpack_from("<I", data, offset)[0]


def parse_sections(data: bytes) -> tuple[int, list[Section], int]:
    if data[:2] != b"MZ":
        raise PEFormatError("missing MZ header")

    e_lfanew = u32(data, 0x3C)
    if data[e_lfanew:e_lfanew + 4] != b"PE\0\0":
        raise PEFormatError("missing PE header")

    file_header_off = e_lfanew + 4
    _, number_of_sections, _, _, _, size_of_optional_header, _ = struct.unpack_from(
        "<HHIIIHH", data, file_header_off
    )
    optional_header_off = file_header_off + 20
    magic = u16(data, optional_header_off)
    if magic == 0x10B:
        data_directory_off = optional_header_off + 96
    elif magic == 0x20B:
        data_directory_off = optional_header_off + 112
    else:
        raise PEFormatError(f"unsupported optional header magic: 0x{magic:04x}")

    number_of_rva_and_sizes = u32(data, optional_header_off + (92 if magic == 0x10B else 108))
    if number_of_rva_and_sizes <= 2:
        raise PEFormatError("missing resource directory")

    resource_rva = u32(data, data_directory_off + 2 * 8)
    if resource_rva == 0:
        raise PEFormatError("missing resource directory RVA")

    sections_off = optional_header_off + size_of_optional_header
    sections: list[Section] = []
    for index in range(number_of_sections):
        section_off = sections_off + index * 40
        raw_name = data[section_off:section_off + 8].split(b"\0", 1)[0]
        name = raw_name.decode("ascii", errors="ignore")
        virtual_size = u32(data, section_off + 8)
        virtual_address = u32(data, section_off + 12)
        raw_size = u32(data, section_off + 16)
        raw_ptr = u32(data, section_off + 20)
        sections.append(
            Section(
                name=name,
                virtual_address=virtual_address,
                virtual_size=virtual_size,
                raw_size=raw_size,
                raw_ptr=raw_ptr,
            )
        )

    return resource_rva, sections, e_lfanew


def rva_to_offset(rva: int, sections: list[Section]) -> int:
    for section in sections:
        section_size = max(section.virtual_size, section.raw_size)
        if section.virtual_address <= rva < section.virtual_address + section_size:
            return section.raw_ptr + (rva - section.virtual_address)
    raise PEFormatError(f"failed to map RVA to file offset: 0x{rva:x}")


def parse_resources(data: bytes, resource_off: int, sections: list[Section]) -> dict[int, dict[int, dict[int, bytes]]]:
    resources: dict[int, dict[int, dict[int, bytes]]] = defaultdict(lambda: defaultdict(dict))

    def walk(directory_rel_off: int, path: list[int]) -> None:
        directory_off = resource_off + directory_rel_off
        if directory_off + 16 > len(data):
            raise PEFormatError("truncated resource directory")

        _, _, _, _, named_count, id_count = struct.unpack_from("<IIHHHH", data, directory_off)
        entry_off = directory_off + 16
        for index in range(named_count + id_count):
            name_raw, offset_raw = struct.unpack_from("<II", data, entry_off + index * 8)
            if name_raw & 0x80000000:
                continue

            key = name_raw & 0x7FFFFFFF
            if offset_raw & 0x80000000:
                walk(offset_raw & 0x7FFFFFFF, path + [key])
                continue

            full_path = path + [key]
            if len(full_path) != 3:
                continue

            data_entry_off = resource_off + (offset_raw & 0x7FFFFFFF)
            if data_entry_off + 16 > len(data):
                raise PEFormatError("truncated resource data entry")

            data_rva = u32(data, data_entry_off)
            size = u32(data, data_entry_off + 4)
            file_off = rva_to_offset(data_rva, sections)
            blob = data[file_off:file_off + size]
            type_id, name_id, lang_id = full_path
            resources[type_id][name_id][lang_id] = blob

    walk(0, [])
    return resources


def decode_group_icon(data: bytes) -> list[IconEntry]:
    if len(data) < 6:
        raise PEFormatError("truncated group icon resource")

    reserved, icon_type, count = struct.unpack_from("<HHH", data, 0)
    if reserved != 0 or icon_type != 1:
        raise PEFormatError("unexpected group icon header")

    entries: list[IconEntry] = []
    entry_off = 6
    for _ in range(count):
        if entry_off + 14 > len(data):
            raise PEFormatError("truncated group icon entry")
        width, height, color_count, _, planes, bit_count, bytes_in_res, resource_id = struct.unpack_from(
            "<BBBBHHIH", data, entry_off
        )
        entries.append(
            IconEntry(
                width=256 if width == 0 else width,
                height=256 if height == 0 else height,
                color_count=color_count,
                planes=planes,
                bit_count=bit_count,
                bytes_in_res=bytes_in_res,
                resource_id=resource_id,
            )
        )
        entry_off += 14

    return entries


def choose_group_resource(resources: dict[int, dict[int, dict[int, bytes]]]) -> tuple[int, int, bytes]:
    group_icons = resources.get(RT_GROUP_ICON)
    if not group_icons:
        raise PEFormatError("no group icon resource found")

    group_name_id = sorted(group_icons)[0]
    group_langs = group_icons[group_name_id]
    group_lang_id = sorted(group_langs)[0]
    return group_name_id, group_lang_id, group_langs[group_lang_id]


def choose_icon_blob(
    resources: dict[int, dict[int, dict[int, bytes]]],
    entry: IconEntry,
    lang_id: int,
) -> bytes:
    icon_types = resources.get(RT_ICON)
    if not icon_types:
        raise PEFormatError("no icon resource found")

    icon_langs = icon_types.get(entry.resource_id)
    if not icon_langs:
        raise PEFormatError(f"missing icon resource id: {entry.resource_id}")

    if lang_id in icon_langs:
        return icon_langs[lang_id]

    return icon_langs[sorted(icon_langs)[0]]


def score_entry(entry: IconEntry) -> tuple[int, int, int, int]:
    exact_256 = 1 if entry.width == 256 and entry.height == 256 else 0
    area = entry.width * entry.height
    return exact_256, area, entry.bit_count, entry.bytes_in_res


def build_ico(entry: IconEntry, blob: bytes, output_path: Path) -> None:
    icon_dir_size = 6 + 16
    with output_path.open("wb") as handle:
        handle.write(struct.pack("<HHH", 0, 1, 1))
        handle.write(
            struct.pack(
                "<BBBBHHII",
                0 if entry.width == 256 else entry.width,
                0 if entry.height == 256 else entry.height,
                entry.color_count,
                0,
                entry.planes,
                entry.bit_count,
                len(blob),
                icon_dir_size,
            )
        )
        handle.write(blob)


def convert_ico_to_png(ico_path: Path, png_path: Path) -> None:
    with Image.open(ico_path) as image:
        image.save(png_path)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"usage: {Path(argv[0]).name} INPUT_EXE OUTPUT_PNG", file=sys.stderr)
        return 1

    input_path = Path(argv[1])
    output_path = Path(argv[2])
    data = input_path.read_bytes()
    resource_rva, sections, _ = parse_sections(data)
    resource_off = rva_to_offset(resource_rva, sections)
    resources = parse_resources(data, resource_off, sections)
    group_name_id, group_lang_id, group_data = choose_group_resource(resources)
    group_entries = decode_group_icon(group_data)
    if not group_entries:
        raise PEFormatError("empty group icon resource")

    best_entry = max(group_entries, key=score_entry)
    best_blob = choose_icon_blob(resources, best_entry, group_lang_id)

    with tempfile.TemporaryDirectory(prefix="emeditor-wine-icon-") as tmpdir:
        tmpdir_path = Path(tmpdir)
        ico_path = tmpdir_path / "emeditor.ico"
        build_ico(best_entry, best_blob, ico_path)
        convert_ico_to_png(ico_path, output_path)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv))
    except PEFormatError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
