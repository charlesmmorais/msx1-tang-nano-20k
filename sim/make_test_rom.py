#!/usr/bin/env python3
"""
Writes sim/test_rom.mem: a tiny hand-assembled Z80 program that exercises the
machine. It reports results by writing to I/O ports the testbench watches:
  OUT (10h) = a checked value, in order (see EXPECT in tb_top.v)
  OUT (12h) = from the interrupt handler (VDP status)
  OUT (11h) = end of test
"""
from pathlib import Path

rom = bytearray(b"\xff" * (48 * 1024))

def put(addr, *code):
    rom[addr:addr + len(code)] = bytes(code)
    return addr + len(code)

# 0000h: jump to main
put(0x0000, 0xF3, 0xC3, 0x00, 0x01)              # DI ; JP 0100h

# 0038h: IM 1 interrupt handler
put(0x0038,
    0xDB, 0x99,                                  # IN A,(99h)   ack VDP, A = status
    0xD3, 0x12,                                  # OUT (12h),A
    0xFB,                                        # EI
    0xC9)                                        # RET

p = 0x0100
p = put(p, 0x3E, 0xF0, 0xD3, 0xA8)               # slots: pages 2,3 = slot 3 (RAM)
p = put(p, 0x31, 0xF0, 0xFF)                     # LD SP,FFF0h
p = put(p, 0x21, 0x00, 0xC0)                     # LD HL,C000h
p = put(p, 0x36, 0x55, 0x23, 0x36, 0xAA)         # LD (HL),55h ; INC HL ; LD (HL),AAh
p = put(p, 0x3A, 0x00, 0xC0, 0xD3, 0x10)         # LD A,(C000h) ; OUT (10h),A   -> 55
p = put(p, 0x3A, 0x01, 0xC0, 0xD3, 0x10)         # LD A,(C001h) ; OUT (10h),A   -> AA
call_at = p
p = put(p, 0xCD, 0x00, 0x00)                     # CALL sub (patched)          -> 77
p = put(p, 0x3E, 0x00, 0xD3, 0x99, 0x3E, 0x41, 0xD3, 0x99)  # VRAM write addr 0100h
p = put(p, 0x3E, 0x3C, 0xD3, 0x98, 0x3E, 0xC3, 0xD3, 0x98)  # write 3Ch, C3h
p = put(p, 0x3E, 0x00, 0xD3, 0x99, 0x3E, 0x01, 0xD3, 0x99)  # VRAM read addr 0100h
p = put(p, 0xDB, 0x98, 0xD3, 0x10)               # IN A,(98h) ; OUT (10h),A     -> 3C
p = put(p, 0xDB, 0x98, 0xD3, 0x10)               # IN A,(98h) ; OUT (10h),A     -> C3
p = put(p, 0x3E, 0x07, 0xD3, 0xA0)               # PSG reg 7
p = put(p, 0x3E, 0xB8, 0xD3, 0xA1)               # = B8h
p = put(p, 0xDB, 0xA2, 0xD3, 0x10)               # IN A,(A2h) ; OUT (10h),A     -> B8
p = put(p, 0x3E, 0x08, 0xD3, 0xAA)               # keyboard row 8
p = put(p, 0xDB, 0xA9, 0xFE, 0xFF, 0x28, 0xFA)   # wait: IN A,(A9h) ; CP FFh ; JR Z,wait
p = put(p, 0xD3, 0x10)                           # OUT (10h),A                  -> FE (space)
p = put(p, 0xDB, 0xA8, 0xD3, 0x10)               # IN A,(A8h) ; OUT (10h),A     -> F0

# ---- build a Graphics I screen: checkerboard tiles, a few colours, sprites
def vdp_reg(r, v):
    return (0x3E, v, 0xD3, 0x99, 0x3E, 0x80 | r, 0xD3, 0x99)

def vram_wr_addr(a):
    return (0x3E, a & 0xFF, 0xD3, 0x99, 0x3E, 0x40 | (a >> 8), 0xD3, 0x99)

def out98(*vals):
    code = ()
    for v in vals:
        code += (0x3E, v, 0xD3, 0x98)
    return code

for r, v in [(0, 0x00), (2, 0x06), (3, 0x80), (4, 0x00), (5, 0x36), (6, 0x07), (7, 0xF4)]:
    p = put(p, *vdp_reg(r, v))                    # PNT 1800h CT 2000h PGT 0 SAT 1B00h SPT 3800h
p = put(p, *vram_wr_addr(0x0008))                # pattern 1: 2x2-pixel checkerboard
p = put(p, *out98(0xCC, 0xCC, 0x33, 0x33, 0xCC, 0xCC, 0x33, 0x33))
p = put(p, *out98(0xFF, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0xFF))   # pattern 2: box
p = put(p, *vram_wr_addr(0x1800))                # name table: all pattern 1
loop = p
p = put(p, 0x3E, 0x01, 0x16, 0x03,               # LD A,1 ; LD D,3
           0x06, 0x00,                           # outer: LD B,0
           0xD3, 0x98, 0x10, 0xFC,               # inner: OUT (98h),A ; DJNZ inner
           0x15, 0x20, 0xF7)                     # DEC D ; JR NZ,outer
p = put(p, *vram_wr_addr(0x1800 + 32 * 12 + 8))  # row 12: a run of box tiles
p = put(p, *out98(*([2] * 16)))
p = put(p, *vram_wr_addr(0x2000))                # colours: tiles 0-7 yellow/black
p = put(p, *out98(0xA1))
p = put(p, *vram_wr_addr(0x3800))                # sprite pattern 0: solid 8x8
p = put(p, *out98(*([0xFF] * 8)))
p = put(p, *vram_wr_addr(0x1B00))                # SAT: 2 sprites + terminator
p = put(p, *out98(40, 60, 0, 0x0F,               # white at (60,41)
                  44, 64, 0, 0x08,               # red, overlapping -> collision
                  0xD0))
p = put(p, 0x3E, 0x60, 0xD3, 0x99, 0x3E, 0x81, 0xD3, 0x99)  # R1 = 60h: display on, IE
p = put(p, 0xED, 0x56, 0xFB, 0x76)               # IM 1 ; EI ; HALT (wait for VBLANK)
p = put(p, 0xF3, 0x3E, 0x99, 0xD3, 0x11, 0x76)   # DI ; OUT (11h),99h ; HALT

sub = p
p = put(p, 0x3E, 0x77, 0xD3, 0x10, 0xC9)         # sub: OUT (10h),77h ; RET
rom[call_at + 1] = sub & 0xFF
rom[call_at + 2] = sub >> 8

out = Path(__file__).resolve().parent / "test_rom.mem"
out.write_text("".join(f"{b:02x}\n" for b in rom))
print(f"wrote {out} ({p - 0x100} bytes of code)")
