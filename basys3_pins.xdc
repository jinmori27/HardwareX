## ============================================================================
## HomeGuardX v2.0 — Basys3 Pin Constraints (XDC)
## Target: XC7A35T-1CPG236C
## ============================================================================

## ---- System Clock (100 MHz) ----
set_property PACKAGE_PIN W5  [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk -period 10.00 -waveform {0 5} [get_ports clk]

## ---- Reset (active-low, active button = BTNC directly or inverted) ----
set_property PACKAGE_PIN U18 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

## ---- Switches (sw[15:0]) ----
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw[3]}]
set_property PACKAGE_PIN W15 [get_ports {sw[4]}]
set_property PACKAGE_PIN V15 [get_ports {sw[5]}]
set_property PACKAGE_PIN W14 [get_ports {sw[6]}]
set_property PACKAGE_PIN W13 [get_ports {sw[7]}]
set_property PACKAGE_PIN V2  [get_ports {sw[8]}]
set_property PACKAGE_PIN T3  [get_ports {sw[9]}]
set_property PACKAGE_PIN T2  [get_ports {sw[10]}]
set_property PACKAGE_PIN R3  [get_ports {sw[11]}]
set_property PACKAGE_PIN W2  [get_ports {sw[12]}]
set_property PACKAGE_PIN U1  [get_ports {sw[13]}]
set_property PACKAGE_PIN T1  [get_ports {sw[14]}]
set_property PACKAGE_PIN R2  [get_ports {sw[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sw[*]}]

## ---- Buttons ----
set_property PACKAGE_PIN U18 [get_ports {btn[0]}]
set_property PACKAGE_PIN T18 [get_ports {btn[1]}]
set_property PACKAGE_PIN W19 [get_ports {btn[2]}]
set_property PACKAGE_PIN T17 [get_ports {btn[3]}]
set_property PACKAGE_PIN U17 [get_ports {btn[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {btn[*]}]

## ---- LEDs (led[15:0]) ----
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property PACKAGE_PIN V14 [get_ports {led[7]}]
set_property PACKAGE_PIN V13 [get_ports {led[8]}]
set_property PACKAGE_PIN V3  [get_ports {led[9]}]
set_property PACKAGE_PIN W3  [get_ports {led[10]}]
set_property PACKAGE_PIN U3  [get_ports {led[11]}]
set_property PACKAGE_PIN P3  [get_ports {led[12]}]
set_property PACKAGE_PIN N3  [get_ports {led[13]}]
set_property PACKAGE_PIN P1  [get_ports {led[14]}]
set_property PACKAGE_PIN L1  [get_ports {led[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

## ---- 7-Segment Display ----
set_property PACKAGE_PIN W7  [get_ports {seg[0]}]
set_property PACKAGE_PIN W6  [get_ports {seg[1]}]
set_property PACKAGE_PIN U8  [get_ports {seg[2]}]
set_property PACKAGE_PIN V8  [get_ports {seg[3]}]
set_property PACKAGE_PIN U5  [get_ports {seg[4]}]
set_property PACKAGE_PIN V5  [get_ports {seg[5]}]
set_property PACKAGE_PIN U7  [get_ports {seg[6]}]
set_property PACKAGE_PIN V7  [get_ports dp]
set_property PACKAGE_PIN U2  [get_ports {an[0]}]
set_property PACKAGE_PIN U4  [get_ports {an[1]}]
set_property PACKAGE_PIN V4  [get_ports {an[2]}]
set_property PACKAGE_PIN W4  [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports dp]
set_property IOSTANDARD LVCMOS33 [get_ports {an[*]}]

## ---- PIR & Door Sensors (directly on Pmod header or GPIO) ----
## Using two spare pins on Pmod JA upper row (pins 3-4)
set_property PACKAGE_PIN A14 [get_ports pir_sensor]
set_property PACKAGE_PIN A16 [get_ports door_sensor]
set_property IOSTANDARD LVCMOS33 [get_ports pir_sensor]
set_property IOSTANDARD LVCMOS33 [get_ports door_sensor]

## ---- Keypad 4x4 (Pmod JA) ----
## Rows = outputs, Cols = inputs
set_property PACKAGE_PIN J1  [get_ports {kp_row[0]}]
set_property PACKAGE_PIN L2  [get_ports {kp_row[1]}]
set_property PACKAGE_PIN J2  [get_ports {kp_row[2]}]
set_property PACKAGE_PIN G2  [get_ports {kp_row[3]}]
set_property PACKAGE_PIN H1  [get_ports {kp_col[0]}]
set_property PACKAGE_PIN K2  [get_ports {kp_col[1]}]
set_property PACKAGE_PIN H2  [get_ports {kp_col[2]}]
set_property PACKAGE_PIN G3  [get_ports {kp_col[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kp_row[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {kp_col[*]}]
set_property PULLDOWN true [get_ports {kp_col[*]}]

## ---- OLED I2C (Pmod JB, pins 1-2) ----
set_property PACKAGE_PIN A14 [get_ports oled_scl]
set_property PACKAGE_PIN A15 [get_ports oled_sda]
set_property IOSTANDARD LVCMOS33 [get_ports oled_scl]
set_property IOSTANDARD LVCMOS33 [get_ports oled_sda]
set_property PULLUP true [get_ports oled_scl]
set_property PULLUP true [get_ports oled_sda]

## ---- RS-485 Link (Pmod JC, pins 1-2) ----
set_property PACKAGE_PIN K17 [get_ports rs485_a]
set_property PACKAGE_PIN M18 [get_ports rs485_b]
set_property IOSTANDARD LVCMOS33 [get_ports rs485_a]
set_property IOSTANDARD LVCMOS33 [get_ports rs485_b]

## ---- PWM Fan Output + TACH (Pmod JD, pins 1-2) ----
set_property PACKAGE_PIN H4  [get_ports pwm_fan_out]
set_property PACKAGE_PIN H1  [get_ports fan_tach_in]
set_property IOSTANDARD LVCMOS33 [get_ports pwm_fan_out]
set_property IOSTANDARD LVCMOS33 [get_ports fan_tach_in]

## ---- ADC Interface (Pmod JD, pins 3-6) ----
set_property PACKAGE_PIN G1  [get_ports adc_cs_n]
set_property PACKAGE_PIN G3  [get_ports adc_sclk]
set_property PACKAGE_PIN H2  [get_ports adc_miso]
set_property PACKAGE_PIN G4  [get_ports {adc_ch_sel[0]}]
set_property PACKAGE_PIN G2  [get_ports {adc_ch_sel[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports adc_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports adc_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports adc_miso]
set_property IOSTANDARD LVCMOS33 [get_ports {adc_ch_sel[*]}]

## ---- DHT22 (bidirectional, Pmod JD pin 7) ----
set_property PACKAGE_PIN F4  [get_ports dht22_data]
set_property IOSTANDARD LVCMOS33 [get_ports dht22_data]
set_property PULLUP true [get_ports dht22_data]

## ---- Room Lights & Buzzer (directly on spare GPIO) ----
set_property PACKAGE_PIN B18 [get_ports room_lights]
set_property PACKAGE_PIN A18 [get_ports buzzer_out]
set_property IOSTANDARD LVCMOS33 [get_ports room_lights]
set_property IOSTANDARD LVCMOS33 [get_ports buzzer_out]

## ---- Bitstream Configuration ----
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
