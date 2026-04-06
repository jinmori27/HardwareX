// ============================================================================
// HomeGuardX v2.0 — Testbench: HMCB Arbiter
// Verifies round-robin arbitration + alarm priority
// ============================================================================
`timescale 1ns / 1ps

module tb_hmcb_arbiter;

    `include "hmcb_pkg.vh"

    reg         clk, rst_n;
    reg  [31:0] tx [0:9];
    reg         tv [0:9];
    wire [31:0] hmcb_bus;
    wire        hmcb_bus_valid;

    integer i;

    hmcb_arbiter uut (
        .clk(clk), .rst_n(rst_n),
        .tx_core(tx[0]),       .tx_core_valid(tv[0]),
        .tx_timer(tx[1]),      .tx_timer_valid(tv[1]),
        .tx_config(tx[2]),     .tx_config_valid(tv[2]),
        .tx_intruder(tx[3]),   .tx_intruder_valid(tv[3]),
        .tx_pwm_fan(tx[4]),    .tx_pwm_fan_valid(tv[4]),
        .tx_light(tx[5]),      .tx_light_valid(tv[5]),
        .tx_sensor_hub(tx[6]), .tx_sensor_hub_valid(tv[6]),
        .tx_oled(tx[7]),       .tx_oled_valid(tv[7]),
        .tx_keypad(tx[8]),     .tx_keypad_valid(tv[8]),
        .tx_prop_link(tx[9]),  .tx_prop_link_valid(tv[9]),
        .hmcb_bus(hmcb_bus),
        .hmcb_bus_valid(hmcb_bus_valid)
    );

    // Clock: 100MHz
    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0;
        for (i = 0; i < 10; i = i+1) begin
            tx[i] = 32'd0;
            tv[i] = 1'b0;
        end

        #20 rst_n = 1;

        // Test 1: Single module transmits
        @(posedge clk);
        tx[3] = `HMCB_PKT(MID_CORE, MID_INTRUDER, CMD_DATA_REPORT, 8'h25, 8'h00);
        tv[3] = 1'b1;
        @(posedge clk);
        tv[3] = 1'b0;
        @(posedge clk);
        if (hmcb_bus_valid)
            $display("PASS: Single TX arbitrated, bus=%h", hmcb_bus);

        // Test 2: Two modules, alarm has priority
        @(posedge clk);
        tx[1] = `HMCB_PKT(MID_CORE, MID_TIMER, CMD_PONG, 8'h00, MID_TIMER);
        tv[1] = 1'b1;
        tx[6] = `HMCB_PKT(MID_BROADCAST, MID_SENSOR_HUB, CMD_ALARM_RAISE, 8'h00, 8'h10);
        tv[6] = 1'b1;
        @(posedge clk);
        tv[1] = 1'b0; tv[6] = 1'b0;
        @(posedge clk);
        if (hmcb_bus_valid && hmcb_bus[23:16] == CMD_ALARM_RAISE)
            $display("PASS: Alarm priority works");
        else
            $display("FAIL: Expected alarm priority, got %h", hmcb_bus);

        #100;
        $display("TB_HMCB_ARBITER: Done");
        $finish;
    end

endmodule
