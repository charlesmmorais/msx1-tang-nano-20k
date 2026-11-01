<div align="center">

# MSX1 on Tang Nano 20K

### An MSX1 computer in Verilog for the Sipeed Tang Nano 20K (Gowin GW2AR-18C)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![HDL](https://img.shields.io/badge/HDL-Verilog-blue.svg)](src/)
[![FPGA](https://img.shields.io/badge/FPGA-Gowin%20GW2AR--18C-orange.svg)](https://www.gowinsemi.com/)
[![Board](https://img.shields.io/badge/Board-Tang%20Nano%2020K-green.svg)](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)

**Read this in:** [Português](README.pt-BR.md) · [Español](README.es.md) · [Français](README.fr.md) · [Italiano](README.it.md)

</div>

---

## Status

| Check | Result |
|---|---|
| Synthesis + place & route (Gowin EDA 1.9.12) | ✅ bitstream generated, timing met (Fmax 54 MHz for a 27 MHz design) |
| System simulation (Icarus Verilog, `sim/run.sh`) | ✅ passes: RAM, stack, VRAM, VDP image, sprites, PSG, PPI, keyboard, interrupts |
| Booting C-BIOS on real hardware | ⏳ **not tested yet** |

The design builds and simulates, but it has not been run on a board yet.
Reports from people who try it are very welcome (open an Issue).

## What is in it

| Part | Implementation |
|---|---|
| CPU | Z80 at 3.579545 MHz — [tv80](https://github.com/hutch31/tv80) core (Verilog port of T80, MIT). One wait state on M1, like a real MSX. |
| Video | TMS9918A: Graphics I, Graphics II, Multicolor, Text. 32 sprites (8×8/16×16, magnified, early clock), 4 per line, 5th-sprite and collision flags. |
| Video out | HDMI/DVI 720×480p 59.94 Hz. The 256×192 picture is doubled to 512×384 and centred. |
| Sound | AY-3-8910 (3 tones, noise, envelope) + key click, 1-pin sigma-delta (PDM) output |
| PPI | i8255: slot select, keyboard matrix, CAPS LED, click |
| ROM | 48 KB in block RAM, slot 0 (C-BIOS main + logo, or an MSX1 BIOS+BASIC) |
| RAM | 64 KB in the GW2AR's embedded SDRAM, slot 3 |
| Keyboard | PS/2, mapped to the MSX international matrix |
| microSD | raw SPI port (card protocol done by MSX software; no disk driver yet) |

## Hardware

- Sipeed Tang Nano 20K
- HDMI monitor/TV (720×480p input)
- PS/2 keyboard (or a USB keyboard that still speaks PS/2, through an adapter)
- Audio: an RC low-pass on the audio pin (e.g. 1 kΩ + 10 nF) and a coupling capacitor (e.g. 1 µF) to an amplifier
- Optional: microSD card

## Pins

All in [constraints/tang_nano_20k.cst](constraints/tang_nano_20k.cst).

| Signal | Pin | Notes |
|---|---|---|
| 27 MHz clock | 4 | on board |
| Reset (S1) | 88 | on board button |
| LEDs 0–5 | 15–20 | CAPS, SD, HALT, SDRAM not ready, heartbeat, reset |
| HDMI | 33–40 | on board connector |
| microSD | 81–84 | on board slot |
| PS/2 clock | 76 | **side header — check before wiring** |
| PS/2 data | 77 | **side header — check before wiring** |
| Audio PDM | 75 | **side header — check before wiring** |

The Tang Nano 20K has no PMOD connector. The PS/2 and audio pins are free
3.3 V GPIOs on the side headers; confirm them against Sipeed's pinout for your
board revision and change the `.cst` if needed. PS/2 keyboards are 5 V
devices: most work at 3.3 V; if yours does not, use a level shifter.

## Getting started

### 1. Make the ROM image

The ROM is not in the repository. [C-BIOS](https://cbios.sourceforge.net/) is a free MSX BIOS:

```bash
python3 tools/make_rom.py cbios_main_msx1.rom cbios_logo_msx1.rom
```

Or, if you own an MSX1 system ROM (32 KB, BIOS + BASIC):

```bash
python3 tools/make_rom.py msx1.rom
```

Both write `bios/msx_rom.mem`, which the build reads.

### 2. Build

With the Gowin EDA IDE: open `msx1_tang20k.gprj` and run *Place & Route*.
In *Project → Configuration → Dual-Purpose Pin*, enable MSPI, SSPI, READY and DONE as regular I/O.

Or from the command line (Gowin EDA installed):

```bash
gw_sh scripts/build.tcl
```

The bitstream is `impl/pnr/msx1_tang20k.fs`.

### 3. Program the board

With [openFPGALoader](https://github.com/trabucayre/openFPGALoader):

```bash
openFPGALoader -b tangnano20k impl/pnr/msx1_tang20k.fs
```

Add `-f` to write it to flash so it survives a power cycle. The Gowin
Programmer works too.

### 4. Simulate (optional)

Needs [Icarus Verilog](https://steveicarus.github.io/iverilog/) and Python 3:

```bash
sh sim/run.sh
```

It runs a small Z80 test program ([sim/make_test_rom.py](sim/make_test_rom.py))
on the whole machine, with a model of the SDRAM, and saves one HDMI frame to
`sim/frame.ppm`. The same test runs in GitHub Actions on every push.

## How it works

### Clocks

```
27 MHz crystal ─► rPLL ─► 135 MHz ──────────────► OSER10 (HDMI serializers)
                             └─► CLKDIV /5 ─► 27 MHz  = pixel clock = system clock
                                                ├─ CPU clock enable   3.579545 MHz
                                                ├─ PSG clock enable   1.789773 MHz
                                                └─ SDRAM clock (inverted)
```

Everything runs in one 27 MHz clock domain, so there are no clock-domain
crossings. The CPU clock enable comes from a phase accumulator, so its
average rate is exactly 3.579545 MHz.

### Memory map (primary slots, selected with PPI port A / I/O A8h)

| Page | Slot 0 | Slot 1 | Slot 2 | Slot 3 |
|---|---|---|---|---|
| 0000–3FFF | ROM | – | – | RAM |
| 4000–7FFF | ROM | – | – | RAM |
| 8000–BFFF | ROM (logo / BASIC) | – | – | RAM |
| C000–FFFF | – | – | – | RAM |

Empty space reads FFh. Expanded slots are not implemented.

### I/O map

| Port | Device |
|---|---|
| 40h–41h | microSD SPI (data, control/status) — see [src/sdcard/sd_spi.v](src/sdcard/sd_spi.v) |
| 98h–99h | VDP (VRAM data, control/status) |
| A0h–A2h | PSG (address, write, read) |
| A8h–ABh | PPI (slots, keyboard, port C, control) |

### SDRAM

The GW2AR-18C carries a 64 Mbit SDRAM die in the same package. Its pins have
fixed names (`O_sdram_*`, `IO_sdram_dq`) and need no constraints.
[src/memory/sdram_ctrl.v](src/memory/sdram_ctrl.v) does one byte per access
(ACTIVATE + READ/WRITE with auto-precharge, CAS latency 2) and refreshes every
14 µs. The CPU is held with WAIT until each RAM access finishes. In
simulation an access fits inside the Z80's normal bus cycle, so RAM adds no
wait states (only the very first access waits ~0.3 ms for SDRAM power-up).

### VDP

The 16 KB VRAM is a dual-port block RAM (CPU on one port, renderer on the
other). Each TMS line is drawn into a small line buffer during the two HDMI
lines before it is shown (background tiles first, then up to 4 sprites), so
VRAM is read one byte per clock instead of many bytes at once.

### FPGA resources (Gowin EDA 1.9.12)

| Resource | Used | Available |
|---|---|---|
| Logic (LUT/ALU) | 5,235 | 20,736 (26%) |
| Registers | 1,666 | 15,915 (11%) |
| Block RAM (BSRAM) | 33 | 46 (72%) |
| rPLL | 1 | 2 |

## Files

```
src/top.v                  top level, I/O decode, clocks/reset
src/pll_135m.v             rPLL 27→135 MHz + CLKDIV /5
src/cpu/tv80_msx.v         Z80 wrapper with clock enable
src/cpu/tv80/              tv80 core (MIT, Guy Hutchison)
src/memory/slot_ctrl.v     primary slot decoder
src/memory/sdram_ctrl.v    embedded SDRAM controller
src/vdp/tms9918a.v         TMS9918A
src/video/                 TMDS encoder + HDMI serializer
src/psg/ay8910.v           AY-3-8910
src/ppi/ppi8255.v          i8255
src/keyboard/              PS/2 receiver + MSX key map
src/sdcard/sd_spi.v        SPI port for the microSD slot
src/audio/pdm_dac.v        sigma-delta audio DAC
constraints/               pin constraints
scripts/build.tcl          command-line build
sim/                       testbench, SDRAM model, test program
tools/make_rom.py          builds bios/msx_rom.mem
```

## Known limitations

- Not tested on hardware yet (see Status).
- No cartridge slots, no expanded slots, no Nextor/MSX-DOS driver for the SD card.
- No joystick or cassette interface.
- VDP: no VRAM access-timing limits (software that relies on slow-VRAM
  behaviour may show differences); the 4/16 KB bit is ignored.
- PS/2 keys follow the MSX keycaps (international layout), not the PC ones.

## Roadmap

1. Boot C-BIOS on a board and fix what shows up.
2. Cartridge ROM loading (from the SD card or flash) into slot 1.
3. Nextor driver for the SD port.
4. Joystick (DB9) and cassette audio in.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please run `sh sim/run.sh` before
sending a change to the RTL.

## Credits

- [tv80](https://github.com/hutch31/tv80) by Guy Hutchison, based on T80 by Daniel Wallner (MIT)
- [C-BIOS](https://cbios.sourceforge.net/) team, for a free MSX BIOS
- Sipeed and the Tang Nano community for board documentation

## References

- [MSX2 Technical Handbook](https://konamiman.github.io/MSX2-Technical-Handbook/) (covers the MSX1 hardware too)
- [TMS9918A data manual](http://www.unige.ch/medecine/nouspikel/ti99/tms9918a.htm)
- [Tang Nano 20K wiki](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
- [Gowin GW2AR-18 documentation](https://www.gowinsemi.com/en/support/database/)
