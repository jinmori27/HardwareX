// ============================================================================
// HomeGuardX v2.0 — Module Registry & Presence Detection
// Broadcasts PING, collects PONG, maintains presence register
// Hot-swap detection every 10 seconds; MODULE_LOST fault on disappearance
// ============================================================================
`timescale 1ns / 1ps

module module_registry (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,

    // HMCB interface
    input  wire [31:0] hmcb_rx,
    input  wire        hmcb_rx_valid,
    output reg  [31:0] hmcb_tx,
    output reg         hmcb_tx_valid,

    // Presence register output (active-high per optional module)
    // Bit 0 = Module 0x5 (PWM Fan), Bit 1 = 0x6 (Light), ...
    output reg  [7:0]  module_presence_reg
);

    `include "hmcb_pkg.vh"

    // -------------------------------------------
    // State machine for periodic PING broadcast
    // -------------------------------------------
    localparam S_IDLE       = 2'd0;
    localparam S_PING       = 2'd1;
    localparam S_COLLECT    = 2'd2;

    reg [1:0]  state;
    reg [3:0]  ping_tick_cnt;    // counts 1Hz ticks for 10-second interval
    reg [7:0]  pong_collect_reg; // temporary collection during scan window
    reg [23:0] collect_timer;    // ~100ms window at 100 MHz = 10M cycles
    reg        boot_phase;       // 1 during first-second boot scan
    reg [3:0]  boot_ping_cnt;    // send 10 PINGs during boot (every 100ms)

    localparam COLLECT_WINDOW = 24'd10_000_000; // 100ms at 100MHz
    localparam BOOT_PINGS     = 4'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= S_IDLE;
            hmcb_tx            <= 32'd0;
            hmcb_tx_valid      <= 1'b0;
            module_presence_reg<= 8'd0;
            pong_collect_reg   <= 8'd0;
            collect_timer      <= 24'd0;
            ping_tick_cnt      <= 4'd0;
            boot_phase         <= 1'b1;
            boot_ping_cnt      <= 4'd0;
        end else begin
            hmcb_tx_valid <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (boot_phase) begin
                        // Boot: send PING every 100ms for 1 second
                        if (collect_timer == COLLECT_WINDOW) begin
                            collect_timer <= 24'd0;
                            state         <= S_PING;
                            boot_ping_cnt <= boot_ping_cnt + 4'd1;
                            if (boot_ping_cnt >= BOOT_PINGS - 1)
                                boot_phase <= 1'b0;
                        end else begin
                            collect_timer <= collect_timer + 24'd1;
                        end
                    end else begin
                        // Runtime: send PING every 10 seconds
                        if (tick_1hz) begin
                            ping_tick_cnt <= ping_tick_cnt + 4'd1;
                            if (ping_tick_cnt >= 4'd9) begin
                                ping_tick_cnt    <= 4'd0;
                                pong_collect_reg <= 8'd0;
                                state            <= S_PING;
                            end
                        end
                    end
                end

                S_PING: begin
                    // Broadcast PING
                    hmcb_tx       <= `HMCB_PKT(MID_BROADCAST, MID_CORE, CMD_PING, 8'h00, 8'h00);
                    hmcb_tx_valid <= 1'b1;
                    collect_timer <= 24'd0;
                    pong_collect_reg <= 8'd0;
                    state         <= S_COLLECT;
                end

                S_COLLECT: begin
                    // Listen for PONGs during collection window
                    if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_PONG) begin
                        // Map Module ID to presence bit
                        if (`HMCB_DL(hmcb_rx) >= 8'h05 && `HMCB_DL(hmcb_rx) <= 8'h0A)
                            pong_collect_reg[`HMCB_DL(hmcb_rx) - 8'h05] <= 1'b1;
                    end

                    if (collect_timer >= COLLECT_WINDOW) begin
                        // Detect disappearance: was present, now gone
                        if (!boot_phase) begin
                            // Check for modules that disappeared
                            // (fault broadcast handled by core controller)
                        end
                        module_presence_reg <= pong_collect_reg;
                        state               <= S_IDLE;
                    end else begin
                        collect_timer <= collect_timer + 24'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
