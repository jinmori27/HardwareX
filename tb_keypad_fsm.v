// ============================================================================
// HomeGuardX v2.0 — Testbench: Keypad FSM
// ============================================================================
`timescale 1ns / 1ps

module tb_keypad_fsm;

    reg        clk, rst_n;
    wire [3:0] kp_row;
    reg  [3:0] kp_col;
    wire [3:0] key_code;
    wire       key_valid;

    keypad_fsm uut (
        .clk(clk), .rst_n(rst_n),
        .kp_row(kp_row), .kp_col(kp_col),
        .key_code(key_code), .key_valid(key_valid)
    );

    always #5 clk = ~clk;

    // Simulate key press: when row N is driven, assert col M
    // Key '5' = row 1, col 1
    always @(*) begin
        kp_col = 4'd0;
        if (kp_row[1]) kp_col[1] = 1'b1; // simulate '5' pressed
    end

    initial begin
        clk = 0; rst_n = 0; kp_col = 4'd0;
        #20 rst_n = 1;

        // Wait for scanner to detect and debounce
        #5_000_000; // 5ms — enough for scan + some debounce

        // Check for key_valid
        wait(key_valid);
        $display("Key detected: code=%d (expect 5)", key_code);

        #1000;
        $display("TB_KEYPAD_FSM: Done");
        $finish;
    end

    // Timeout
    initial begin
        #50_000_000;
        $display("TB_KEYPAD_FSM: Timeout");
        $finish;
    end

endmodule
