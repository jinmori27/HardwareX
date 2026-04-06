// ============================================================================
// HomeGuardX v2.0 — Top Level Controller
// Pure interconnect wrapper: instantiates all modules, connects HMCB,
// routes physical I/O pins. Contains no combinational logic itself.
// Target: Xilinx Artix-7 (Basys3 / Nexys A7) @ 100MHz
// ============================================================================
`timescale 1ns / 1ps

module top_level_controller (
    input  wire        clk,            // 100 MHz system clock
    input  wire        rst_n,          // Active-low async reset (active-low button)

    // ---- Physical I/O: Switches & Buttons ----
    input  wire [15:0] sw,             // 16 switches
    input  wire [4:0]  btn,            // 5 buttons (center=load, others=user)

    // ---- Physical I/O: LEDs ----
    output wire [15:0] led,

    // ---- Physical I/O: 7-segment (optional, directly from config) ----
    output wire [6:0]  seg,
    output wire [3:0]  an,
    output wire        dp,

    // ---- Physical I/O: Security sensors ----
    input  wire        pir_sensor,
    input  wire        door_sensor,

    // ---- Physical I/O: Keypad (Pmod JA) ----
    output wire [3:0]  kp_row,
    input  wire [3:0]  kp_col,

    // ---- Physical I/O: OLED I2C (Pmod JB) ----
    inout  wire        oled_sda,
    output wire        oled_scl,

    // ---- Physical I/O: RS-485 Link (Pmod JC) ----
    output wire        rs485_a,        // RS-485 differential A (directly tx)
    input  wire        rs485_b,        // RS-485 differential B (directly rx)

    // ---- Physical I/O: PWM Fan (Pmod JD) ----
    output wire        pwm_fan_out,
    input  wire        fan_tach_in,

    // ---- Physical I/O: Multi-Sensor Hub ADC ----
    output wire        adc_cs_n,
    output wire        adc_sclk,
    input  wire        adc_miso,
    output wire [1:0]  adc_ch_sel,

    // ---- Physical I/O: DHT22 ----
    inout  wire        dht22_data,

    // ---- Physical I/O: Room lights & buzzer ----
    output wire        room_lights,
    output wire        buzzer_out
);

    `include "hmcb_pkg.vh"

    // ========================================================================
    // HMCB Bus Wires
    // ========================================================================
    wire [31:0] hmcb_bus;
    wire        hmcb_bus_valid;

    // Per-module TX lines
    wire [31:0] tx_core_w;       wire tx_core_valid_w;
    wire [31:0] tx_timer_w;      wire tx_timer_valid_w;
    wire [31:0] tx_config_w;     wire tx_config_valid_w;
    wire [31:0] tx_intruder_w;   wire tx_intruder_valid_w;
    wire [31:0] tx_pwm_fan_w;    wire tx_pwm_fan_valid_w;
    wire [31:0] tx_light_w;      wire tx_light_valid_w;
    wire [31:0] tx_sensor_hub_w; wire tx_sensor_hub_valid_w;
    wire [31:0] tx_oled_w;       wire tx_oled_valid_w;
    wire [31:0] tx_keypad_w;     wire tx_keypad_valid_w;
    wire [31:0] tx_prop_link_w;  wire tx_prop_link_valid_w;

    // ========================================================================
    // Shared signal wires
    // ========================================================================
    wire        tick_1hz;
    wire        tick_blink;
    wire [7:0]  temp_threshold;
    wire [7:0]  light_threshold;
    wire [7:0]  humidity_threshold;
    wire [7:0]  gas_threshold;
    wire [7:0]  co_threshold;
    wire [7:0]  temp_headroom;
    wire [7:0]  temp_reading;
    wire [7:0]  humidity_reading;
    wire [7:0]  gas_reading;
    wire [7:0]  co_reading;
    wire [7:0]  light_reading;
    wire [7:0]  fan_duty;
    wire        overheat_alarm;
    wire        alarm_active;
    wire        alarm_led;
    wire [1:0]  security_state;
    wire [3:0]  key_code;
    wire        key_valid;
    wire        auth_granted;
    wire        keypad_locked;
    wire        link_authenticated;
    wire        dongle_present;
    wire [7:0]  module_presence_reg;

    // ========================================================================
    // Switch mapping
    // ========================================================================
    wire [7:0]  sw_data    = sw[7:0];
    wire [2:0]  sw_reg_sel = sw[10:8];
    wire        arm_switch = sw[15];
    wire        btn_load   = btn[0]; // center button

    // ========================================================================
    // LED mapping
    // ========================================================================
    assign led[0]     = room_lights;
    assign led[1]     = alarm_led;
    assign led[2]     = alarm_active;
    assign led[3]     = auth_granted;
    assign led[4]     = link_authenticated;
    assign led[5]     = dongle_present;
    assign led[6]     = keypad_locked;
    assign led[7]     = overheat_alarm;
    assign led[13:8]  = module_presence_reg[5:0];
    assign led[14]    = tick_blink;
    assign led[15]    = arm_switch;

    // 7-segment display (simple: show fan_duty as hex)
    assign seg = 7'h7F; // off by default (active low)
    assign an  = 4'hF;  // all digits off
    assign dp  = 1'b1;

    // ========================================================================
    // Module: HMCB Arbiter
    // ========================================================================
    hmcb_arbiter u_arbiter (
        .clk              (clk),
        .rst_n            (rst_n),
        .tx_core          (tx_core_w),
        .tx_core_valid    (tx_core_valid_w),
        .tx_timer         (tx_timer_w),
        .tx_timer_valid   (tx_timer_valid_w),
        .tx_config        (tx_config_w),
        .tx_config_valid  (tx_config_valid_w),
        .tx_intruder      (tx_intruder_w),
        .tx_intruder_valid(tx_intruder_valid_w),
        .tx_pwm_fan       (tx_pwm_fan_w),
        .tx_pwm_fan_valid (tx_pwm_fan_valid_w),
        .tx_light         (tx_light_w),
        .tx_light_valid   (tx_light_valid_w),
        .tx_sensor_hub    (tx_sensor_hub_w),
        .tx_sensor_hub_valid(tx_sensor_hub_valid_w),
        .tx_oled          (tx_oled_w),
        .tx_oled_valid    (tx_oled_valid_w),
        .tx_keypad        (tx_keypad_w),
        .tx_keypad_valid  (tx_keypad_valid_w),
        .tx_prop_link     (tx_prop_link_w),
        .tx_prop_link_valid(tx_prop_link_valid_w),
        .hmcb_bus         (hmcb_bus),
        .hmcb_bus_valid   (hmcb_bus_valid)
    );

    // ========================================================================
    // Module: Module Registry (Presence Detection)
    // ========================================================================
    module_registry u_registry (
        .clk                (clk),
        .rst_n              (rst_n),
        .tick_1hz           (tick_1hz),
        .hmcb_rx            (hmcb_bus),
        .hmcb_rx_valid      (hmcb_bus_valid),
        .hmcb_tx            (tx_core_w),
        .hmcb_tx_valid      (tx_core_valid_w),
        .module_presence_reg(module_presence_reg)
    );

    // ========================================================================
    // Module: Timer Counter
    // ========================================================================
    timer_counter u_timer (
        .clk           (clk),
        .rst_n         (rst_n),
        .hmcb_rx       (hmcb_bus),
        .hmcb_rx_valid (hmcb_bus_valid),
        .hmcb_tx       (tx_timer_w),
        .hmcb_tx_valid (tx_timer_valid_w),
        .tick_1hz      (tick_1hz),
        .tick_blink    (tick_blink)
    );

    // ========================================================================
    // Module: Config Registers
    // ========================================================================
    config_registers u_config (
        .clk               (clk),
        .rst_n             (rst_n),
        .sw_data           (sw_data),
        .sw_reg_sel        (sw_reg_sel),
        .btn_load          (btn_load),
        .hmcb_rx           (hmcb_bus),
        .hmcb_rx_valid     (hmcb_bus_valid),
        .hmcb_tx           (tx_config_w),
        .hmcb_tx_valid     (tx_config_valid_w),
        .temp_threshold    (temp_threshold),
        .light_threshold   (light_threshold),
        .humidity_threshold(humidity_threshold),
        .gas_threshold     (gas_threshold),
        .co_threshold      (co_threshold),
        .temp_headroom     (temp_headroom)
    );

    // ========================================================================
    // Module: Intruder Alert Controller
    // ========================================================================
    intruder_alert_controller u_intruder (
        .clk           (clk),
        .rst_n         (rst_n),
        .pir_sensor    (pir_sensor),
        .door_sensor   (door_sensor),
        .arm_switch    (arm_switch),
        .tick_1hz      (tick_1hz),
        .tick_blink    (tick_blink),
        .hmcb_rx       (hmcb_bus),
        .hmcb_rx_valid (hmcb_bus_valid),
        .hmcb_tx       (tx_intruder_w),
        .hmcb_tx_valid (tx_intruder_valid_w),
        .alarm_active  (alarm_active),
        .alarm_led     (alarm_led),
        .buzzer_out    (buzzer_out),
        .security_state(security_state)
    );

    // ========================================================================
    // Module: PWM Fan Controller
    // ========================================================================
    pwm_fan_controller #(.MODULE_PRESENT(1)) u_pwm_fan (
        .clk            (clk),
        .rst_n          (rst_n),
        .tick_1hz       (tick_1hz),
        .temp_value     (temp_reading),
        .temp_threshold (temp_threshold),
        .temp_headroom  (temp_headroom),
        .fan_tach_in    (fan_tach_in),
        .hmcb_rx        (hmcb_bus),
        .hmcb_rx_valid  (hmcb_bus_valid),
        .hmcb_tx        (tx_pwm_fan_w),
        .hmcb_tx_valid  (tx_pwm_fan_valid_w),
        .pwm_fan_out    (pwm_fan_out),
        .fan_duty       (fan_duty),
        .overheat_alarm (overheat_alarm)
    );

    // ========================================================================
    // Module: Light Controller
    // ========================================================================
    light_controller #(.MODULE_PRESENT(1)) u_light (
        .clk            (clk),
        .rst_n          (rst_n),
        .light_level    (light_reading),
        .light_threshold(light_threshold),
        .hmcb_rx        (hmcb_bus),
        .hmcb_rx_valid  (hmcb_bus_valid),
        .hmcb_tx        (tx_light_w),
        .hmcb_tx_valid  (tx_light_valid_w),
        .room_lights    (room_lights)
    );

    // ========================================================================
    // Module: Multi-Sensor Hub
    // ========================================================================
    multi_sensor_hub #(.MODULE_PRESENT(1)) u_sensor_hub (
        .clk               (clk),
        .rst_n             (rst_n),
        .tick_1hz          (tick_1hz),
        .adc_cs_n          (adc_cs_n),
        .adc_sclk          (adc_sclk),
        .adc_miso          (adc_miso),
        .adc_ch_sel        (adc_ch_sel),
        .dht22_data        (dht22_data),
        .humidity_threshold(humidity_threshold),
        .gas_threshold     (gas_threshold),
        .co_threshold      (co_threshold),
        .hmcb_rx           (hmcb_bus),
        .hmcb_rx_valid     (hmcb_bus_valid),
        .hmcb_tx           (tx_sensor_hub_w),
        .hmcb_tx_valid     (tx_sensor_hub_valid_w),
        .temp_reading      (temp_reading),
        .humidity_reading  (humidity_reading),
        .gas_reading       (gas_reading),
        .co_reading        (co_reading),
        .light_reading     (light_reading)
    );

    // ========================================================================
    // Module: OLED I2C Controller
    // ========================================================================
    wire oled_sda_in = oled_sda; // read-back

    oled_i2c_controller #(.MODULE_PRESENT(1)) u_oled (
        .clk               (clk),
        .rst_n             (rst_n),
        .tick_1hz          (tick_1hz),
        .oled_scl          (oled_scl),
        .oled_sda          (oled_sda),
        .oled_sda_in       (oled_sda_in),
        .hmcb_rx           (hmcb_bus),
        .hmcb_rx_valid     (hmcb_bus_valid),
        .hmcb_tx           (tx_oled_w),
        .hmcb_tx_valid     (tx_oled_valid_w),
        .temp_reading      (temp_reading),
        .humidity_reading  (humidity_reading),
        .fan_duty          (fan_duty),
        .room_lights       (room_lights),
        .security_state    (security_state),
        .auth_granted      (auth_granted),
        .module_presence_reg(module_presence_reg),
        .gas_reading       (gas_reading),
        .co_reading        (co_reading)
    );

    // ========================================================================
    // Module: Keypad FSM
    // ========================================================================
    keypad_fsm u_keypad (
        .clk       (clk),
        .rst_n     (rst_n),
        .kp_row    (kp_row),
        .kp_col    (kp_col),
        .key_code  (key_code),
        .key_valid (key_valid)
    );

    // ========================================================================
    // Module: PIN Auth Controller
    // ========================================================================
    pin_auth_controller #(.MODULE_PRESENT(1)) u_pin_auth (
        .clk           (clk),
        .rst_n         (rst_n),
        .tick_1hz      (tick_1hz),
        .key_code      (key_code),
        .key_valid     (key_valid),
        .security_state(security_state),
        .hmcb_rx       (hmcb_bus),
        .hmcb_rx_valid (hmcb_bus_valid),
        .hmcb_tx       (tx_keypad_w),
        .hmcb_tx_valid (tx_keypad_valid_w),
        .auth_granted  (auth_granted),
        .keypad_locked (keypad_locked)
    );

    // ========================================================================
    // Module: Proprietary Link Controller
    // ========================================================================
    prop_link_controller #(.MODULE_PRESENT(1)) u_prop_link (
        .clk               (clk),
        .rst_n             (rst_n),
        .tick_1hz          (tick_1hz),
        .rs485_tx          (rs485_a),
        .rs485_rx          (rs485_b),
        .rs485_tx_en       (), // directly driving differential pair
        .hmcb_rx           (hmcb_bus),
        .hmcb_rx_valid     (hmcb_bus_valid),
        .hmcb_tx           (tx_prop_link_w),
        .hmcb_tx_valid     (tx_prop_link_valid_w),
        .link_authenticated(link_authenticated),
        .dongle_present    (dongle_present)
    );

endmodule
