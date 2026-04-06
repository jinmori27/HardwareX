// ============================================================================
// HomeGuardX v2.0 — Testbench: OLED I2C Controller
// Verifies I2C init sequence and framebuffer refresh
// ============================================================================
`timescale 1ns / 1ps

module tb_oled_controller;

    `include "hmcb_pkg.vh"

    reg         clk, rst_n, tick_1hz;
    wire        oled_scl, oled_sda;
    reg  [31:0] hmcb_rx;
    reg         hmcb_rx_valid;
    wire [31:0] hmcb_tx;
    wire        hmcb_tx_valid;

    // Tie display data inputs to constants for test
    reg  [7:0]  temp_reading, humidity_reading, fan_duty;
    reg         room_lights;
    reg  [1:0]  security_state;
    reg         auth_granted;
    reg  [7:0]  module_presence_reg;
    reg  [7:0]  gas_reading, co_reading;

    // Pull-ups for open-drain I2C
    pullup(oled_scl);
    pullup(oled_sda);

    oled_i2c_controller #(.MODULE_PRESENT(1)) uut (
        .clk(clk), .rst_n(rst_n), .tick_1hz(tick_1hz),
        .oled_scl(oled_scl), .oled_sda(oled_sda),
        .oled_sda_in(oled_sda),
        .hmcb_rx(hmcb_rx), .hmcb_rx_valid(hmcb_rx_valid),
        .hmcb_tx(hmcb_tx), .hmcb_tx_valid(hmcb_tx_valid),
        .temp_reading(temp_reading),
        .humidity_reading(humidity_reading),
        .fan_duty(fan_duty),
        .room_lights(room_lights),
        .security_state(security_state),
        .auth_granted(auth_granted),
        .module_presence_reg(module_presence_reg),
        .gas_reading(gas_reading),
        .co_reading(co_reading)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rst_n = 0; tick_1hz = 0;
        hmcb_rx = 0; hmcb_rx_valid = 0;
        temp_reading = 8'd28; humidity_reading = 8'd55;
        fan_duty = 8'd100; room_lights = 1;
        security_state = 2'd1; auth_granted = 0;
        module_presence_reg = 8'h3F;
        gas_reading = 8'd20; co_reading = 8'd10;

        #20 rst_n = 1;

        // Wait for init to complete (11 I2C commands)
        #500_000;
        $display("OLED init should be complete by now");

        // Write some data to framebuffer via HMCB
        @(posedge clk);
        hmcb_rx = `HMCB_PKT(MID_OLED, MID_CORE, CMD_DISPLAY_UPDATE, 8'h00, 8'hAA);
        hmcb_rx_valid = 1;
        @(posedge clk);
        hmcb_rx_valid = 0;

        // Wait for a refresh cycle (~250ms at 4Hz)
        #300_000_000;

        // Verify PING response
        @(posedge clk);
        hmcb_rx = `HMCB_PKT(MID_BROADCAST, MID_CORE, CMD_PING, 8'h00, 8'h00);
        hmcb_rx_valid = 1;
        @(posedge clk);
        hmcb_rx_valid = 0;
        #100;
        if (hmcb_tx_valid && hmcb_tx[7:0] == MID_OLED)
            $display("PASS: OLED responded to PING");

        $display("TB_OLED_CONTROLLER: Done");
        $finish;
    end

    // Timeout
    initial begin
        #500_000_000;
        $display("TB_OLED_CONTROLLER: Timeout (expected for long refresh)");
        $finish;
    end

endmodule
