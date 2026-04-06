// ============================================================================
// HomeGuardX v2.0 — PWM Fan Speed Controller (Module 0x5)
// 25kHz PWM, 8-bit proportional duty cycle
// duty = ((temp - threshold) * 255) / headroom, clamped 0-255
// Overheat alarm if duty=255 for 3 consecutive seconds
// ============================================================================
`timescale 1ns / 1ps

module pwm_fan_controller #(
    parameter MODULE_PRESENT = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,

    // Sensor input (from multi_sensor_hub or direct)
    input  wire [7:0]  temp_value,
    input  wire [7:0]  temp_threshold,
    input  wire [7:0]  temp_headroom,

    // TACH feedback input (from fan)
    input  wire        fan_tach_in,

    // HMCB interface
    input  wire [31:0] hmcb_rx,
    input  wire        hmcb_rx_valid,
    output reg  [31:0] hmcb_tx,
    output reg         hmcb_tx_valid,

    // Physical output
    output reg         pwm_fan_out,

    // Status
    output reg  [7:0]  fan_duty,
    output reg         overheat_alarm
);

    `include "hmcb_pkg.vh"

    generate
    if (MODULE_PRESENT == 0) begin : gen_stub
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                hmcb_tx        <= 32'd0;
                hmcb_tx_valid  <= 1'b0;
                pwm_fan_out    <= 1'b0;
                fan_duty       <= 8'd0;
                overheat_alarm <= 1'b0;
            end else begin
                hmcb_tx_valid  <= 1'b0;
                pwm_fan_out    <= 1'b0;
                fan_duty       <= 8'd0;
                overheat_alarm <= 1'b0;
            end
        end
    end else begin : gen_full

        // ---- 25kHz PWM carrier (100MHz / 4000) ----
        reg [11:0] pwm_counter;
        localparam PWM_MAX = 12'd3999;

        // ---- Duty cycle computation ----
        // Done on tick_1hz to avoid glitches
        reg [15:0] diff;       // temp_value - temp_threshold (can be negative)
        reg [23:0] scaled;     // diff * 255
        reg [7:0]  duty_next;

        // ---- Overheat detection ----
        reg [1:0]  overheat_cnt; // count consecutive seconds at duty=255

        // ---- Fan TACH RPM measurement ----
        reg        tach_prev;
        reg [15:0] tach_count;   // edges per second
        reg [15:0] fan_rpm_reg;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                pwm_counter    <= 12'd0;
                pwm_fan_out    <= 1'b0;
                fan_duty       <= 8'd0;
                overheat_alarm <= 1'b0;
                overheat_cnt   <= 2'd0;
                hmcb_tx        <= 32'd0;
                hmcb_tx_valid  <= 1'b0;
                tach_prev      <= 1'b0;
                tach_count     <= 16'd0;
                fan_rpm_reg    <= 16'd0;
            end else begin
                hmcb_tx_valid <= 1'b0;

                // ---- PWM counter ----
                if (pwm_counter >= PWM_MAX)
                    pwm_counter <= 12'd0;
                else
                    pwm_counter <= pwm_counter + 12'd1;

                // PWM output comparison (duty mapped to 0-4000 range)
                // duty 255 -> full on; duty 0 -> full off
                // threshold = (fan_duty * 4000) / 256 ≈ fan_duty * 15.625
                // Simplified: fan_duty * 16 - fan_duty (close enough for PWM)
                pwm_fan_out <= (pwm_counter < ({4'd0, fan_duty} * 12'd16 - {4'd0, fan_duty})) ? 1'b1 : 1'b0;

                // ---- Duty cycle update on 1Hz tick ----
                if (tick_1hz) begin
                    if (temp_value <= temp_threshold) begin
                        fan_duty <= 8'd0;
                    end else if (temp_headroom == 8'd0) begin
                        fan_duty <= 8'd255; // avoid division by zero
                    end else begin
                        diff = {8'd0, temp_value} - {8'd0, temp_threshold};
                        if (diff >= {8'd0, temp_headroom}) begin
                            fan_duty <= 8'd255;
                        end else begin
                            scaled = diff * 16'd255;
                            fan_duty <= scaled[15:0] / {8'd0, temp_headroom};
                        end
                    end

                    // Overheat detection
                    if (fan_duty == 8'd255) begin
                        if (overheat_cnt >= 2'd2) begin
                            overheat_alarm <= 1'b1;
                            hmcb_tx       <= `HMCB_PKT(MID_BROADCAST, MID_PWM_FAN, CMD_ALARM_RAISE, 8'h00, 8'h02);
                            hmcb_tx_valid <= 1'b1;
                        end else begin
                            overheat_cnt <= overheat_cnt + 2'd1;
                        end
                    end else begin
                        overheat_cnt   <= 2'd0;
                        overheat_alarm <= 1'b0;
                    end

                    // Report fan duty via HMCB
                    if (!hmcb_tx_valid) begin
                        hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_PWM_FAN, CMD_DATA_REPORT, fan_duty, fan_rpm_reg[7:0]);
                        hmcb_tx_valid <= 1'b1;
                    end

                    // Reset tach counter
                    fan_rpm_reg <= tach_count;
                    tach_count  <= 16'd0;
                end

                // ---- TACH edge counter ----
                tach_prev <= fan_tach_in;
                if (fan_tach_in && !tach_prev)
                    tach_count <= tach_count + 16'd1;

                // ---- HMCB PING response ----
                if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_PING &&
                    (`HMCB_DEST(hmcb_rx) == MID_BROADCAST || `HMCB_DEST(hmcb_rx) == MID_PWM_FAN)) begin
                    hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_PWM_FAN, CMD_PONG, 8'h00, MID_PWM_FAN);
                    hmcb_tx_valid <= 1'b1;
                end
            end
        end

    end
    endgenerate

endmodule
