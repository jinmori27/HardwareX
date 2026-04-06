// ============================================================================
// HomeGuardX v2.0 — 4x4 Keypad Scanner FSM
// Sequential row drive, column read, 20ms debounce
// Outputs decoded 4-bit keycode + key_valid strobe
// ============================================================================
`timescale 1ns / 1ps

module keypad_fsm (
    input  wire        clk,
    input  wire        rst_n,

    // Physical keypad I/O
    output reg  [3:0]  kp_row,      // Row drive outputs (active high, one-hot)
    input  wire [3:0]  kp_col,      // Column read inputs

    // Decoded output
    output reg  [3:0]  key_code,    // 0-9, A=10, B=11, C=12, D=13, *=14, #=15
    output reg         key_valid    // Pulse high for 1 clk on new key press
);

    `include "hmcb_pkg.vh"

    // -------------------------------------------
    // Row scan at 1kHz (100MHz / 100000 = 1kHz)
    // -------------------------------------------
    localparam SCAN_DIV = 100_000; // 1ms per row
    reg [16:0] scan_cnt;
    reg [1:0]  row_idx;

    // Debounce: require stable for 20ms = 20 scan cycles
    localparam DEBOUNCE_CNT = 5'd20;
    reg [4:0]  debounce_timer;
    reg [3:0]  col_stable;
    reg [3:0]  col_prev;
    reg        key_pressed;

    // Keymap ROM: row[1:0] x col[1:0] -> keycode
    // Standard 4x4 layout:
    // Row0: 1 2 3 A
    // Row1: 4 5 6 B
    // Row2: 7 8 9 C
    // Row3: * 0 # D
    function [3:0] decode_key;
        input [1:0] row;
        input [1:0] col;
        begin
            case ({row, col})
                4'b00_00: decode_key = 4'd1;
                4'b00_01: decode_key = 4'd2;
                4'b00_10: decode_key = 4'd3;
                4'b00_11: decode_key = 4'd10; // A
                4'b01_00: decode_key = 4'd4;
                4'b01_01: decode_key = 4'd5;
                4'b01_10: decode_key = 4'd6;
                4'b01_11: decode_key = 4'd11; // B
                4'b10_00: decode_key = 4'd7;
                4'b10_01: decode_key = 4'd8;
                4'b10_10: decode_key = 4'd9;
                4'b10_11: decode_key = 4'd12; // C
                4'b11_00: decode_key = 4'd14; // *
                4'b11_01: decode_key = 4'd0;
                4'b11_10: decode_key = 4'd15; // #
                4'b11_11: decode_key = 4'd13; // D
            endcase
        end
    endfunction

    // Find first set bit in column vector
    function [1:0] col_encode;
        input [3:0] col;
        begin
            casez (col)
                4'b???1: col_encode = 2'd0;
                4'b??10: col_encode = 2'd1;
                4'b?100: col_encode = 2'd2;
                4'b1000: col_encode = 2'd3;
                default: col_encode = 2'd0;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_cnt       <= 17'd0;
            row_idx        <= 2'd0;
            kp_row         <= 4'b0001;
            key_code       <= 4'd0;
            key_valid      <= 1'b0;
            debounce_timer <= 5'd0;
            col_stable     <= 4'd0;
            col_prev       <= 4'd0;
            key_pressed    <= 1'b0;
        end else begin
            key_valid <= 1'b0;

            if (scan_cnt == SCAN_DIV - 1) begin
                scan_cnt <= 17'd0;

                // Read columns for current row
                if (kp_col != 4'd0) begin
                    // Key detected
                    if (kp_col == col_prev) begin
                        if (debounce_timer < DEBOUNCE_CNT)
                            debounce_timer <= debounce_timer + 5'd1;
                        else if (!key_pressed) begin
                            // Debounce passed, emit key
                            key_code    <= decode_key(row_idx, col_encode(kp_col));
                            key_valid   <= 1'b1;
                            key_pressed <= 1'b1;
                        end
                    end else begin
                        col_prev       <= kp_col;
                        debounce_timer <= 5'd0;
                    end
                end else begin
                    // No key on this row - advance
                    key_pressed    <= 1'b0;
                    debounce_timer <= 5'd0;
                    col_prev       <= 4'd0;
                    row_idx        <= row_idx + 2'd1;
                    kp_row         <= {kp_row[2:0], kp_row[3]}; // rotate one-hot
                end
            end else begin
                scan_cnt <= scan_cnt + 17'd1;
            end
        end
    end

endmodule
