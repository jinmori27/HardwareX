// ============================================================================
// HomeGuardX v2.0 — Intruder Alert Controller
// FSM: IDLE -> TRIGGERED -> ALARM -> (DISARMED via keypad AUTH_GRANT)
// Retained v1.0 logic + HMCB interface + keypad disarm
// ============================================================================
`timescale 1ns / 1ps

module intruder_alert_controller (
    input  wire        clk,
    input  wire        rst_n,

    // Physical inputs
    input  wire        pir_sensor,     // PIR motion sensor (active high)
    input  wire        door_sensor,    // Door contact sensor (1 = open)
    input  wire        arm_switch,     // System arm/disarm switch

    // Timing
    input  wire        tick_1hz,
    input  wire        tick_blink,

    // HMCB interface
    input  wire [31:0] hmcb_rx,
    input  wire        hmcb_rx_valid,
    output reg  [31:0] hmcb_tx,
    output reg         hmcb_tx_valid,

    // Outputs
    output reg         alarm_active,
    output reg         alarm_led,      // blinks during alarm
    output reg         buzzer_out,
    output reg  [1:0]  security_state  // 0=IDLE, 1=ARMED, 2=TRIGGERED, 3=ALARM
);

    `include "hmcb_pkg.vh"

    // FSM states
    localparam ST_IDLE      = 2'd0;
    localparam ST_ARMED     = 2'd1;
    localparam ST_TRIGGERED = 2'd2;
    localparam ST_ALARM     = 2'd3;

    reg [3:0] trigger_countdown; // Grace period (seconds) before alarm

    localparam GRACE_SECONDS = 4'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            security_state    <= ST_IDLE;
            alarm_active      <= 1'b0;
            alarm_led         <= 1'b0;
            buzzer_out        <= 1'b0;
            trigger_countdown <= 4'd0;
            hmcb_tx           <= 32'd0;
            hmcb_tx_valid     <= 1'b0;
        end else begin
            hmcb_tx_valid <= 1'b0;

            case (security_state)
                ST_IDLE: begin
                    alarm_active <= 1'b0;
                    alarm_led    <= 1'b0;
                    buzzer_out   <= 1'b0;
                    if (arm_switch)
                        security_state <= ST_ARMED;
                end

                ST_ARMED: begin
                    alarm_active <= 1'b0;
                    alarm_led    <= 1'b0;
                    buzzer_out   <= 1'b0;
                    if (!arm_switch) begin
                        security_state <= ST_IDLE;
                    end else if (pir_sensor || door_sensor) begin
                        security_state    <= ST_TRIGGERED;
                        trigger_countdown <= GRACE_SECONDS;
                    end
                end

                ST_TRIGGERED: begin
                    alarm_led <= tick_blink; // slow blink during grace
                    if (!arm_switch) begin
                        security_state <= ST_IDLE;
                    end else if (tick_1hz) begin
                        if (trigger_countdown == 4'd0) begin
                            security_state <= ST_ALARM;
                            // Raise alarm on HMCB
                            hmcb_tx       <= `HMCB_PKT(MID_BROADCAST, MID_INTRUDER, CMD_ALARM_RAISE, 8'h00, 8'h01);
                            hmcb_tx_valid <= 1'b1;
                        end else begin
                            trigger_countdown <= trigger_countdown - 4'd1;
                        end
                    end
                    // Check for AUTH_GRANT (keypad disarm during grace)
                    if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_AUTH_GRANT) begin
                        security_state <= ST_ARMED; // Stay armed, just cancel trigger
                    end
                end

                ST_ALARM: begin
                    alarm_active <= 1'b1;
                    alarm_led    <= tick_blink; // fast visual indication
                    buzzer_out   <= 1'b1;

                    // Disarm via physical switch
                    if (!arm_switch) begin
                        security_state <= ST_IDLE;
                        hmcb_tx       <= `HMCB_PKT(MID_BROADCAST, MID_INTRUDER, CMD_ALARM_CLEAR, 8'h00, 8'h01);
                        hmcb_tx_valid <= 1'b1;
                    end

                    // Disarm via keypad AUTH_GRANT
                    if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_AUTH_GRANT) begin
                        security_state <= ST_IDLE;
                        alarm_active   <= 1'b0;
                        buzzer_out     <= 1'b0;
                        hmcb_tx       <= `HMCB_PKT(MID_BROADCAST, MID_INTRUDER, CMD_ALARM_CLEAR, 8'h00, 8'h01);
                        hmcb_tx_valid <= 1'b1;
                    end
                end
            endcase

            // ---- HMCB PING response ----
            if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_PING &&
                (`HMCB_DEST(hmcb_rx) == MID_BROADCAST || `HMCB_DEST(hmcb_rx) == MID_INTRUDER)) begin
                hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_INTRUDER, CMD_PONG, 8'h00, MID_INTRUDER);
                hmcb_tx_valid <= 1'b1;
            end
        end
    end

endmodule
