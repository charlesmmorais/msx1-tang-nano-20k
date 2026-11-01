# Contributing to MSX1 Tang Nano 20K

Thank you for your interest in contributing! 🎮

## Ways to Contribute

- **Bug reports** — open an Issue describing the problem
- **Fix a bug** — open a Pull Request with the fix
- **New feature** — discuss in an Issue first, then PR
- **Documentation** — translations, corrections, additions
- **Testing** — report compatibility with MSX software

## Development Guidelines

### Code Style (Verilog)
- 4-space indentation
- `snake_case` for signal names
- Comment every module port
- Use `localparam` instead of `define` when possible
- Active-low signals end in `_n` (e.g., `rst_n`, `cs_n`)

### Commit Messages
```
feat: add MSX2 V9938 VDP mode
fix: correct sprite early-clock offset
docs: add wiring diagram for PS/2 adapter
test: add simulation for sprite overflow
```

### Pull Request Process
1. Fork the repo and create a branch from `main`
2. Make your changes with clear commit messages
3. Run the system simulation: `sh sim/run.sh` must print `PASS`
4. Update documentation if needed
5. Open a PR describing what changed and why

## Reporting Bugs

Include:
- Tang Nano 20K revision
- Gowin EDA version
- MSX software being tested
- Description of expected vs actual behavior
- If possible: oscilloscope screenshots or simulation waveforms

## Areas Needing Help

- [ ] MSX2 VDP (V9938) upgrade
- [ ] FM audio (YM2413/OPL)
- [ ] Expanded slot support
- [ ] More testbenches (VDP modes, PSG output, C-BIOS boot)
- [ ] Cartridge slot (ROM loading from SD or flash)
- [ ] MSX-DOS / Nextor disk controller
- [ ] Joystick port (DB9)
- [ ] Cassette interface

## Questions?

Open a Discussion on GitHub — we're happy to help!
