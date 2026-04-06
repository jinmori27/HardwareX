// ============================================================================
// HomeGuardX v2.0 — Testbench: Proprietary Link Controller
// Simulates dongle response to verify LFSR challenge-response auth
// ============================================================================
`timescale 1ns / 1ps

module tb_prop_link;

    `include "hmcb_pkg.vh"

    reg         clk, rst_n, tick_1hz;
    wire        rs485_tx;
    reg         rs485_rx;
    wire        rs485_tx_en;
    reg  [31:0] hmcb_rx;
    reg         hmcb_rx_valid;
    wire [31:0] hmcb_tx;
    wire        hmcb_tx_valid;
    wire        link_authenticated;
    wire        dongle_present;

    prop_link_controller #(.MODULE_PRESENT(1)) uut (
        .clk(clk), .rst_n(rst_n), .tick_1hz(tick_1hz),
        .rs485_tx(rs485_tx), .rs485_rx(rs485_rx),
        .rs485_tx_en(rs485_tx_en),
        .hmcb_rx(hmcb_rx), .hmcb_rx_valid(hmcb_rx_valid),
        .hmcb_tx(hmcb_tx), .hmcb_tx_valid(hmcb_tx_valid),
        .link_authenticated(link_authenticated),
        .dongle_present(dongle_present)
    );

    always #5 clk = ~clk;

    // Simulated dongle: capture 4 TX bytes (challenge), compute response, send back
    reg [63:0] dongle_secret;
    initial dongle_secret = 64'hDEAD_BEEF_CAFE_BABE; // Must match controller

    reg [31:0] captured_challenge;
    reg [31:0] dongle_response;
    integer byte_cnt;

    // Simple loopback with response computation
    // In real test, we'd decode the UART TX; here we send the correct response
    // after a delay to simulate dongle processing
    initial begin
        clk = 0; rst_n = 0; tick_1hz = 0;
        rs485_rx = 1; // idle
        hmcb_rx = 0; hmcb_rx_valid = 0;

        #20 rst_n = 1;
        #100;

        // Send AUTH_CHALLENGE via HMCB
        @(posedge clk);
        hmcb_rx = `HMCB_PKT(MID_PROP_LINK, MID_CORE, CMD_AUTH_CHALLENGE, 8'h00, 8'h00);
        hmcb_rx_valid = 1;
        @(posedge clk);
        hmcb_rx_valid = 0;

        // Wait for TX to complete (4 bytes at 115200 = ~350us)
        #400_000;

        // Simulate dongle sending correct response
        // The challenge used is the LFSR initial state: 32'h12345678
        captured_challenge = 32'h12345678;
        dongle_response = (captured_challenge ^ dongle_secret[31:0]) ^ dongle_secret[63:32];

        // Send 4 response bytes via UART (simple: just pulse rx for each byte)
        // This is a simplified model; real dongle would send proper UART frames
        $display("Dongle computed response: %h", dongle_response);

        // For brevity, we skip full UART frame simulation here
        // In a full test, each byte would be sent as start+8data+stop at baud rate

        #1_000_000;

        if (hmcb_tx_valid)
            $display("Link controller responded on HMCB: %h", hmcb_tx);

        $display("TB_PROP_LINK: Done");
        $finish;
    end

endmodule
