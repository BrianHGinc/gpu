#**************************************************************
# This .sdc file is created by Terasic Tool.
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
create_clock -period "10.0 MHz" [get_ports ADC_CLK_10]
create_clock -period "50.0 MHz" [get_ports MAX10_CLK1_50]
create_clock -period "50.0 MHz" [get_ports MAX10_CLK2_50]

#create_clock -period "100 MHz"  [get_nets {SDInterface:SID|SDWriter:SDWriter_inst|SDCmdCtrl:sd_cmd_ctrl_inst|sdclk}]

#**************************************************************
# Create Generated Clock
#**************************************************************
derive_pll_clocks


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty

#Specify the required tSU
set tSU 0.500
#Specify the required tH
set tH  2.000

#Specify the required tCO
#Use -7.5 for -6 Altera FPGA
#Use -8.0 for -7 Altera FPGA
#Use -8.5 for -8 Altera FPGA
set tCO  -7.500
#Specify the required tCOm
set tCOm -3.800


##**************************************************************
## Set Input Delay
##**************************************************************

set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[2]}]             -max -add_delay $tSU [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[2]}]             -min -add_delay $tH  [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[2]}] -clock_fall -max -add_delay $tSU [get_ports {DDR3_DQ*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[2]}] -clock_fall -min -add_delay $tH  [get_ports {DDR3_DQ*[*]}]

set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tSU  [get_ports {GPIO*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tH   [get_ports {GPIO*[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tSU  [get_ports {KEY[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tH   [get_ports {KEY[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tSU  [get_ports {SW[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tH   [get_ports {SW[*]}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tSU  [get_ports {HDMI_I2C_SDA}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tH   [get_ports {HDMI_I2C_SDA}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tSU  [get_ports {HDMI_TX_INT}]
set_input_delay  -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tH   [get_ports {HDMI_TX_INT}]


##**************************************************************
## Set Output Delay
##**************************************************************

set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[0]}] -max $tCO              [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[0]}] -max $tCO  -clock_fall [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[0]}] -min $tCOm             [get_ports {DDR3*}] -add_delay
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[0]}] -min $tCOm -clock_fall [get_ports {DDR3*}] -add_delay

set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tCO  [get_ports {GPIO*[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tCOm [get_ports {GPIO*[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[4]}] -max $tCO  [get_ports {LED[*]}]
set_output_delay -clock [get_clocks {*DDR3_PLL5*clk[4]}] -min $tCOm [get_ports {LED[*]}]

set_output_delay -clock [get_clocks {*VGA_SW_216_297*clk[0]}] -max $tCO  [get_ports {HDMI*}]
set_output_delay -clock [get_clocks {*VGA_SW_216_297*clk[0]}] -min $tCOm [get_ports {HDMI*}]

#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

# Separate VGA output video pixel clock from the main system clock and CLK_In 50Mhz clock.
set_false_path -from [get_clocks {*DDR3_PLL5*}] -to [get_clocks {VGA_PLL*}]
set_false_path -from [get_clocks {VGA_PLL*}] -to [get_clocks {*DDR3_PLL5*}]
set_false_path -from [get_clocks {VGA_PLL*}] -to [get_clocks {MAX10_CLK1_50}]
set_false_path -from [get_clocks {MAX10_CLK1_50}] -to [get_clocks {VGA_PLL*}]



# Separate the fake SD Card clock
#set_false_path -from [get_clocks {*}] -to [get_clocks SID|SDWriter:SDWriter_inst|SDCmdCtrl:sd_cmd_ctrl_inst|sdclk}]
#set_false_path -from [get_clocks {SID|SDWriter:SDWriter_inst|SDCmdCtrl:sd_cmd_ctrl_inst|sdclk}] -to [get_clocks {*}]


# Optional: Separate the reset and low frequency inputs on the CLK_IN 50Mhz from the core.
set_false_path -from [get_clocks {MAX10_CLK1_50}] -to [get_clocks {*DDR3_PLL5*clk[4]}]
set_false_path -from [get_clocks {*DDR3_PLL5*clk[4]}] -to [get_clocks {MAX10_CLK1_50}]


#**************************************************************
# Set Multicycle Path
#**************************************************************

# The BHG_VGA_HWREGS go all over the place and cross clock domains, but, they are not timing important as they control static or once every V-Sync graphic setting.
# multicycle is safer than set_false_path since it guarantees data arrival within the set number of clock cycles instead of any random amount of time.
set_multicycle_path -setup -end -from  {*BHG_VGA_HWREGS|HW_REGS*} -to {*} 2
set_multicycle_path -from              {*BHG_VGA_HWREGS|HW_REGS*} -to {*} -hold -end 1


#**************************************************************
# Set Maximum Delay
#**************************************************************


#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************
