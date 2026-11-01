# Command-line build with Gowin EDA (run from the repository root):
#   gw_sh scripts/build.tcl
# Output bitstream: impl/pnr/msx1_tang20k.fs
# Needs bios/msx_rom.mem (see tools/make_rom.py).

set_device GW2AR-LV18QN88C8/I7 -device_version C

add_file src/top.v
add_file src/pll_135m.v
add_file src/cpu/tv80_msx.v
add_file src/cpu/tv80/tv80_core.v
add_file src/cpu/tv80/tv80_alu.v
add_file src/cpu/tv80/tv80_mcode.v
add_file src/cpu/tv80/tv80_reg.v
add_file src/memory/slot_ctrl.v
add_file src/memory/sdram_ctrl.v
add_file src/vdp/tms9918a.v
add_file src/video/tmds_encoder.v
add_file src/video/hdmi_out.v
add_file src/psg/ay8910.v
add_file src/ppi/ppi8255.v
add_file src/keyboard/ps2_decoder.v
add_file src/keyboard/msx_keymap.v
add_file src/sdcard/sd_spi.v
add_file src/audio/pdm_dac.v
add_file constraints/tang_nano_20k.cst

set_option -top_module top
set_option -verilog_std v2001
set_option -output_base_name msx1_tang20k
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -use_ready_as_gpio 1
set_option -use_done_as_gpio 1

run all
