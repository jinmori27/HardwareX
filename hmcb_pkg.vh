// ============================================================================
// HomeGuardX v2.0 — HMCB Shared Package
// Shared localparams: Module IDs, Command Opcodes, System Constants
// Author: Mohit Sai Vinnakota | VIT Vellore
// ============================================================================

// ---------------------------------------------------------------------------
// Module IDs (4-bit, max 15 modules, 0x0 = broadcast)
// ---------------------------------------------------------------------------
localparam [3:0] MID_BROADCAST       = 4'h0;
localparam [3:0] MID_CORE            = 4'h1;
localparam [3:0] MID_TIMER           = 4'h2;
localparam [3:0] MID_CONFIG          = 4'h3;
localparam [3:0] MID_INTRUDER        = 4'h4;
localparam [3:0] MID_PWM_FAN         = 4'h5;
localparam [3:0] MID_LIGHT           = 4'h6;
localparam [3:0] MID_SENSOR_HUB      = 4'h7;
localparam [3:0] MID_OLED            = 4'h8;
localparam [3:0] MID_KEYPAD_AUTH     = 4'h9;
localparam [3:0] MID_PROP_LINK       = 4'hA;

// ---------------------------------------------------------------------------
// HMCB Command Opcodes (8-bit)
// ---------------------------------------------------------------------------
localparam [7:0] CMD_PING            = 8'h00;
localparam [7:0] CMD_PONG            = 8'h01;
localparam [7:0] CMD_DATA_REPORT     = 8'h10;
localparam [7:0] CMD_THRESHOLD_SET   = 8'h11;
localparam [7:0] CMD_ALARM_RAISE     = 8'h20;
localparam [7:0] CMD_ALARM_CLEAR     = 8'h21;
localparam [7:0] CMD_AUTH_CHALLENGE  = 8'h30;
localparam [7:0] CMD_AUTH_RESPONSE   = 8'h31;
localparam [7:0] CMD_AUTH_GRANT      = 8'h32;
localparam [7:0] CMD_DISPLAY_UPDATE  = 8'h40;
localparam [7:0] CMD_FAULT           = 8'hFF;

// ---------------------------------------------------------------------------
// Fault Codes (8-bit, carried in DATA_L of FAULT packets)
// ---------------------------------------------------------------------------
localparam [7:0] FAULT_MODULE_LOST   = 8'h01;
localparam [7:0] FAULT_AUTH_FAIL     = 8'h02;
localparam [7:0] FAULT_SENSOR_ERR    = 8'h03;

// ---------------------------------------------------------------------------
// System Constants
// ---------------------------------------------------------------------------
localparam CLK_FREQ_HZ       = 100_000_000;  // 100 MHz system clock
localparam TICK_1HZ_MAX       = CLK_FREQ_HZ - 1;
localparam PWM_FREQ_HZ        = 25_000;       // 25 kHz PWM carrier
localparam PWM_DIV            = CLK_FREQ_HZ / PWM_FREQ_HZ; // 4000
localparam I2C_FREQ_HZ        = 400_000;      // I2C fast mode
localparam RS485_BAUD          = 115_200;
localparam RS485_DIV           = CLK_FREQ_HZ / RS485_BAUD;

// ---------------------------------------------------------------------------
// HMCB Packet Field Helpers (for readability)
// ---------------------------------------------------------------------------
// Build a 32-bit HMCB packet
// Usage: hmcb_packet(dest, src, cmd, data_h, data_l)
`define HMCB_PKT(dest, src, cmd, dh, dl) {dest, src, cmd, dh, dl}

// Extract fields from a 32-bit HMCB packet
`define HMCB_DEST(pkt)   pkt[31:28]
`define HMCB_SRC(pkt)    pkt[27:24]
`define HMCB_CMD(pkt)    pkt[23:16]
`define HMCB_DH(pkt)     pkt[15:8]
`define HMCB_DL(pkt)     pkt[7:0]
