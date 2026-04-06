## ============================================================================
## HomeGuardX v2.0 — Timing Constraints
## ============================================================================

## Primary clock already defined in basys3_pins.xdc
## create_clock -add -name sys_clk -period 10.00 [get_ports clk]

## ---- Input delay constraints (external sensors, buttons, switches) ----
## Assume max 10ns input delay from board-level routing
set_input_delay -clock sys_clk -max 10.0 [get_ports {sw[*]}]
set_input_delay -clock sys_clk -max 10.0 [get_ports {btn[*]}]
set_input_delay -clock sys_clk -max 10.0 [get_ports pir_sensor]
set_input_delay -clock sys_clk -max 10.0 [get_ports door_sensor]
set_input_delay -clock sys_clk -max 10.0 [get_ports {kp_col[*]}]
set_input_delay -clock sys_clk -max 10.0 [get_ports rs485_b]
set_input_delay -clock sys_clk -max 10.0 [get_ports fan_tach_in]
set_input_delay -clock sys_clk -max 10.0 [get_ports adc_miso]

## ---- Output delay constraints ----
set_output_delay -clock sys_clk -max 8.0 [get_ports {led[*]}]
set_output_delay -clock sys_clk -max 8.0 [get_ports {seg[*]}]
set_output_delay -clock sys_clk -max 8.0 [get_ports {an[*]}]
set_output_delay -clock sys_clk -max 8.0 [get_ports {kp_row[*]}]
set_output_delay -clock sys_clk -max 8.0 [get_ports oled_scl]
set_output_delay -clock sys_clk -max 8.0 [get_ports oled_sda]
set_output_delay -clock sys_clk -max 8.0 [get_ports rs485_a]
set_output_delay -clock sys_clk -max 8.0 [get_ports pwm_fan_out]
set_output_delay -clock sys_clk -max 8.0 [get_ports adc_cs_n]
set_output_delay -clock sys_clk -max 8.0 [get_ports adc_sclk]
set_output_delay -clock sys_clk -max 8.0 [get_ports {adc_ch_sel[*]}]
set_output_delay -clock sys_clk -max 8.0 [get_ports room_lights]
set_output_delay -clock sys_clk -max 8.0 [get_ports buzzer_out]

## ---- False paths for async inputs (buttons, sensors) ----
## These are asynchronous and will be synchronized internally
set_false_path -from [get_ports {btn[*]}]
set_false_path -from [get_ports pir_sensor]
set_false_path -from [get_ports door_sensor]
set_false_path -from [get_ports {kp_col[*]}]
set_false_path -from [get_ports fan_tach_in]
