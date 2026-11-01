#!/bin/sh
# System simulation with Icarus Verilog. Run from the repository root:
#   sh sim/run.sh
set -e
python3 sim/make_test_rom.py 2>/dev/null || python sim/make_test_rom.py
iverilog -g2005 -Wall -Wno-timescale -Wno-implicit-dimensions -o sim/tb_top.vvp \
    -DROM_FILE=\"sim/test_rom.mem\" \
    sim/tb_top.v sim/gowin_stubs.v sim/sdram_model.v \
    src/top.v src/pll_135m.v src/cpu/tv80_msx.v \
    src/cpu/tv80/tv80_core.v src/cpu/tv80/tv80_alu.v src/cpu/tv80/tv80_mcode.v src/cpu/tv80/tv80_reg.v \
    src/memory/slot_ctrl.v src/memory/sdram_ctrl.v src/vdp/tms9918a.v \
    src/video/tmds_encoder.v src/video/hdmi_out.v src/psg/ay8910.v src/ppi/ppi8255.v \
    src/keyboard/ps2_decoder.v src/keyboard/msx_keymap.v src/sdcard/sd_spi.v src/audio/pdm_dac.v
vvp -n sim/tb_top.vvp
