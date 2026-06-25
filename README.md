<div align="center">

# 🖥️ MSX1 on Tang Nano 20K

### A fully functional MSX1 computer implemented in Verilog on a $20 FPGA board

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Verilog](https://img.shields.io/badge/HDL-Verilog-blue.svg)](src/)
[![FPGA](https://img.shields.io/badge/FPGA-Gowin%20GW2AR--18-orange.svg)](https://www.gowinsemi.com/)
[![Board](https://img.shields.io/badge/Board-Tang%20Nano%2020K-green.svg)](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
[![MSX](https://img.shields.io/badge/Standard-MSX1-red.svg)](https://www.msx.org/)

**Read this in:** [🇧🇷 Português](README.pt-BR.md) · [🇪🇸 Español](README.es.md) · [🇫🇷 Français](README.fr.md) · [🇮🇹 Italiano](README.it.md)

<br>

```
┌─────────────────────────────────────────────────────────────────────┐
│                        MSX1 FPGA SYSTEM                             │
│                                                                      │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────────────────┐  │
│  │  Z80 CPU │───▶│  Address Bus │───▶│     Memory Map           │  │
│  │  3.6 MHz │    │   16-bit     │    │  Slot 0: BIOS (32KB)    │  │
│  └────┬─────┘    └──────────────┘    │  Slot 0: BASIC (16KB)   │  │
│       │                              │  Slot 3: RAM  (64KB)    │  │
│       │ Data Bus (8-bit)             └──────────────────────────┘  │
│       │                                                              │
│  ┌────▼──────────────────────────────────────────────────────────┐  │
│  │                    I/O DEVICES                                  │  │
│  │                                                                 │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐   │  │
│  │  │ TMS9918A │  │ AY-3-891 │  │  i8255   │  │  SD Card   │   │  │
│  │  │   VDP    │  │   PSG    │  │   PPI    │  │ Controller │   │  │
│  │  │ Port 98h │  │ Port A0h │  │ Port A8h │  │ Port 40h   │   │  │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────────┘   │  │
│  └───────┼─────────────┼─────────────┼────────────────────────── ┘  │
│          │             │             │                               │
│       ┌──▼──┐       ┌──▼──┐      ┌──▼──┐                          │
│       │HDMI │       │ PDM │      │ PS/2│                           │
│       │ OUT │       │ DAC │      │ KBD │                           │
│       └─────┘       └─────┘      └─────┘                          │
└─────────────────────────────────────────────────────────────────────┘
```

</div>

---

## 📋 Table of Contents

- [What is MSX?](#-what-is-msx)
- [What is an FPGA?](#-what-is-an-fpga)
- [Hardware Requirements](#-hardware-requirements)
- [Architecture Overview](#-architecture-overview)
  - [Z80 CPU](#-z80-cpu)
  - [TMS9918A VDP](#-tms9918a-video-display-processor)
  - [AY-3-8910 PSG](#-ay-3-8910-sound-chip)
  - [Intel 8255 PPI](#-intel-8255-ppi)
  - [Memory & Slots](#-memory--slot-system)
  - [Video Output (HDMI)](#-hdmi-video-output)
  - [SD Card](#-sd-card)
  - [PS/2 Keyboard](#-ps2-keyboard)
  - [Audio Output](#-audio-output)
- [Clock Architecture](#%EF%B8%8F-clock-architecture)
- [Getting Started](#-getting-started)
- [Hardware Connections](#-hardware-connections)
- [Building & Flashing](#-building--flashing)
- [File Structure](#-file-structure)
- [IO Map](#-io-port-map)
- [Memory Map](#-memory-map)
- [Known Limitations](#-known-limitations)
- [Contributing](#-contributing)
- [References](#-references)

---

## 🎮 What is MSX?

**MSX** is a standardized home computer architecture created in **1983** by **ASCII Corporation** and **Microsoft**, widely adopted in Japan, Brazil, Europe, and the Middle East. It defined a common hardware standard so that software would run on any MSX machine regardless of manufacturer (Sony, Panasonic, Philips, Gradiente, Sharp…).

Key specifications of the **MSX1**:
| Component | Specification |
|-----------|--------------|
| CPU | Zilog Z80A @ 3.579 MHz |
| Video | Texas Instruments TMS9918A (NTSC/PAL) |
| Audio | General Instrument AY-3-8910 |
| RAM | Minimum 8KB (we implement 64KB) |
| ROM | 32KB BIOS + 16KB BASIC |
| Video RAM | 16KB |
| Colors | 15 + transparent |
| Resolution | 256×192 (graphics) / 40×24 (text) |
| Sprites | 32 sprites, 8×8 or 16×16 |

---

## ⚡ What is an FPGA?

An **FPGA** (Field-Programmable Gate Array) is a chip that you can program to **become any digital circuit** — including a complete computer from the 1980s.

Instead of software running on a fixed processor, an FPGA implements the **actual hardware logic** in parallel. Every component of the MSX (CPU, VDP, PSG, PPI) runs simultaneously, just like in the original machine.

The **Tang Nano 20K** from Sipeed uses a **Gowin GW2AR-18C** FPGA with:
- **20,736** Look-Up Tables (LUTs) — the basic building blocks
- **15,552** Flip-Flops (registers)
- **96** Block RAMs (18Kbit each)
- **2** Phase-Locked Loops (PLLs) for clock generation
- Onboard **HDMI** connector
- Onboard **microSD** slot
- Price: ~$20 USD

---

## 🛒 Hardware Requirements

| Item | Purpose | Cost (approx.) |
|------|---------|----------------|
| Tang Nano 20K | Main FPGA board | ~$20 |
| PS/2 keyboard (or USB→PS/2 adapter) | Input | ~$5 |
| HDMI monitor or TV | Display | — |
| microSD card (any size) | Storage | ~$3 |
| Breadboard + jumper wires | Connections | ~$3 |
| 2× 4.7kΩ resistors | PS/2 pull-up | ~$0.10 |
| 1× 100Ω + 1× 10µF capacitor | Audio filter | ~$0.20 |

**Total: under $35!**

---

## 🏗️ Architecture Overview

### 🔵 Z80 CPU

The **Zilog Z80** is the heart of every MSX computer. Our implementation is a **multi-cycle state machine** written entirely in Verilog — no black-box cores.

#### How the Z80 works:

Every instruction goes through **Machine Cycles (M-cycles)**, each composed of **T-states** (clock cycles):

```
FETCH (M1):  ┌─T1─┬─T2─┬─T3─┬─T4─┐
              │ PC →│    │Rfsh│    │  Reads opcode from memory
              │MREQ│Data│    │Exec│
              └────┴────┴────┴────┘

READ (MR):   ┌─T1─┬─T2─┬─T3─┐
              │ Addr│    │Data│  Reads a byte from memory
              └────┴────┴────┘

WRITE (MW):  ┌─T1─┬─T2─┬─T3─┐
              │ Addr│    │    │  Writes a byte to memory
              └────┴────┴────┘

I/O READ:    ┌─T1─┬─T2─┬─TW─┬─T3─┬─T4─┐
              │Port│    │Wait│Data│    │  Reads from I/O port
              └────┴────┴────┴────┴────┘
```

#### Instruction Groups:

| Prefix | Group | Examples |
|--------|-------|---------|
| (none) | Main set | `LD A,B` `ADD A,n` `JP nn` `CALL cc,nn` |
| `CB` | Bit operations | `RLC r` `BIT b,r` `SET b,r` `RES b,r` |
| `DD` | IX register | `LD IX,nn` `ADD IX,rp` `LD r,(IX+d)` |
| `FD` | IY register | `LD IY,nn` `LD (IY+d),r` |
| `ED` | Extended | `LDIR` `LDDR` `INI` `OUTI` `IM 2` `ADC HL,rp` |
| `DDCB` | IX bit ops | `BIT b,(IX+d)` `SET b,(IX+d)` |
| `FDCB` | IY bit ops | `BIT b,(IY+d)` `RES b,(IY+d)` |

#### Register File:

```
Main Bank:          Alternate Bank:
┌────┬────┐         ┌─────┬─────┐
│ A  │ F  │         │  A' │  F' │  ← swapped by EX AF,AF'
├────┼────┤         ├─────┼─────┤
│ B  │ C  │         │  B' │  C' │
├────┼────┤         ├─────┼─────┤  ← swapped by EXX
│ D  │ E  │         │  D' │  E' │
├────┼────┤         ├─────┼─────┤
│ H  │ L  │         │  H' │  L' │
└────┴────┘         └─────┴─────┘

Index:   IX [15:0]    IY [15:0]
Stack:   SP [15:0]    PC [15:0]
Special: I [7:0]  R [7:0]  IFF1  IFF2  IM[1:0]
```

#### Flags Register (F):

```
Bit:  7    6    5    4    3    2    1    0
      S    Z    Y    H    X    PV   N    C
      │    │    │    │    │    │    │    │
      │    │    │    │    │    │    │    └─ Carry
      │    │    │    │    │    │    └───── Add/Subtract
      │    │    │    │    │    └────────── Parity/Overflow
      │    │    │    │    └─────────────── Undocumented (bit 3 of result)
      │    │    │    └──────────────────── Half Carry
      │    │    └───────────────────────── Undocumented (bit 5 of result)
      │    └────────────────────────────── Zero
      └─────────────────────────────────── Sign
```

#### Interrupt Modes:

| Mode | How it works | MSX Usage |
|------|-------------|-----------|
| IM 0 | Device puts RST instruction on bus | Rare |
| **IM 1** | **Jumps to address 0x0038** | **VDP vertical sync (60 Hz)** |
| IM 2 | Jump table via I register + vector | Advanced software |

---

### 🟢 TMS9918A Video Display Processor

The **TMS9918A** from Texas Instruments generates video independently from the CPU. It has its own **16KB of VRAM** and generates NTSC/PAL composite video.

#### Video Modes:

**Screen 0 — Text Mode (40×24)**
```
┌────────────────────────────────────────┐
│ Character cell: 6×8 pixels             │
│ 40 columns × 24 rows = 960 characters  │
│ Single foreground color (R7 bits 7:4)  │
│ No sprites                             │
│                                        │
│  HELLO, MSX WORLD!                     │
└────────────────────────────────────────┘
```

**Screen 1 — Graphics I (32×24 tiles)**
```
┌────────────────────────────────────────┐
│ Character cell: 8×8 pixels             │
│ 32 columns × 24 rows = 768 characters  │
│ 2 colors per group of 8 characters     │
│ 32 sprites supported                   │
│                                        │
│  ████░░░░  ░░░░████  ████████          │
│  ██░░░░██  ██░░░░██  ██░░░░██          │
└────────────────────────────────────────┘
```

**Screen 2 — Graphics II (256×192 bitmap)**
```
┌────────────────────────────────────────┐
│ Full bitmap: 256 × 192 pixels          │
│ 2 colors per 8-pixel horizontal strip  │
│ Different colors for each 8-row band   │
│ 32 sprites supported                   │
│ Used by most MSX games                 │
└────────────────────────────────────────┘
```

**Screen 3 — Multicolor (64×48 blocks)**
```
┌────────────────────────────────────────┐
│ Each block = 4×4 pixels                │
│ Each block has its own color (16 opts) │
│ Simple but fast to draw                │
└────────────────────────────────────────┘
```

#### VRAM Memory Layout:

```
16KB VRAM Address Space:
┌──────────────────────────────────────────────┐
│ 0x0000 ─ Pattern Name Table (PNT)            │ R#2
│          Which character goes where           │
├──────────────────────────────────────────────┤
│ 0x0800 ─ Sprite Attribute Table (SAT)        │ R#5
│          Y, X, Pattern, Color for each sprite │
├──────────────────────────────────────────────┤
│ 0x1000 ─ Pattern Generator Table (PGT)       │ R#4
│          8 bytes define the shape of each     │
│          character (8×8 pixel bitmap)         │
├──────────────────────────────────────────────┤
│ 0x2000 ─ Color Table (CT)                    │ R#3
│          Foreground/background color pairs    │
├──────────────────────────────────────────────┤
│ 0x3800 ─ Sprite Pattern Table (SPT)          │ R#6
│          8 or 32 bytes per sprite pattern     │
└──────────────────────────────────────────────┘
```

#### The 15-Color MSX Palette:

```
Index │ Color Name      │ R    G    B
──────┼─────────────────┼──────────────
  0   │ Transparent     │  0    0    0
  1   │ Black           │  0    0    0
  2   │ Medium Green    │ 62   184   73
  3   │ Light Green     │116   212  128
  4   │ Dark Blue       │ 89   85   224
  5   │ Light Blue      │128  118  241
  6   │ Dark Red        │185   94   81
  7   │ Cyan            │101  219  239
  8   │ Medium Red      │219   101   89
  9   │ Light Red       │255  137  125
 10   │ Dark Yellow     │204  195   94
 11   │ Light Yellow    │222  208  135
 12   │ Dark Green      │ 58  162   65
 13   │ Magenta         │183   102  181
 14   │ Gray            │204  204  204
 15   │ White           │255  255  255
```

#### VDP Registers:

| Reg | Function |
|-----|---------|
| R0 | Mode bits M2, External video enable |
| R1 | Mode bits M1/M3, Blank, IE (interrupt enable), Sprite size/mag |
| R2 | Pattern Name Table base address |
| R3 | Color Table base address |
| R4 | Pattern Generator Table base address |
| R5 | Sprite Attribute Table base address |
| R6 | Sprite Pattern Table base address |
| R7 | Background/Text color |

---

### 🔴 AY-3-8910 Sound Chip

The **General Instrument AY-3-8910** generates 3-channel square wave audio with noise and envelope. It is the sound chip of the MSX, ZX Spectrum, and many arcade machines.

#### Internal Architecture:

```
                    AY-3-8910
         ┌───────────────────────────────┐
         │                               │
CPU ────▶│  Address Latch  ┌──────────┐  │
         │  R0–R15         │ Tone Gen │──┼──▶ Channel A
         │                 │ f = Fclk │  │
CPU ────▶│  Data Bus       │ ÷ (2×N)  │──┼──▶ Channel B
         │                 └──────────┘  │
         │                 ┌──────────┐  │──▶ Channel C
         │  Port A ──────▶ │ Noise    │  │
         │  (kbd row)      │ LFSR 17b │  │
         │  Port B ◀────── │          │  │
         │  (kbd col)      └──────────┘  │
         │                 ┌──────────┐  │
         │                 │ Envelope │  │
         │                 │ Gen      │  │
         └─────────────────┴──────────┘  │
```

#### Register Map:

| Reg | Bits | Function |
|-----|------|---------|
| R0 | 7:0 | Channel A tone period (low 8 bits) |
| R1 | 3:0 | Channel A tone period (high 4 bits) |
| R2 | 7:0 | Channel B tone period (low 8 bits) |
| R3 | 3:0 | Channel B tone period (high 4 bits) |
| R4 | 7:0 | Channel C tone period (low 8 bits) |
| R5 | 3:0 | Channel C tone period (high 4 bits) |
| R6 | 4:0 | Noise period |
| R7 | 5:0 | Mixer (enable tone/noise per channel) |
| R8 | 4:0 | Channel A volume (bit4=envelope mode) |
| R9 | 4:0 | Channel B volume |
| R10| 4:0 | Channel C volume |
| R11| 7:0 | Envelope period (low byte) |
| R12| 7:0 | Envelope period (high byte) |
| R13| 3:0 | Envelope shape |
| R14| 7:0 | Port A (output: keyboard row select) |
| R15| 7:0 | Port B (input: keyboard columns) |

#### Tone Frequency Formula:
```
f_tone = f_clock / (16 × N)

Where N = {R1[3:0], R0[7:0]} (12-bit period)
f_clock = 1.789 MHz (MSX standard)

Example: Middle A (440 Hz)
N = 1,789,000 / (16 × 440) ≈ 254
→ R0 = 0xFE, R1 = 0x00
```

---

### 🟡 Intel 8255 PPI

The **Programmable Peripheral Interface** (8255) connects the CPU to the keyboard matrix, cassette interface, and the **slot selection system**.

#### Ports:

```
PPI i8255
┌─────────────────────────────────────┐
│                                     │
│  Port A [7:0] ─── OUTPUT ──────────▶ Slot Selection
│  bits [1:0] = Page 0 slot (0-3)    │
│  bits [3:2] = Page 1 slot (0-3)    │
│  bits [5:4] = Page 2 slot (0-3)    │
│  bits [7:6] = Page 3 slot (0-3)    │
│                                     │
│  Port B [7:0] ─── INPUT ◀──────────  Keyboard Columns
│  bit 0 = Column 0 state            │ (active low)
│  bit 7 = Column 7 state            │
│                                     │
│  Port C [3:0] ─── OUTPUT ──────────▶ Keyboard Row Select
│  Port C [4]   ─── OUTPUT ──────────▶ Cassette audio out
│  Port C [5]   ─── OUTPUT ──────────▶ Cassette motor
│  Port C [6]   ─── OUTPUT ──────────▶ Caps Lock LED
│  Port C [7]   ─── OUTPUT ──────────▶ Click sound      
└─────────────────────────────────────┘
```

---

### 🟠 Memory & Slot System

The MSX uses a clever **slot banking system** that allows different hardware to appear in the same 64KB address space.

#### Address Space Division:

```
CPU Address Space (64KB)
┌──────────────────────────────────────────┐
│ Page 3: 0xC000–0xFFFF (16KB)            │
│         PPI_A[7:6] selects slot 0–3     │
├──────────────────────────────────────────┤
│ Page 2: 0x8000–0xBFFF (16KB)            │
│         PPI_A[5:4] selects slot 0–3     │
├──────────────────────────────────────────┤
│ Page 1: 0x4000–0x7FFF (16KB)            │
│         PPI_A[3:2] selects slot 0–3     │
├──────────────────────────────────────────┤
│ Page 0: 0x0000–0x3FFF (16KB)            │
│         PPI_A[1:0] selects slot 0–3     │
└──────────────────────────────────────────┘
```

#### Our Slot Assignment:

```
Slot 0 ──── ROM (BIOS + BASIC)
│           0x0000–0x7FFF = BIOS (32KB)
│           0x8000–0xBFFF = BASIC (16KB)

Slot 1 ──── Cartridge Slot A (not implemented → 0xFF)

Slot 2 ──── Cartridge Slot B (not implemented → 0xFF)

Slot 3 ──── RAM (64KB, all pages mirror)
```

#### Boot Sequence:
```
1. Reset: PPI_A = 0x00 → all pages select Slot 0 (ROM)
2. Z80 starts at 0x0000 → executes BIOS
3. BIOS initializes hardware, detects RAM
4. BIOS writes PPI_A = 0xC0 → Page 3 now points to Slot 3 (RAM)
5. Stack pointer moves to RAM (0xF380)
6. BIOS jumps to BASIC interpreter
```

---

### 🟣 HDMI Video Output

The Tang Nano 20K has an onboard HDMI connector. We use Gowin-specific primitives to serialize the TMDS signal.

#### Signal Chain:

```
TMS9918A          TMDS Encoder        OSER10              HDMI
RGB 4-bit ──────▶ 8b → 10b TMDS ───▶ 10:1 Serializer ──▶ Differential
                  (per DVI spec)       @ 135 MHz            Pair LVDS
                  
                  Blue  → D0 (+ sync)
                  Green → D1
                  Red   → D2
                  Clock → CLK pair
```

#### TMDS Encoding (simplified):

```
For DATA pixels:
1. Count 1s in byte → choose XOR or XNOR encoding
2. Build 9-bit q_m (bit 8 = XOR/XNOR flag)
3. Track running DC disparity
4. Invert q_m if needed to balance DC → 10-bit word

For SYNC (no data):
  00 → 1101010100
  01 → 0010101011
  10 → 0101010100
  11 → 1010101011
```

#### Video Timing (720×480p60):

```
Parameter       Value
──────────────────────
Pixel Clock     27.000 MHz
H Total         858 pixels
H Active        720 pixels
H Front Porch    16 pixels
H Sync           62 pixels
H Back Porch     60 pixels
V Total         525 lines
V Active        480 lines
V Front Porch     9 lines
V Sync            6 lines
V Back Porch     30 lines

TMS9918 content:  256×192 pixels
Displayed as:     512×384 (2× scale)
Centered in:      720×480 with 104px/48px borders
```

---

### 💾 SD Card

The SD card uses **SPI mode** (3-wire + CS), which is simpler than the native SD mode.

#### Initialization Sequence:

```
Power On
│
├─ Send 80 clock pulses with CS=HIGH (dummy clocks)
│
├─ CMD0 (GO_IDLE_STATE) → expect R1 = 0x01
│
├─ CMD8 (SEND_IF_COND) → check voltage range
│
├─ Repeat ACMD41 (APP_OP_COND) until R1 = 0x00
│   (can take hundreds of milliseconds)
│
└─ Card ready! Set to high-speed SPI
```

#### Reading a Sector:

```
CMD17 (READ_SINGLE_BLOCK, address)
│
├─ Response: R1 = 0x00
│
├─ Poll for data token 0xFE
│
├─ Read 512 bytes of sector data
│
└─ Read 2 bytes CRC (discard in SPI mode)
```

---

### ⌨️ PS/2 Keyboard

PS/2 uses a **synchronous serial protocol**: the keyboard drives the clock, and data is sampled on the falling edge.

#### Timing:

```
PS2_CLK: ─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─
          └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

PS2_DAT:  0  START│ D0  │ D1  │ D2  │ D3  │ D4  │ D5  │ D6  │ D7  │ P │ 1
                   └─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┴───┘
                   LSB first                                   Parity Stop
```

#### MSX Keyboard Matrix (11×8):

```
         Col7  Col6  Col5  Col4  Col3  Col2  Col1  Col0
Row  0:   7     6     5     4     3     2     1     0
Row  1:   ;     ]     [     \     =     -     9     8
Row  2:   B     A     /     .     ,     `    dead   —
Row  3:  F5    F4    F3    F2    F1   HOME   INS   DEL
Row  4:   U     Y     T     R     E     W     Q    TAB
Row  5:  RET  BKSP   @     P     O     I     —     —
Row  6:   L     K     J     H     G     F     D     S
Row  7:   :     Z     X     C     V     B     N     M
Row  8:  SPC   CAPS  GRPH  CTRL SHFT  F5    F4    F3  (shifted)
Row  9:  NUM   /     *     -     +     .     0     INS
Row 10:  STOP  SEL   PRINT PAUS  —     —    —     F5
```

---

### 🔊 Audio Output

The PSG produces 3 channels of digital audio summed to a 10-bit signal. We convert it to a 1-bit **PDM (Pulse Density Modulation)** stream using a sigma-delta modulator.

#### Sigma-Delta DAC:

```
10-bit PCM ──▶ Accumulator ──▶ Overflow bit = PDM output
              (11-bit wide)

PDM stream ──▶ RC Filter ──▶ Analog audio

Schematic:
                100Ω
FPGA pin ─────┤ R ├────┬──── Audio jack (+)
                       │
                      [C] 10µF
                       │
                      GND ──── Audio jack (-)
```

---

## ⏱️ Clock Architecture

```
27 MHz Crystal
     │
     ├──────────────────────────────────────────────┐
     │                                              │
  ┌──▼──────┐                                  ┌───▼───────┐
  │ PLL #1  │                                  │ PLL #2    │
  │ ×4 = 108│                                  │ ×5 = 135  │
  │   MHz   │                                  │   MHz     │
  └──┬──────┘                                  └───┬───────┘
     │                                             │
     ├─ ÷1 = 108 MHz ─── System logic             │
     │                                             │
     ├─ ÷30 = 3.6 MHz ── Z80 CPU clock enable     │
     │                                             │
     ├─ ÷60 = 1.8 MHz ── PSG clock enable         │
     │                                             │
     ├─ ÷4  = 27 MHz ─── VDP pixel clock          │
     │                                             │
     └─────────────────────────────────────────────┘
                         │
                         └─ 135 MHz TMDS serial clock (HDMI)
```

**PLL Configuration (Gowin rPLL):**

| PLL | Input | FBDIV | ODIV | Output |
|-----|-------|-------|------|--------|
| PLL1 | 27 MHz | 7 | 2 | **108 MHz** (27×8÷2) |
| PLL2 | 27 MHz | 9 | 2 | **135 MHz** (27×10÷2) |

---

## 🚀 Getting Started

### Step 1 — Install Gowin EDA

Download from the official Gowin website:
- 🔗 https://www.gowinsemi.com/en/support/download_eda/

You'll need to register (free) and request a free license.

### Step 2 — Get the BIOS

The MSX BIOS is copyrighted. We recommend **C-BIOS** — a free, open-source MSX BIOS:

```bash
# Download C-BIOS
wget https://sourceforge.net/projects/cbios/files/cbios-0.29a.zip
unzip cbios-0.29a.zip

# Convert to hex format for $readmemh
python3 tools/convert_rom.py cbios_main_msx1.rom bios/cbios_main_msx1.mem
```

### Step 3 — Clone this Repository

```bash
git clone https://github.com/YOUR_USERNAME/msx1-tang-nano-20k.git
cd msx1-tang-nano-20k
cp /path/to/cbios_main_msx1.mem bios/
```

### Step 4 — Open in Gowin EDA

1. Open Gowin EDA
2. **File → Open Project** → select `msx1_tang20k.gprj`
3. **Process → Synthesize**
4. **Process → Place & Route**
5. **Tools → Programmer → Program**

---

## 🔌 Hardware Connections

### Tang Nano 20K Pin Layout

```
                  Tang Nano 20K
        ┌─────────────────────────────┐
        │  USB-C                  LED │
        │   │                    ●  ● │
        │  [=]                        │
        │                             │
        │  ┌─────────────────────┐   │
        │  │                     │   │
        │  │    GW2AR-18C        │   │
        │  │    FPGA             │   │
        │  │                     │   │
        │  └─────────────────────┘   │
        │                             │
        │  [HDMI]        [microSD]   │
        │                             │
        │  PMOD1          PMOD2      │
        │  ●●●●●●●●●●●●  ●●●●●●●●●● │
        └─────────────────────────────┘
```

### PS/2 Keyboard Connection (PMOD1)

```
PS/2 Female Connector        PMOD1 Header
    ┌─────────────┐
    │  ● ●        │   Pin 1 (CLK) ─── PMOD1 Pin 1 ─── 4.7kΩ ─── 3.3V
    │ ● ●  ● ●   │   Pin 2 (DAT) ─── PMOD1 Pin 2 ─── 4.7kΩ ─── 3.3V
    │    ●  ●    │   Pin 3 (VCC) ─── PMOD1 Pin 6 (3.3V)
    └─────────────┘   Pin 4 (GND) ─── PMOD1 Pin 5 (GND)
    
    PS/2 Mini-DIN 6:
    Pin 1 = DATA     Pin 4 = VCC (+5V or +3.3V)
    Pin 3 = GND      Pin 5 = CLK
```

> ⚠️ **Pull-up resistors required!** PS/2 is open-collector. Without 4.7kΩ pull-ups on CLK and DATA, it won't work.

### Audio Connection (PMOD1 Pin 3)

```
PMOD1 Pin 3 ─── 100Ω ─── Audio+ ─── 3.5mm jack Tip
                     │
                   10µF
                     │
               GND ──┘──── 3.5mm jack Sleeve
```

### Complete PMOD1 Pinout

```
PMOD1:  1  2  3  4  5  6  7  8  9  10
        │  │  │  │  │  │
        │  │  │  │  │  └── 3.3V (VCC)
        │  │  │  │  └───── GND
        │  │  │  └──────── (free)
        │  │  └─────────── Audio PDM out
        │  └────────────── PS/2 DATA
        └───────────────── PS/2 CLK
```

---

## 🔨 Building & Flashing

### Method 1: Gowin EDA (Recommended for Beginners)

```
1. Open project → msx1_tang20k.gprj
2. Double-click "Synthesize" in Process panel
3. Double-click "Place & Route"  
4. Double-click "Generate Bitstream"
5. Open Programmer tool
6. Select impl/msx1_tang20k.fs
7. Click "Program/Configure"
```

### Method 2: Open Source Toolchain

```bash
# Install tools
pip install apycula  # Gowin bitstream tools
# Install yosys, nextpnr-himbaechel from your package manager

# Synthesize
yosys -p "synth_gowin -top top -json msx1.json" \
  src/top.v src/cpu/*.v src/vdp/*.v src/psg/*.v src/ppi/*.v \
  src/keyboard/*.v src/sdcard/*.v src/memory/*.v \
  src/video/*.v src/audio/*.v src/pll_*.v

# Place & Route
nextpnr-himbaechel \
  --json msx1.json \
  --write msx1_routed.json \
  --device GW2AR-LV18QN88C8/I7 \
  --vopt family=GW2AR-18 \
  --vopt cst=constraints/tang_nano_20k.cst

# Pack bitstream
gowin_pack msx1_routed.json -o msx1.fs

# Flash!
openFPGALoader -b tangnano20k msx1.fs
```

---

## 📁 File Structure

```
msx1-tang-nano-20k/
│
├── README.md                    ← You are here!
├── README.pt-BR.md              ← Português
├── README.es.md                 ← Español
├── README.fr.md                 ← Français
├── README.it.md                 ← Italiano
├── LICENSE                      ← MIT License
├── CONTRIBUTING.md              ← How to contribute
├── msx1_tang20k.gprj            ← Gowin EDA project file
│
├── src/                         ← All Verilog source files
│   ├── top.v                    ← Top-level: connects everything
│   ├── pll_108m.v               ← PLL: 27→108 MHz
│   ├── pll_135m.v               ← PLL: 27→135 MHz (HDMI TMDS)
│   │
│   ├── cpu/
│   │   ├── z80_cpu.v            ← Complete Z80 state machine
│   │   └── z80_alu.v            ← Z80 Arithmetic Logic Unit
│   │
│   ├── vdp/
│   │   └── tms9918a.v           ← Video Display Processor
│   │
│   ├── psg/
│   │   └── ay8910.v             ← Programmable Sound Generator
│   │
│   ├── ppi/
│   │   └── ppi8255.v            ← Programmable Peripheral Interface
│   │
│   ├── keyboard/
│   │   ├── ps2_decoder.v        ← PS/2 serial protocol decoder
│   │   └── msx_keymap.v         ← PS/2 → MSX matrix mapping
│   │
│   ├── sdcard/
│   │   ├── spi_master.v         ← SPI Master (low-level)
│   │   └── sd_ctrl.v            ← SD Card controller
│   │
│   ├── memory/
│   │   └── slot_ctrl.v          ← MSX slot/memory controller
│   │
│   ├── video/
│   │   ├── tmds_encoder.v       ← TMDS 8b10b encoder (HDMI)
│   │   └── hdmi_out.v           ← HDMI output (OSER10 + ELVDS)
│   │
│   └── audio/
│       └── pdm_dac.v            ← Sigma-delta 1-bit DAC
│
├── bios/
│   ├── README.txt               ← How to get C-BIOS
│   └── cbios_main_msx1.mem      ← C-BIOS in hex (add yourself)
│
├── constraints/
│   └── tang_nano_20k.cst        ← Pin assignments for the board
│
└── tools/
    └── convert_rom.py           ← Converts .ROM → .mem for Verilog
```

---

## 🗺️ IO Port Map

| Port(s) | Device | Access | Description |
|---------|--------|--------|-------------|
| `0x40`–`0x47` | SD Card | R/W | SPI data, CS, sector read |
| `0x98` | VDP | R/W | VRAM data read/write |
| `0x99` | VDP | R/W | Register write / Status read |
| `0xA0` | PSG | W | Write data to latched register |
| `0xA1` | PSG | W | Latch register address |
| `0xA2` | PSG | R | Read from latched register |
| `0xA8` | PPI | R/W | Port A: slot selection |
| `0xA9` | PPI | R | Port B: keyboard columns |
| `0xAA` | PPI | R/W | Port C: keyboard row + control |
| `0xAB` | PPI | W | Control word |

---

## 🗺️ Memory Map

```
0xFFFF ┬──────────────────────────────────────────┐
       │  Page 3 (PPI_A[7:6])                     │
       │  Default: Slot 3 → RAM                   │
0xC000 ┼──────────────────────────────────────────┤
       │  Page 2 (PPI_A[5:4])                     │
       │  Slot 0 → BASIC ROM (16KB)               │
0x8000 ┼──────────────────────────────────────────┤
       │  Page 1 (PPI_A[3:2])                     │
       │  Slot 0 → BIOS ROM high (16KB)           │
0x4000 ┼──────────────────────────────────────────┤
       │  Page 0 (PPI_A[1:0])                     │
       │  Slot 0 → BIOS ROM low (16KB)            │
0x0000 └──────────────────────────────────────────┘
```

---

## ⚠️ Known Limitations

| Feature | Status |
|---------|--------|
| Z80 CPU | ✅ Complete (all instruction groups) |
| TMS9918A Screen 0 | ✅ Text mode |
| TMS9918A Screen 1 | ✅ Graphics I |
| TMS9918A Screen 2 | ✅ Graphics II (bitmap) |
| TMS9918A Screen 3 | ✅ Multicolor |
| Sprites (basic) | ✅ 32 sprites, 8×8 and 16×16 |
| Sprite collision | ⚠️ Simplified |
| PSG sound | ✅ 3 channels + noise + envelope |
| PPI keyboard | ✅ Full matrix |
| PS/2 keyboard | ✅ Standard keys |
| HDMI 720×480p | ✅ Working |
| SD card read | ✅ Sector read via SPI |
| MSX-DOS / Nextor | ❌ Not implemented |
| Cartridge slot | ❌ Not implemented (returns 0xFF) |
| Expanded slots | ❌ Not implemented |
| Joystick port | ❌ Not implemented |
| Cassette interface | ❌ Not implemented |
| MSX2 upgrade | ❌ Future work |

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Areas needing help:**
- 🎮 Joystick/gamepad support (DB9)
- 💿 MSX-DOS disk controller
- 🔊 FM audio (YM2413)
- 🖥️ MSX2 VDP (V9938) upgrade
- 🧪 Simulation testbenches
- 📚 Documentation improvements

---

## 📚 References

### MSX Standard
- [MSX Technical Handbook](https://konamiman.github.io/MSX2-Technical-Handbook/) — The definitive MSX reference
- [MSX.org](https://www.msx.org/) — MSX community and software archive
- [C-BIOS](https://cbios.sourceforge.net/) — Open source MSX BIOS

### Hardware Datasheets
- [Z80 CPU User Manual](https://www.zilog.com/docs/z80/um0080.pdf) — Zilog official
- [TMS9918A Datasheet](http://www.unige.ch/medecine/nouspikel/ti99/tms9918a.htm) — Video chip
- [AY-3-8910 Datasheet](https://www.ym2149.com/ay8910.pdf) — Sound chip
- [Intel 8255 Datasheet](https://datasheetspdf.com/datasheet/8255.html) — PPI

### FPGA & Board
- [Tang Nano 20K Wiki](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html)
- [GW2AR-18C Datasheet](https://www.gowinsemi.com/en/product/detail/52/)
- [Gowin EDA Manual](https://www.gowinsemi.com/en/support/database/15/)
- [DVI/HDMI TMDS Specification](https://glenwing.github.io/docs/DVI-1.0.pdf)

### Similar Projects (Inspiration)
- [MSX1FPGA](https://github.com/MiSTer-devel/MSX_MiSTer) — MSX on MiSTer
- [OneChipMSX](http://www.msx.org/wiki/One_Chip_MSX) — Classic FPGA MSX
- [T80 Z80 Core](https://opencores.org/projects/t80) — Reference Z80 in VHDL

---

## 📊 FPGA Resource Utilization (Estimated)

| Resource | Used | Available | % |
|----------|------|-----------|---|
| LUTs | ~10,000 | 20,736 | ~48% |
| Flip-Flops | ~4,000 | 15,552 | ~26% |
| Block RAM | ~8 | 96 | ~8% |
| PLLs | 2 | 2 | 100% |
| DSP | 0 | 46 | 0% |

---

<div align="center">

**Made with ❤️ for the MSX and FPGA community**

⭐ If this project helped you, please star it on GitHub! ⭐

</div>
