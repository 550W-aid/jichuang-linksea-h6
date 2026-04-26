create_clock -name "sys_clk" -period 20.000 [get_ports {sys_clk}]
create_clock -name "ov5640_pclk" -period 12.500 [get_ports {ov5640_pclk}]

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

set_false_path -from [get_clocks {sys_clk}] -to [get_clocks {ov5640_pclk}]
set_false_path -from [get_clocks {ov5640_pclk}] -to [get_clocks {sys_clk}]

set_false_path -from [get_clocks {\clk_gen:clk_gen_inst|altpll:altpll_component|_clk0}] -to [get_clocks {ov5640_pclk}]
set_false_path -from [get_clocks {ov5640_pclk}] -to [get_clocks {\clk_gen:clk_gen_inst|altpll:altpll_component|_clk0}]

set_false_path -from [get_clocks {\clk_gen2:clk_gen_inst2|altpll:altpll_component|_clk0}] -to [get_clocks {ov5640_pclk}]
set_false_path -from [get_clocks {ov5640_pclk}] -to [get_clocks {\clk_gen2:clk_gen_inst2|altpll:altpll_component|_clk0}]

set_false_path -from [get_clocks {\ov5640_top:ov5640_top_inst|i2c_ctrl:i2c_ctrl_inst|i2c_clk}] -to [get_clocks {ov5640_pclk}]
set_false_path -from [get_clocks {ov5640_pclk}] -to [get_clocks {\ov5640_top:ov5640_top_inst|i2c_ctrl:i2c_ctrl_inst|i2c_clk}]

set_false_path -from [get_ports {sys_rst_n}]
