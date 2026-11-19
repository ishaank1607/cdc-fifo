set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports clk]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports btnC]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN V16 IOSTANDARD LVCMOS33} [get_ports {sw[1]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {led[4]}]
create_clock -period 10.000 -name sys_clk [get_ports clk]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# the two MMCM outputs are unrelated for CDC purposes
set_clock_groups -asynchronous -group [get_clocks clk_out1_clk_wiz_0*] -group [get_clocks clk_out2_clk_wiz_0*]
set_false_path -from [get_ports {btnC {sw[*]}}]
set_false_path -to [get_ports {led[*]}]
create_waiver -type CDC -id {CDC-1} -user "ishaan" -desc "FIFO memory read path: data is stable before rempty deasserts (pointer crosses 2 synchronizer stages after the write)" -from [get_pins u_fifo/mem_reg_0_15_0_5/RAMC_D1/CLK] -to [get_pins err_reg/CE] -timestamp "Wed Nov 18 23:14:28 GMT 2026"
