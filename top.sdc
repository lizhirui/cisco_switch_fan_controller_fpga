#************************************************************
# THIS IS A WIZARD-GENERATED FILE.                           
#
# Version 13.0.0 Build 156 04/24/2013 SJ Full Version
#
#************************************************************

# Copyright (C) 1991-2013 Altera Corporation
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, Altera MegaCore Function License 
# Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the 
# applicable agreement for further details.



# Clock constraints

create_clock -name "clk" -period 20.000ns [get_ports {clk}]


# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty to jitter and other effects.
derive_clock_uncertainty

# tsu/th constraints

# tco constraints

# tpd constraints

set_false_path -from [get_ports {rst_n}]
set_false_path -from [get_ports {uart_rxd}]
set_false_path -from [get_ports {key_*}]
set_false_path -from [get_ports {cisco_fan1234_pwm}]
set_false_path -from [get_ports {cisco_fan5678_pwm}]
set_false_path -from [get_ports {cisco_led_status_green}]
set_false_path -from [get_ports {cisco_led_status_red}]

set_false_path -from [get_ports {main_fan_fb[*]}]
set_false_path -from [get_ports {lcd_rom_so}]
set_false_path -from [get_ports {eeprom_sda}]

set_false_path -to [get_ports {cisco_fan_fb[*]}]
set_false_path -to [get_ports {main_fan_pwm[*]}]
set_false_path -to [get_ports {uart_txd}]

set_false_path -to [get_ports {eeprom_addr[*]}]
set_false_path -to [get_ports {eeprom_scl}]
set_false_path -to [get_ports {eeprom_sda}]
set_false_path -to [get_ports {eeprom_wp}]

set_false_path -to [get_ports {lcd_cs}]
set_false_path -to [get_ports {lcd_leda_pwm}]
set_false_path -to [get_ports {lcd_rom_cs}]
set_false_path -to [get_ports {lcd_rom_sck}]
set_false_path -to [get_ports {lcd_rom_si}]
set_false_path -to [get_ports {lcd_rs}]
set_false_path -to [get_ports {lcd_rst}]
set_false_path -to [get_ports {lcd_sclk}]
set_false_path -to [get_ports {lcd_sda}]