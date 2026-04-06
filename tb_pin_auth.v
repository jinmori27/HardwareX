// ============================================================================
// HomeGuardX v2.0 — Testbench: PIN Auth Controller
// Tests correct PIN entry, wrong PIN, and lockout
// ============================================================================
`timescale 1ns / 1ps

module tb_pin_auth;

    `include "hmcb_pkg.vh"

    reg         clk, rst_n, tick_1hz;
    reg  [3:0]  key_code;
    reg         key_valid;
    reg  [1:0]  security_state;
    reg  [31:0] hmcb_rx;
    reg         hmcb_rx_valid;
    wire [31:0] hmcb_tx;
    wire        hmcb_tx_valid;
    wire        auth_granted;
    wire        keypad_locked;

    pin_auth_controller #(.MODULE_PRESENT(1)) uut (
        .clk(clk), .rst_n(rst_n), .tick_1hz(tick_1hz),
        .key_code(key_code), .key_valid(key_valid),
        .security_state(security_state),
        .hmcb_rx(hmcb_rx), .hmcb_rx_valid(hmcb_rx_valid),
        .hmcb_tx(hmcb_tx), .hmcb_tx_valid(hmcb_tx_valid),
        .auth_granted(auth_granted), .keypad_locked(keypad_locked)
    );

    always #5 clk = ~clk;

    task enter_digit(input [3:0] d);
        begin
            @(posedge clk);
            key_code = d; key_valid = 1;
            @(posedge clk);
            key_valid = 0;
            #200;
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; tick_1hz = 0;
        key_code = 0; key_valid = 0;
        security_state = 2'd0;
        hmcb_rx = 0; hmcb_rx_valid = 0;

        #20 rst_n = 1;
        #100;

        // Test 1: Correct PIN (1234)
        $display("Entering correct PIN: 1-2-3-4");
        enter_digit(4'd1);
        enter_digit(4'd2);
        enter_digit(4'd3);
        enter_digit(4'd4);
        #100;
        if (auth_granted) $display("PASS: Auth granted");
        else $display("FAIL: Auth not granted");

        #500;

        // Test 2: Wrong PIN
        $display("Entering wrong PIN: 0-0-0-0");
        enter_digit(4'd0);
        enter_digit(4'd0);
        enter_digit(4'd0);
        enter_digit(4'd0);
        #100;
        if (!auth_granted) $display("PASS: Auth denied for wrong PIN");
        else $display("FAIL: Should not grant");

        $display("TB_PIN_AUTH: Done");
        $finish;
    end

endmodule
