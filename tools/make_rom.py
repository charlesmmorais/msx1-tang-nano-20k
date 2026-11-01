#!/usr/bin/env python3
"""
Build bios/msx_rom.mem (48 KB, one hex byte per line) for $readmemh.

The 48 KB image is mapped in slot 0 at 0000h-BFFFh. Unused space is FFh.

  C-BIOS (open source, https://cbios.sourceforge.net/):
    python3 tools/make_rom.py cbios_main_msx1.rom cbios_logo_msx1.rom
  A real MSX1 system ROM (BIOS + BASIC, 32 KB):
    python3 tools/make_rom.py msx1.rom

Files are placed back to back: the first at 0000h, the next right after it.
"""
import sys
from pathlib import Path

SIZE = 48 * 1024


def main(argv):
    if not 2 <= len(argv) <= 3:
        print(__doc__)
        return 1
    image = bytearray()
    for name in argv[1:]:
        data = Path(name).read_bytes()
        print(f"{name}: {len(data)} bytes at {len(image):04X}h")
        image += data
    if len(image) > SIZE:
        print(f"error: {len(image)} bytes, the ROM area is only {SIZE}")
        return 1
    image += b"\xff" * (SIZE - len(image))
    out = Path(__file__).resolve().parent.parent / "bios" / "msx_rom.mem"
    out.write_text("".join(f"{b:02x}\n" for b in image))
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
