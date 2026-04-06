// ============================================================================
// HomeGuardX v2.0 — Light Controller (Module 0x6, retained from v1.0)
// Automatic lighting with hysteresis to prevent oscillation
// ============================================================================
`timescale 1ns / 1ps

module light_controller #(
    parameter MODULE_PRESENT = 1
)(
    input  wire        clk,
    input  wire        rst_n,

    // Sensor input
    input  wire [7:0]  light_level,     // ADC reading (0=dark, 255=bright)
    input  wire [7:0]  light_threshold,

    // HMCB interface
    input  wire [31:0] hmcb_rx,
    input  wire        hmcb_rx_valid,
    output reg  [31:0] hmcb_tx,
    output reg         hmcb_tx_valid,

    // Output
    output reg         room_lights
);

    `include "hmcb_pkg.vh"

    generate
    if (MODULE_PRESENT == 0) begin : gen_stub
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                hmcb_tx       <= 32'd0;
                hmcb_tx_valid <= 1'b0;
                room_lights   <= 1'b0;
            end else begin
                hmcb_tx_valid <= 1'b0;
                room_lights   <= 1'b0;
            end
        end
    end else begin : gen_full

        // Hysteresis band: ±4 counts around threshold
        localparam [7:0] HYSTERESIS = 8'd4;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                room_lights   <= 1'b0;
                hmcb_tx       <= 32'd0;
                hmcb_tx_valid <= 1'b0;
            end else begin
                hmcb_tx_valid <= 1'b0;

                // Light control with hysteresis
                if (!room_lights) begin
                    // Currently OFF — turn ON if dark (below threshold - hysteresis)
                    if (light_level < (light_threshold - HYSTERESIS))
                        room_lights <= 1'b1;
                end else begin
                    // Currently ON — turn OFF if bright (above threshold + hysteresis)
                    if (light_level > (light_threshold + HYSTERESIS))
                        room_lights <= 1'b0;
                end

                // ---- HMCB PING response ----
                if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_PING &&
                    (`HMCB_DEST(hmcb_rx) == MID_BROADCAST || `HMCB_DEST(hmcb_rx) == MID_LIGHT)) begin
                    hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_LIGHT, CMD_PONG, 8'h00, MID_LIGHT);
                    hmcb_tx_valid <= 1'b1;
                end
            end
        end

    end
    endgenerate

endmodule
