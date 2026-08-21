"""Compile declarative Eden blueprints into the v1 macro collection format.

The input is intentionally small and deterministic so an LLM can produce it
without needing to know the binary macro format. Blueprint coordinates use
the conventional (x, y, z) order, with y vertical. Eden's native build
arguments are (x, z, y), so compilation performs that final axis translation.
The compiler expands boxes, frames, and axis-aligned lines, validates every
event, and writes the same 10-slot collection consumed by macro-payload.S.
"""

from __future__ import annotations

import argparse
import json
import os
import struct
from pathlib import Path
from typing import Any


MAGIC = b"EDNMAC01"
VERSION = 1
SLOT_COUNT = 10
EVENT_SIZE = 24
MAX_EVENTS = 32768
SLOT_SIZE = EVENT_SIZE * MAX_EVENTS
HEADER_SIZE = 8 + 4 + (SLOT_COUNT * 4)
EVENT = struct.Struct("<iiiiiBBH")
HEADER = struct.Struct("<8sI10I")


class BlueprintError(ValueError):
    pass


def xyz(value: Any, label: str) -> tuple[int, int, int]:
    if not isinstance(value, list) or len(value) != 3:
        raise BlueprintError(f"{label} must be a three-element list")
    if not all(isinstance(v, int) and not isinstance(v, bool) for v in value):
        raise BlueprintError(f"{label} must contain integers")
    return value[0], value[1], value[2]


def inclusive_range(a: int, b: int):
    return range(a, b + 1) if a <= b else range(a, b - 1, -1)


class DesignCompiler:
    def __init__(self, palette: dict[str, Any]):
        self.palette = palette
        self.cells: dict[tuple[int, int, int], tuple[int, int, int, int]] = {}

    def material(self, name: str, operation: dict[str, Any]) -> tuple[int, int, int]:
        try:
            spec = self.palette[name]
        except KeyError as exc:
            raise BlueprintError(f"unknown block palette name: {name}") from exc
        if isinstance(spec, int):
            block_id, default_color, default_orientation = spec, 0, 2
        else:
            block_id = spec["id"]
            default_color = spec.get("color", 0)
            default_orientation = spec.get("orientation", 2)
        color = operation.get("color", default_color)
        orientation = operation.get("orientation", default_orientation)
        if not all(isinstance(v, int) for v in (block_id, color, orientation)):
            raise BlueprintError(f"invalid metadata for block {name}")
        if not 0 <= block_id <= 0x7fffffff:
            raise BlueprintError(f"block id out of range for {name}")
        if not 0 <= color <= 0x7fffffff:
            raise BlueprintError(f"color out of range for {name}")
        if not 0 <= orientation <= 255:
            raise BlueprintError(f"orientation out of range for {name}")
        return block_id, color, orientation

    def put(self, position: tuple[int, int, int], operation: dict[str, Any]) -> None:
        block_id, color, orientation = self.material(operation["block"], operation)
        event = operation.get("event", "build")
        event_code = {"build": 0, "destroy": 1, "paint": 2}.get(event)
        if event_code is None:
            raise BlueprintError(f"unsupported event type: {event}")
        self.cells[position] = (block_id, color, orientation, event_code)

    def box(self, operation: dict[str, Any]) -> None:
        low = xyz(operation["min"], "box.min")
        high = xyz(operation["max"], "box.max")
        hollow = bool(operation.get("hollow", False))
        for x in inclusive_range(low[0], high[0]):
            for y in inclusive_range(low[1], high[1]):
                for z in inclusive_range(low[2], high[2]):
                    if hollow and not (
                        x in (low[0], high[0])
                        or y in (low[1], high[1])
                        or z in (low[2], high[2])
                    ):
                        continue
                    self.put((x, y, z), operation)

    def frame(self, operation: dict[str, Any]) -> None:
        low = xyz(operation["min"], "frame.min")
        high = xyz(operation["max"], "frame.max")
        for x in inclusive_range(low[0], high[0]):
            for y in inclusive_range(low[1], high[1]):
                for z in inclusive_range(low[2], high[2]):
                    if x in (low[0], high[0]) or z in (low[2], high[2]):
                        self.put((x, y, z), operation)

    def line(self, operation: dict[str, Any]) -> None:
        start = xyz(operation["from"], "line.from")
        end = xyz(operation["to"], "line.to")
        differing = [axis for axis in range(3) if start[axis] != end[axis]]
        if len(differing) > 1:
            raise BlueprintError("line endpoints must be axis-aligned")
        axis = differing[0] if differing else 0
        for value in inclusive_range(start[axis], end[axis]):
            position = list(start)
            position[axis] = value
            self.put(tuple(position), operation)

    def compile(self, design: dict[str, Any]) -> tuple[list[bytes], dict[str, Any]]:
        self.cells.clear()
        anchor = xyz(design.get("anchor", [0, 0, 0]), "anchor")
        for operation in design.get("operations", []):
            kind = operation.get("op")
            if kind == "block":
                self.put(xyz(operation["at"], "block.at"), operation)
            elif kind == "box":
                self.box(operation)
            elif kind == "frame":
                self.frame(operation)
            elif kind == "line":
                self.line(operation)
            else:
                raise BlueprintError(f"unsupported operation: {kind}")
        if anchor not in self.cells:
            raise BlueprintError(f"design anchor {anchor} has no block")
        if len(self.cells) > MAX_EVENTS:
            raise BlueprintError(
                f"{design.get('name', 'design')} has {len(self.cells)} events; "
                f"the current macro limit is {MAX_EVENTS}"
            )

        ordered_positions = [anchor] + sorted(
            (position for position in self.cells if position != anchor),
            key=lambda position: (position[1], position[2], position[0]),
        )
        records: list[bytes] = []
        for position in ordered_positions:
            dx = position[0] - anchor[0]
            dy = position[1] - anchor[1]
            dz = position[2] - anchor[2]
            if not all(-(2**31) <= value < 2**31 for value in (dx, dy, dz)):
                raise BlueprintError("relative coordinate exceeds macro format")
            block_id, color, orientation, event_code = self.cells[position]
            # Eden's BUILD_BLOCK argument order is native (x, z, y). Keep the
            # authoring format intuitive (x, y, z) and swap the final two
            # relative coordinates only at the binary format boundary.
            records.append(EVENT.pack(dx, dz, dy, block_id, color, orientation, event_code, 0))

        positions = list(self.cells)
        bounds = {
            "min": [min(position[axis] for position in positions) for axis in range(3)],
            "max": [max(position[axis] for position in positions) for axis in range(3)],
        }
        manifest = {
            "slot": design["slot"],
            "name": design["name"],
            "description": design.get("description", ""),
            "anchor": list(anchor),
            "coordinate_order": "blueprint x,y,z -> Eden native x,z,y",
            "event_count": len(records),
            "bounds": bounds,
            "materials": sorted(
                {self.cells[position][0] for position in self.cells}
            ),
        }
        return records, manifest


