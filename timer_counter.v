// ============================================================================
// HomeGuardX v2.0 — Timer Counter (retained from v1.0)
// Generates 1Hz tick and blink tick from 100MHz system clock
// HMCB interface added for bus compatibility
// ============================================================================
`timescale 1ns / 1ps

module timer_counter (
    input  wire        clk,
    input  wire        rst_n,

    // HMCB interface
    input  wire [31:0] hmcb_rx,
    input  wire        hmcb_rx_valid,
    output reg  [31:0] hmcb_tx,
    output reg         hmcb_tx_valid,

    // Tick outputs used by other modules
    output reg         tick_1hz,
    output reg         tick_blink    // ~2Hz blink rate
);

    `include "hmcb_pkg.vh"

    // -----------------------------------------------------------------------
    // 1Hz tick generator
    // -----------------------------------------------------------------------
    reg [26:0] cnt_1hz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_1hz  <= 27'd0;
            tick_1hz <= 1'b0;
        end else begin
            if (cnt_1hz == TICK_1HZ_MAX) begin
                cnt_1hz  <= 27'd0;
                tick_1hz <= 1'b1;
            end else begin
                cnt_1hz  <= cnt_1hz + 27'd1;
                tick_1hz <= 1'b0;
            end
        end
    end

    // -----------------------------------------------------------------------
    // Blink tick (~2Hz for LED blink, 500ms period)
    // -----------------------------------------------------------------------
    reg [25:0] cnt_blink;
    localparam BLINK_MAX = CLK_FREQ_HZ / 2 - 1; // 50M-1

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_blink  <= 26'd0;
            tick_blink <= 1'b0;
        end else begin
            if (cnt_blink == BLINK_MAX[25:0]) begin
                cnt_blink  <= 26'd0;
                tick_blink <= ~tick_blink;
            end else begin
                cnt_blink <= cnt_blink + 26'd1;
            end
        end
    end

    // -----------------------------------------------------------------------
    // HMCB: Respond to PING with PONG
    // -----------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hmcb_tx       <= 32'd0;
            hmcb_tx_valid <= 1'b0;
        end else begin
            hmcb_tx_valid <= 1'b0;
            if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_PING &&
                (`HMCB_DEST(hmcb_rx) == MID_BROADCAST || `HMCB_DEST(hmcb_rx) == MID_TIMER)) begin
                hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_TIMER, CMD_PONG, 8'h00, MID_TIMER);
                hmcb_tx_valid <= 1'b1;
            end
        end
    end

endmodule
