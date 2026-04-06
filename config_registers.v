// ============================================================================
// HomeGuardX v2.0 — Config Registers (expanded from v1.0)
// 6 threshold registers configurable via switches + load button
// Registers:
//   0: temp_threshold       (v1.0)
//   1: light_threshold      (v1.0)
//   2: humidity_threshold   (v2.0 new)
//   3: gas_threshold        (v2.0 new)
//   4: co_threshold         (v2.0 new)
//   5: temp_headroom        (v2.0 new — for PWM fan range)
// ============================================================================
`timescale 1ns / 1ps

module config_registers (
    input  wire        clk,
    input  wire        rst_n,

    // Physical I/O (switches + button)
    input  wire [7:0]  sw_data,       // 8-bit value from switches
    input  wire [2:0]  sw_reg_sel,    // 3-bit register select (switches)
    input  wire        btn_load,      // Debounced load button

    // HMCB interface
    input  wire [31:0] hmcb_rx,
    input  wire        hmcb_rx_valid,
    output reg  [31:0] hmcb_tx,
    output reg         hmcb_tx_valid,

    // Register outputs (directly used by other modules)
    output reg  [7:0]  temp_threshold,
    output reg  [7:0]  light_threshold,
    output reg  [7:0]  humidity_threshold,
    output reg  [7:0]  gas_threshold,
    output reg  [7:0]  co_threshold,
    output reg  [7:0]  temp_headroom
);

    `include "hmcb_pkg.vh"

    // Default values
    localparam DEF_TEMP_THRESH  = 8'd30;  // 30°C
    localparam DEF_LIGHT_THRESH = 8'd80;  // ~31% brightness ADC
    localparam DEF_HUM_THRESH   = 8'd70;  // 70% humidity
    localparam DEF_GAS_THRESH   = 8'd150; // gas ADC threshold
    localparam DEF_CO_THRESH    = 8'd100; // CO ADC threshold
    localparam DEF_TEMP_HEADRM  = 8'd20;  // PWM full-scale range above threshold

    // Button edge detect
    reg btn_load_d;
    wire btn_load_posedge = btn_load & ~btn_load_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_threshold     <= DEF_TEMP_THRESH;
            light_threshold    <= DEF_LIGHT_THRESH;
            humidity_threshold <= DEF_HUM_THRESH;
            gas_threshold      <= DEF_GAS_THRESH;
            co_threshold       <= DEF_CO_THRESH;
            temp_headroom      <= DEF_TEMP_HEADRM;
            btn_load_d         <= 1'b0;
            hmcb_tx            <= 32'd0;
            hmcb_tx_valid      <= 1'b0;
        end else begin
            btn_load_d    <= btn_load;
            hmcb_tx_valid <= 1'b0;

            // ---- Physical switch/button load ----
            if (btn_load_posedge) begin
                case (sw_reg_sel)
                    3'd0: temp_threshold     <= sw_data;
                    3'd1: light_threshold    <= sw_data;
                    3'd2: humidity_threshold <= sw_data;
                    3'd3: gas_threshold      <= sw_data;
                    3'd4: co_threshold       <= sw_data;
                    3'd5: temp_headroom      <= sw_data;
                    default: ; // ignore
                endcase
            end

            // ---- HMCB THRESHOLD_SET command ----
            if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_THRESHOLD_SET &&
                (`HMCB_DEST(hmcb_rx) == MID_CONFIG || `HMCB_DEST(hmcb_rx) == MID_BROADCAST)) begin
                case (`HMCB_DH(hmcb_rx))  // reg index
                    8'd0: temp_threshold     <= `HMCB_DL(hmcb_rx);
                    8'd1: light_threshold    <= `HMCB_DL(hmcb_rx);
                    8'd2: humidity_threshold <= `HMCB_DL(hmcb_rx);
                    8'd3: gas_threshold      <= `HMCB_DL(hmcb_rx);
                    8'd4: co_threshold       <= `HMCB_DL(hmcb_rx);
                    8'd5: temp_headroom      <= `HMCB_DL(hmcb_rx);
                    default: ;
                endcase
            end

            // ---- HMCB PING response ----
            if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_PING &&
                (`HMCB_DEST(hmcb_rx) == MID_BROADCAST || `HMCB_DEST(hmcb_rx) == MID_CONFIG)) begin
                hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_CONFIG, CMD_PONG, 8'h00, MID_CONFIG);
                hmcb_tx_valid <= 1'b1;
            end
        end
    end

endmodule
