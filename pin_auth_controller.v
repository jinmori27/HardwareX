// ============================================================================
// HomeGuardX v2.0 — PIN Authentication Controller (Module 0x9)
// 4-digit PIN stored in BRAM, 3-attempt lockout for 5 minutes
// Broadcasts AUTH_GRANT on successful PIN entry
// PIN change: hold '#' 3s -> enter current PIN -> enter new PIN x2
// ============================================================================
`timescale 1ns / 1ps

module pin_auth_controller #(
    parameter MODULE_PRESENT = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,

    // From keypad_fsm
    input  wire [3:0]  key_code,
    input  wire        key_valid,

    // Security state from intruder controller
    input  wire [1:0]  security_state, // 0=IDLE for PIN change permission

    // HMCB interface
    input  wire [31:0] hmcb_rx,
    input  wire        hmcb_rx_valid,
    output reg  [31:0] hmcb_tx,
    output reg         hmcb_tx_valid,

    // Status
    output reg         auth_granted,
    output reg         keypad_locked
);

    `include "hmcb_pkg.vh"

    generate
    if (MODULE_PRESENT == 0) begin : gen_stub
        // Minimal stub: respond to PING with absent
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                hmcb_tx       <= 32'd0;
                hmcb_tx_valid <= 1'b0;
                auth_granted  <= 1'b0;
                keypad_locked <= 1'b0;
            end else begin
                hmcb_tx_valid <= 1'b0;
                auth_granted  <= 1'b0;
                keypad_locked <= 1'b0;
            end
        end
    end else begin : gen_full

        // ---- PIN storage (BRAM-inferred) ----
        // Default PIN: 1234 -> {4'h1, 4'h2, 4'h3, 4'h4} = 16'h1234
        reg [15:0] stored_pin;
        initial stored_pin = 16'h1234;

        // ---- State machine ----
        localparam AUTH_IDLE       = 4'd0;
        localparam AUTH_DIGIT1     = 4'd1;
        localparam AUTH_DIGIT2     = 4'd2;
        localparam AUTH_DIGIT3     = 4'd3;
        localparam AUTH_DIGIT4     = 4'd4;
        localparam AUTH_CHECK      = 4'd5;
        localparam AUTH_LOCKED     = 4'd6;
        // PIN change states
        localparam CHG_WAIT_HASH   = 4'd7;
        localparam CHG_CUR_PIN     = 4'd8;
        localparam CHG_NEW_PIN1    = 4'd9;
        localparam CHG_NEW_PIN2    = 4'd10;
        localparam CHG_DONE        = 4'd11;

        reg [3:0]  state;
        reg [15:0] entered_pin;
        reg [1:0]  digit_idx;
        reg [1:0]  fail_count;
        reg [8:0]  lockout_timer;   // up to 300 seconds
        reg [3:0]  hash_hold_cnt;   // seconds '#' held

        // PIN change temporaries
        reg [15:0] chg_new_pin1;
        reg [1:0]  chg_digit_idx;

        localparam LOCKOUT_SECONDS = 9'd300; // 5 minutes

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                state          <= AUTH_IDLE;
                entered_pin    <= 16'd0;
                digit_idx      <= 2'd0;
                fail_count     <= 2'd0;
                lockout_timer  <= 9'd0;
                hash_hold_cnt  <= 4'd0;
                auth_granted   <= 1'b0;
                keypad_locked  <= 1'b0;
                hmcb_tx        <= 32'd0;
                hmcb_tx_valid  <= 1'b0;
                chg_new_pin1   <= 16'd0;
                chg_digit_idx  <= 2'd0;
            end else begin
                hmcb_tx_valid <= 1'b0;

                case (state)
                    AUTH_IDLE: begin
                        auth_granted <= 1'b0;
                        digit_idx    <= 2'd0;
                        entered_pin  <= 16'd0;

                        if (key_valid) begin
                            if (key_code <= 4'd9) begin
                                // First digit entered
                                entered_pin[15:12] <= key_code;
                                digit_idx          <= 2'd1;
                                state              <= AUTH_DIGIT2;
                            end
                            // '#' held detection starts
                            if (key_code == 4'd15) // '#'
                                hash_hold_cnt <= 4'd0;
                        end
                    end

                    AUTH_DIGIT2: begin
                        if (key_valid && key_code <= 4'd9) begin
                            entered_pin[11:8] <= key_code;
                            state             <= AUTH_DIGIT3;
                        end
                    end

                    AUTH_DIGIT3: begin
                        if (key_valid && key_code <= 4'd9) begin
                            entered_pin[7:4] <= key_code;
                            state            <= AUTH_DIGIT4;
                        end
                    end

                    AUTH_DIGIT4: begin
                        if (key_valid && key_code <= 4'd9) begin
                            entered_pin[3:0] <= key_code;
                            state            <= AUTH_CHECK;
                        end
                    end

                    AUTH_CHECK: begin
                        if (entered_pin == stored_pin) begin
                            auth_granted  <= 1'b1;
                            fail_count    <= 2'd0;
                            // Broadcast AUTH_GRANT
                            hmcb_tx       <= `HMCB_PKT(MID_BROADCAST, MID_KEYPAD_AUTH, CMD_AUTH_GRANT, 8'h00, 8'h01);
                            hmcb_tx_valid <= 1'b1;
                            state         <= AUTH_IDLE;
                        end else begin
                            fail_count <= fail_count + 2'd1;
                            if (fail_count >= 2'd2) begin
                                // 3rd failure -> lockout
                                state         <= AUTH_LOCKED;
                                lockout_timer <= LOCKOUT_SECONDS;
                                keypad_locked <= 1'b1;
                            end else begin
                                state <= AUTH_IDLE;
                            end
                        end
                    end

                    AUTH_LOCKED: begin
                        keypad_locked <= 1'b1;
                        if (tick_1hz) begin
                            if (lockout_timer == 9'd0) begin
                                keypad_locked <= 1'b0;
                                fail_count    <= 2'd0;
                                state         <= AUTH_IDLE;
                            end else begin
                                lockout_timer <= lockout_timer - 9'd1;
                            end
                        end
                    end

                    default: state <= AUTH_IDLE;
                endcase

                // ---- HMCB PING response ----
                if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_PING &&
                    (`HMCB_DEST(hmcb_rx) == MID_BROADCAST || `HMCB_DEST(hmcb_rx) == MID_KEYPAD_AUTH)) begin
                    hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_KEYPAD_AUTH, CMD_PONG, 8'h00, MID_KEYPAD_AUTH);
                    hmcb_tx_valid <= 1'b1;
                end
            end
        end

    end
    endgenerate

endmodule