def compile_collection(source: Path, output: Path, manifest_path: Path, force: bool) -> None:
    document = json.loads(source.read_text(encoding="utf-8"))
    if document.get("format") != 1:
        raise BlueprintError("unsupported blueprint format")
    designs = document.get("designs")
    if not isinstance(designs, list):
        raise BlueprintError("designs must be a list")
    if output.exists() and not force:
        raise BlueprintError(f"refusing to overwrite existing file: {output}")

    collection = bytearray(HEADER_SIZE + (SLOT_SIZE * SLOT_COUNT))
    counts = [0] * SLOT_COUNT
    manifests = []
    for design in designs:
        slot = design.get("slot")
        if not isinstance(slot, int) or not 0 <= slot < SLOT_COUNT:
            raise BlueprintError(f"invalid slot for {design.get('name', '<unnamed>')}")
        if counts[slot]:
            raise BlueprintError(f"duplicate design slot: {slot}")
        records, design_manifest = DesignCompiler(document["palette"]).compile(design)
        counts[slot] = len(records)
        base = HEADER_SIZE + (slot * SLOT_SIZE)
        for index, record in enumerate(records):
            start = base + (index * EVENT_SIZE)
            collection[start : start + EVENT_SIZE] = record
        manifests.append(design_manifest)

    collection[:HEADER_SIZE] = HEADER.pack(MAGIC, VERSION, *counts)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(collection)
    try:
        source_label = str(source.relative_to(manifest_path.parent))
    except ValueError:
        source_label = str(source)
    manifest_path.write_text(
        json.dumps(
            {
                "source": source_label,
                "output": str(output),
                "format": 1,
                "magic": MAGIC.decode("ascii"),
                "slot_size": SLOT_SIZE,
                "designs": sorted(manifests, key=lambda item: item["slot"]),
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> int:
    blueprint_dir = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--blueprints",
        type=Path,
        default=blueprint_dir / "eden_blueprints.json",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(os.environ.get("APPDATA", ".")) / "Eden" / "eden_macros_ai_examples.dat",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=blueprint_dir / "eden_macro_examples_manifest.json",
    )
    parser.add_argument("--force", action="store_true", help="allow replacing the requested output")
    args = parser.parse_args()
    try:
        compile_collection(args.blueprints, args.output, args.manifest, args.force)
    except (OSError, json.JSONDecodeError, BlueprintError) as exc:
        parser.error(str(exc))
    print(f"Created {args.output}")
    print(f"Manifest: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
