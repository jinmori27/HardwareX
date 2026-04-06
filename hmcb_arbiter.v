// ============================================================================
// HomeGuardX v2.0 — HMCB Bus Arbiter
// Round-robin arbitration with priority for ALARM/FAULT packets
// Muxes up to 10 module tx lines onto a single shared bus
// ============================================================================
`timescale 1ns / 1ps

module hmcb_arbiter (
    input  wire        clk,
    input  wire        rst_n,

    // Module TX inputs (each module's outgoing packet + valid strobe)
    input  wire [31:0] tx_core,
    input  wire        tx_core_valid,
    input  wire [31:0] tx_timer,
    input  wire        tx_timer_valid,
    input  wire [31:0] tx_config,
    input  wire        tx_config_valid,
    input  wire [31:0] tx_intruder,
    input  wire        tx_intruder_valid,
    input  wire [31:0] tx_pwm_fan,
    input  wire        tx_pwm_fan_valid,
    input  wire [31:0] tx_light,
    input  wire        tx_light_valid,
    input  wire [31:0] tx_sensor_hub,
    input  wire        tx_sensor_hub_valid,
    input  wire [31:0] tx_oled,
    input  wire        tx_oled_valid,
    input  wire [31:0] tx_keypad,
    input  wire        tx_keypad_valid,
    input  wire [31:0] tx_prop_link,
    input  wire        tx_prop_link_valid,

    // Shared bus output (active for 1 clock when bus_valid is high)
    output reg  [31:0] hmcb_bus,
    output reg         hmcb_bus_valid
);

    `include "hmcb_pkg.vh"

    localparam NUM_PORTS = 10;

    // Pack inputs into arrays for indexed access
    wire [31:0] tx_data  [0:NUM_PORTS-1];
    wire        tx_valid [0:NUM_PORTS-1];

    assign tx_data[0] = tx_core;       assign tx_valid[0] = tx_core_valid;
    assign tx_data[1] = tx_timer;      assign tx_valid[1] = tx_timer_valid;
    assign tx_data[2] = tx_config;     assign tx_valid[2] = tx_config_valid;
    assign tx_data[3] = tx_intruder;   assign tx_valid[3] = tx_intruder_valid;
    assign tx_data[4] = tx_pwm_fan;    assign tx_valid[4] = tx_pwm_fan_valid;
    assign tx_data[5] = tx_light;      assign tx_valid[5] = tx_light_valid;
    assign tx_data[6] = tx_sensor_hub; assign tx_valid[6] = tx_sensor_hub_valid;
    assign tx_data[7] = tx_oled;       assign tx_valid[7] = tx_oled_valid;
    assign tx_data[8] = tx_keypad;     assign tx_valid[8] = tx_keypad_valid;
    assign tx_data[9] = tx_prop_link;  assign tx_valid[9] = tx_prop_link_valid;

    reg [3:0] rr_ptr; // Round-robin pointer

    // Priority scan: alarm/fault first, then round-robin
    integer i;
    reg        found;
    reg [3:0]  grant_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hmcb_bus       <= 32'd0;
            hmcb_bus_valid <= 1'b0;
            rr_ptr         <= 4'd0;
        end else begin
            hmcb_bus_valid <= 1'b0;
            found = 1'b0;

            // Priority pass: scan for ALARM_RAISE or FAULT packets
            for (i = 0; i < NUM_PORTS; i = i + 1) begin
                if (!found && tx_valid[i] &&
                    (tx_data[i][23:16] == CMD_ALARM_RAISE ||
                     tx_data[i][23:16] == CMD_FAULT)) begin
                    hmcb_bus       <= tx_data[i];
                    hmcb_bus_valid <= 1'b1;
                    found = 1'b1;
                end
            end

            // Round-robin pass (if no priority packet)
            if (!found) begin
                for (i = 0; i < NUM_PORTS; i = i + 1) begin
                    grant_idx = (rr_ptr + i[3:0]) % NUM_PORTS;
                    if (!found && tx_valid[grant_idx]) begin
                        hmcb_bus       <= tx_data[grant_idx];
                        hmcb_bus_valid <= 1'b1;
                        rr_ptr         <= (grant_idx + 4'd1) % NUM_PORTS;
                        found = 1'b1;
                    end
                end
            end
        end
    end

endmodule
