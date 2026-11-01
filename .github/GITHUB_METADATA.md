# GitHub Repository Metadata

## Repository Name (suggested)
```
msx1-tang-nano-20k
```

## Description (160 chars max)
```
MSX1 computer in Verilog for the Tang Nano 20K FPGA — Z80, TMS9918A VDP, AY-3-8910 PSG, HDMI, PS/2 keyboard, 64 KB RAM in SDRAM.
```

## Topics (add these in GitHub repository settings)
```
fpga
msx
msx1
z80
verilog
gowin
tang-nano-20k
tms9918a
ay-3-8910
hdmi
retro-computing
retro-gaming
home-computer
8-bit
fpga-implementation
sipeed
gw2ar-18
ps2-keyboard
sd-card
open-source-hardware
```

## Website
```
https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html
```

## Social Preview Image
Use an image showing:
- The Tang Nano 20K board
- An MSX game or BASIC prompt on the HDMI output
- The PS/2 keyboard connected

## README Badges to Add (copy to README.md header)
```markdown
[![Stars](https://img.shields.io/github/stars/YOUR_USERNAME/msx1-tang-nano-20k?style=social)](https://github.com/YOUR_USERNAME/msx1-tang-nano-20k)
[![Forks](https://img.shields.io/github/forks/YOUR_USERNAME/msx1-tang-nano-20k?style=social)](https://github.com/YOUR_USERNAME/msx1-tang-nano-20k/fork)
[![Issues](https://img.shields.io/github/issues/YOUR_USERNAME/msx1-tang-nano-20k)](https://github.com/YOUR_USERNAME/msx1-tang-nano-20k/issues)
[![Last Commit](https://img.shields.io/github/last-commit/YOUR_USERNAME/msx1-tang-nano-20k)](https://github.com/YOUR_USERNAME/msx1-tang-nano-20k)
```

## Suggested Repository Settings
- Visibility: Public
- Enable Issues: ✅
- Enable Discussions: ✅ (great for community questions)
- Enable Wiki: ❌ (use README files instead)
- Enable Sponsorships: ✅ (optional)
- Default branch: main
- Add License: MIT (already in repo)

## Release Strategy
v0.1.0 — Initial release
  - MSX1 core functional
  - C-BIOS boots to BASIC
  - HDMI, PS/2, SD card working

v0.2.0 — Cartridge support
  - ROM cartridge loading from SD card
  - Megarom mapper support

v0.3.0 — MSX-DOS
  - Nextor disk controller
  - FAT16/FAT32 reading

v1.0.0 — Stable release
  - Full MSX1 compatibility
  - Tested game list

v2.0.0 — MSX2
  - V9938 VDP upgrade
  - FM sound (YM2413)
  - RAM expansion
