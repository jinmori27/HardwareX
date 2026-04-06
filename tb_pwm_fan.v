// ============================================================================
// HomeGuardX v2.0 — Testbench: PWM Fan Controller
// ============================================================================
`timescale 1ns / 1ps

module tb_pwm_fan;

    `include "hmcb_pkg.vh"

    reg         clk, rst_n, tick_1hz;
    reg  [7:0]  temp_value, temp_threshold, temp_headroom;
    reg         fan_tach_in;
    reg  [31:0] hmcb_rx;
    reg         hmcb_rx_valid;
    wire [31:0] hmcb_tx;
    wire        hmcb_tx_valid;
    wire        pwm_fan_out;
    wire [7:0]  fan_duty;
    wire        overheat_alarm;

    pwm_fan_controller #(.MODULE_PRESENT(1)) uut (
        .clk(clk), .rst_n(rst_n), .tick_1hz(tick_1hz),
        .temp_value(temp_value), .temp_threshold(temp_threshold),
        .temp_headroom(temp_headroom), .fan_tach_in(fan_tach_in),
        .hmcb_rx(hmcb_rx), .hmcb_rx_valid(hmcb_rx_valid),
        .hmcb_tx(hmcb_tx), .hmcb_tx_valid(hmcb_tx_valid),
        .pwm_fan_out(pwm_fan_out), .fan_duty(fan_duty),
        .overheat_alarm(overheat_alarm)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; tick_1hz = 0;
        temp_value = 8'd25; temp_threshold = 8'd30; temp_headroom = 8'd20;
        fan_tach_in = 0; hmcb_rx = 0; hmcb_rx_valid = 0;

        #20 rst_n = 1;

        // Test 1: Below threshold -> duty = 0
        #10; tick_1hz = 1; @(posedge clk); tick_1hz = 0;
        #100;
        $display("Temp=25, Thresh=30: duty=%d (expect 0)", fan_duty);

        // Test 2: At midpoint -> duty ~50%
        temp_value = 8'd40;
        #10; tick_1hz = 1; @(posedge clk); tick_1hz = 0;
        #100;
        $display("Temp=40, Thresh=30, Head=20: duty=%d (expect ~127)", fan_duty);

        // Test 3: Above headroom -> duty = 255
        temp_value = 8'd55;
        #10; tick_1hz = 1; @(posedge clk); tick_1hz = 0;
        #100;
        $display("Temp=55, Thresh=30, Head=20: duty=%d (expect 255)", fan_duty);

        // Test 4: Observe PWM output for 50us
        #50000;

        $display("TB_PWM_FAN: Done");
        $finish;
    end

endmodule
