// ============================================================================
// HomeGuardX v2.0 — SSD1306 OLED I2C Controller (Module 0x8)
// I2C master FSM at 400kHz, 128x64 OLED (1024-byte BRAM framebuffer)
// 4Hz display refresh via DMA-style sequential writes
// Receives display data via HMCB DISPLAY_UPDATE packets
// ============================================================================
`timescale 1ns / 1ps

module oled_i2c_controller #(
    parameter MODULE_PRESENT = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,

    // I2C physical interface (active-low open drain modeled as output enables)
    output wire        oled_scl,
    output wire        oled_sda,
    input  wire        oled_sda_in,     // SDA read-back for ACK

    // HMCB interface
    input  wire [31:0] hmcb_rx,
    input  wire        hmcb_rx_valid,
    output reg  [31:0] hmcb_tx,
    output reg         hmcb_tx_valid,

    // Display data inputs (directly wired for convenience)
    input  wire [7:0]  temp_reading,
    input  wire [7:0]  humidity_reading,
    input  wire [7:0]  fan_duty,
    input  wire        room_lights,
    input  wire [1:0]  security_state,
    input  wire        auth_granted,
    input  wire [7:0]  module_presence_reg,
    input  wire [7:0]  gas_reading,
    input  wire [7:0]  co_reading
);

    `include "hmcb_pkg.vh"

    generate
    if (MODULE_PRESENT == 0) begin : gen_stub
        assign oled_scl = 1'b1;
        assign oled_sda = 1'b1;
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                hmcb_tx       <= 32'd0;
                hmcb_tx_valid <= 1'b0;
            end else begin
                hmcb_tx_valid <= 1'b0;
            end
        end
    end else begin : gen_full

        // ---- I2C clock generation (400kHz from 100MHz -> divide by 250) ----
        localparam I2C_DIV = 250;
        localparam I2C_HALF = I2C_DIV / 2;
        reg [7:0]  i2c_cnt;
        reg        i2c_clk_en;   // toggles at 400kHz rate

        reg        scl_out;
        reg        sda_out;
        assign oled_scl = scl_out ? 1'bz : 1'b0; // open-drain: release = high (pull-up)
        assign oled_sda = sda_out ? 1'bz : 1'b0;

        // ---- I2C Master FSM ----
        localparam I2C_IDLE     = 4'd0;
        localparam I2C_START    = 4'd1;
        localparam I2C_ADDR     = 4'd2;
        localparam I2C_ADDR_ACK = 4'd3;
        localparam I2C_DATA     = 4'd4;
        localparam I2C_DATA_ACK = 4'd5;
        localparam I2C_STOP     = 4'd6;
        localparam I2C_INIT     = 4'd7;
        localparam I2C_REFRESH  = 4'd8;

        reg [3:0]  i2c_state;
        reg [2:0]  bit_idx;
        reg [7:0]  tx_byte;
        reg        phase;        // 0=SCL low, 1=SCL high
        localparam SSD1306_ADDR = 7'h3C; // default I2C address

        // ---- BRAM framebuffer (1024 bytes = 128x8 pages) ----
        reg [7:0]  framebuf [0:1023];
        reg [9:0]  fb_addr;
        reg [9:0]  refresh_addr;

        // ---- Display refresh (4Hz = every 25M cycles) ----
        localparam REFRESH_DIV = 25_000_000;
        reg [24:0] refresh_cnt;
        reg        refreshing;
        reg [3:0]  init_step;
        reg        oled_initialized;

        // ---- SSD1306 init sequence ----
        // Simplified init: Display OFF, set MUX, display offset, start line,
        // segment remap, COM scan, COM pins, contrast, precharge, VCOMH,
        // display ON, normal display
        localparam NUM_INIT_CMDS = 4'd11;
        reg [7:0] init_cmds [0:10];
        initial begin
            init_cmds[0]  = 8'hAE; // Display OFF
            init_cmds[1]  = 8'hA8; // Set MUX ratio
            init_cmds[2]  = 8'h3F; // 64-1
            init_cmds[3]  = 8'hD3; // Display offset
            init_cmds[4]  = 8'h00; // No offset
            init_cmds[5]  = 8'h40; // Start line 0
            init_cmds[6]  = 8'hA1; // Segment remap
            init_cmds[7]  = 8'hC8; // COM scan direction
            init_cmds[8]  = 8'h81; // Contrast
            init_cmds[9]  = 8'hCF; // Max contrast
            init_cmds[10] = 8'hAF; // Display ON
        end

        // Minimal framebuffer init
        integer fb_i;
        initial begin
            for (fb_i = 0; fb_i < 1024; fb_i = fb_i + 1)
                framebuf[fb_i] = 8'h00;
        end

        // ---- ASCII 8x8 font (subset: digits, letters for status) ----
        // For brevity, we define a BCD-to-segment approach:
        // The core writes pre-formatted bytes into framebuffer via DISPLAY_UPDATE

        // ---- I2C low-level byte send ----
        reg       send_start;
        reg       send_done;
        reg [7:0] bytes_to_send [0:3]; // small buffer
        reg [1:0] byte_idx;
        reg [1:0] bytes_total;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                i2c_cnt         <= 8'd0;
                i2c_clk_en      <= 1'b0;
                scl_out         <= 1'b1;
                sda_out         <= 1'b1;
                i2c_state       <= I2C_INIT;
                bit_idx         <= 3'd7;
                phase           <= 1'b0;
                fb_addr         <= 10'd0;
                refresh_addr    <= 10'd0;
                refresh_cnt     <= 25'd0;
                refreshing      <= 1'b0;
                init_step       <= 4'd0;
                oled_initialized<= 1'b0;
                hmcb_tx         <= 32'd0;
                hmcb_tx_valid   <= 1'b0;
                byte_idx        <= 2'd0;
                bytes_total     <= 2'd0;
                send_done       <= 1'b0;
            end else begin
                hmcb_tx_valid <= 1'b0;

                // I2C timing
                if (i2c_cnt == I2C_DIV - 1) begin
                    i2c_cnt    <= 8'd0;
                    i2c_clk_en <= 1'b1;
                end else begin
                    i2c_cnt    <= i2c_cnt + 8'd1;
                    i2c_clk_en <= 1'b0;
                end

                if (i2c_clk_en) begin
                    case (i2c_state)
                        I2C_INIT: begin
                            // Send init commands sequentially
                            if (!oled_initialized) begin
                                if (init_step < NUM_INIT_CMDS) begin
                                    // Send command byte via I2C
                                    // Address phase
                                    tx_byte   <= {SSD1306_ADDR, 1'b0}; // write
                                    sda_out   <= 1'b0; // START
                                    i2c_state <= I2C_START;
                                end else begin
                                    oled_initialized <= 1'b1;
                                    i2c_state        <= I2C_IDLE;
                                end
                            end
                        end

                        I2C_IDLE: begin
                            scl_out <= 1'b1;
                            sda_out <= 1'b1;

                            // 4Hz refresh trigger
                            if (refresh_cnt >= REFRESH_DIV - 1) begin
                                refresh_cnt  <= 25'd0;
                                refresh_addr <= 10'd0;
                                refreshing   <= 1'b1;
                                i2c_state    <= I2C_START;
                                tx_byte      <= {SSD1306_ADDR, 1'b0};
                            end else begin
                                refresh_cnt <= refresh_cnt + 25'd1;
                            end
                        end

                        I2C_START: begin
                            // I2C START condition: SDA falls while SCL high
                            if (!phase) begin
                                scl_out <= 1'b1;
                                sda_out <= 1'b0; // START
                                phase   <= 1'b1;
                            end else begin
                                scl_out   <= 1'b0;
                                phase     <= 1'b0;
                                bit_idx   <= 3'd7;
                                i2c_state <= I2C_ADDR;
                            end
                        end

                        I2C_ADDR: begin
                            if (!phase) begin
                                sda_out <= tx_byte[bit_idx];
                                phase   <= 1'b1;
                            end else begin
                                scl_out <= 1'b1;
                                phase   <= 1'b0;
                                if (bit_idx == 3'd0) begin
                                    i2c_state <= I2C_ADDR_ACK;
                                end else begin
                                    bit_idx <= bit_idx - 3'd1;
                                end
                                scl_out <= 1'b0;
                            end
                        end

                        I2C_ADDR_ACK: begin
                            // Release SDA, pulse SCL for ACK
                            if (!phase) begin
                                sda_out <= 1'b1; // release
                                scl_out <= 1'b1;
                                phase   <= 1'b1;
                            end else begin
                                scl_out <= 1'b0;
                                phase   <= 1'b0;
                                // Assume ACK received, proceed to data
                                if (refreshing) begin
                                    tx_byte   <= 8'h40; // data mode
                                    bit_idx   <= 3'd7;
                                    i2c_state <= I2C_DATA;
                                end else if (!oled_initialized) begin
                                    tx_byte   <= 8'h00; // command mode
                                    bit_idx   <= 3'd7;
                                    i2c_state <= I2C_DATA;
                                end else begin
                                    i2c_state <= I2C_STOP;
                                end
                            end
                        end

                        I2C_DATA: begin
                            if (!phase) begin
                                sda_out <= tx_byte[bit_idx];
                                phase   <= 1'b1;
                            end else begin
                                scl_out <= 1'b1;
                                phase   <= 1'b0;
                                scl_out <= 1'b0;
                                if (bit_idx == 3'd0) begin
                                    i2c_state <= I2C_DATA_ACK;
                                end else begin
                                    bit_idx <= bit_idx - 3'd1;
                                end
                            end
                        end

                        I2C_DATA_ACK: begin
                            if (!phase) begin
                                sda_out <= 1'b1;
                                scl_out <= 1'b1;
                                phase   <= 1'b1;
                            end else begin
                                scl_out <= 1'b0;
                                phase   <= 1'b0;
                                if (refreshing) begin
                                    if (refresh_addr < 10'd1023) begin
                                        refresh_addr <= refresh_addr + 10'd1;
                                        tx_byte      <= framebuf[refresh_addr + 1];
                                        bit_idx      <= 3'd7;
                                        i2c_state    <= I2C_DATA;
                                    end else begin
                                        refreshing <= 1'b0;
                                        i2c_state  <= I2C_STOP;
                                    end
                                end else if (!oled_initialized) begin
                                    // Send next init command
                                    tx_byte   <= init_cmds[init_step];
                                    bit_idx   <= 3'd7;
                                    init_step <= init_step + 4'd1;
                                    i2c_state <= I2C_DATA;
                                end else begin
                                    i2c_state <= I2C_STOP;
                                end
                            end
                        end

                        I2C_STOP: begin
                            if (!phase) begin
                                sda_out <= 1'b0;
                                scl_out <= 1'b1;
                                phase   <= 1'b1;
                            end else begin
                                sda_out   <= 1'b1; // STOP: SDA rises while SCL high
                                phase     <= 1'b0;
                                if (!oled_initialized)
                                    i2c_state <= I2C_INIT;
                                else
                                    i2c_state <= I2C_IDLE;
                            end
                        end

                        default: i2c_state <= I2C_IDLE;
                    endcase
                end

                // ---- HMCB: Write to framebuffer via DISPLAY_UPDATE ----
                if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_DISPLAY_UPDATE &&
                    (`HMCB_DEST(hmcb_rx) == MID_OLED || `HMCB_DEST(hmcb_rx) == MID_BROADCAST)) begin
                    // DATA_H = address high 2 bits + 6'b0, DATA_L = data byte
                    // Simplified: use SRC_ID upper bits as addr extension
                    // For basic use: sequential write, fb_addr auto-increments
                    framebuf[fb_addr] <= `HMCB_DL(hmcb_rx);
                    fb_addr           <= fb_addr + 10'd1;
                end

                // ---- HMCB PING response ----
                if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_PING &&
                    (`HMCB_DEST(hmcb_rx) == MID_BROADCAST || `HMCB_DEST(hmcb_rx) == MID_OLED)) begin
                    hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_OLED, CMD_PONG, 8'h00, MID_OLED);
                    hmcb_tx_valid <= 1'b1;
                end
            end
        end

    end
    endgenerate

endmodule
