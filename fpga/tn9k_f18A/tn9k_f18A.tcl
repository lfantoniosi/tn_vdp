add_file -type verilog "src/gowin/clk_100.v"
add_file -type verilog "src/gowin/clk_125.v"
add_file -type verilog "src/gowin/dvi_tx.v"
add_file -type verilog "src/top.v"
add_file -type vhdl "src/f18a_color.vhd"
add_file -type vhdl "src/f18a_core.vhd"
add_file -type vhdl "src/f18a_counters.vhd"
add_file -type vhdl "src/f18a_cpu.vhd"
add_file -type vhdl "src/f18a_div32x16.vhd"
add_file -type vhdl "src/f18a_gpu.vhd"
add_file -type vhdl "src/f18a_single_port_ram.vhd"
add_file -type vhdl "src/f18a_sprites.vhd"
add_file -type vhdl "src/f18a_tile_linebuf.vhd"
add_file -type vhdl "src/f18a_tiles.vhd"
add_file -type vhdl "src/f18a_top.vhd"
add_file -type vhdl "src/f18a_version.vhd"
add_file -type vhdl "src/f18a_vga_cont_640_60.vhd"
add_file -type vhdl "src/f18a_vram.vhd"
add_file -type cst "src/tn9k_f18A.cst"
add_file -type sdc "src/tn9k_f18A.sdc"
set_device GW1NR-LV9QN88PC6/I5 -device_version C
set_option -synthesis_tool gowinsynthesis
set_option -output_base_name tn9k_f18A
set_option -top_module top
set_option -place_option 1
set_option -route_option 1
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -loading_rate 250/10
run all
