// ============================================================================
// HomeGuardX v2.0 — Proprietary Link Controller (Module 0xA)
// RS-485 half-duplex UART at 115200 baud
// Galois LFSR challenge-response dongle authentication
// Session token rotation every 60 seconds
// ============================================================================
`timescale 1ns / 1ps

module prop_link_controller #(
    parameter MODULE_PRESENT = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,

    // RS-485 physical interface
    output reg         rs485_tx,       // Directly drives RS-485 driver (active for TX)
    input  wire        rs485_rx,       // From RS-485 receiver
    output reg         rs485_tx_en,    // Driver enable (1=transmit, 0=receive)

    // HMCB interface
    input  wire [31:0] hmcb_rx,
    input  wire        hmcb_rx_valid,
    output reg  [31:0] hmcb_tx,
    output reg         hmcb_tx_valid,

    // Status
    output reg         link_authenticated,
    output reg         dongle_present
);

    `include "hmcb_pkg.vh"

    generate
    if (MODULE_PRESENT == 0) begin : gen_stub
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                hmcb_tx            <= 32'd0;
                hmcb_tx_valid      <= 1'b0;
                rs485_tx           <= 1'b1;
                rs485_tx_en        <= 1'b0;
                link_authenticated <= 1'b0;
                dongle_present     <= 1'b0;
            end else begin
                hmcb_tx_valid      <= 1'b0;
                link_authenticated <= 1'b0;
                dongle_present     <= 1'b0;
            end
        end
    end else begin : gen_full

        // ---- Galois LFSR (x^32 + x^22 + x^2 + x + 1) ----
        reg [31:0] lfsr;
        wire       lfsr_fb = lfsr[0];

        task lfsr_step;
            begin
                lfsr <= {1'b0, lfsr[31:1]} ^ (lfsr_fb ? 32'h00400007 : 32'h0);
            end
        endtask

        // ---- Stored device secret (in BRAM, pre-programmed) ----
        reg [63:0] device_secret;
        initial device_secret = 64'hDEAD_BEEF_CAFE_BABE; // Placeholder — real secret per-device

        // ---- UART TX engine (115200 baud) ----
        localparam UART_DIV = CLK_FREQ_HZ / RS485_BAUD; // ~868
        reg [9:0]  uart_tx_div;
        reg [3:0]  uart_tx_bit;
        reg [9:0]  uart_tx_shift; // start + 8data + stop
        reg        uart_tx_busy;

        // ---- UART RX engine ----
        reg [9:0]  uart_rx_div;
        reg [3:0]  uart_rx_bit;
        reg [7:0]  uart_rx_shift;
        reg        uart_rx_busy;
        reg        uart_rx_done;
        reg [7:0]  uart_rx_data;
        reg        rx_prev;

        // ---- Auth FSM ----
        localparam AUTH_IDLE        = 4'd0;
        localparam AUTH_WAIT_CMD    = 4'd1;
        localparam AUTH_SEND_CHAL   = 4'd2;
        localparam AUTH_WAIT_RESP   = 4'd3;
        localparam AUTH_CHECK_RESP  = 4'd4;
        localparam AUTH_GRANTED     = 4'd5;
        localparam AUTH_SEND_BYTE   = 4'd6;
        localparam AUTH_RECV_BYTES  = 4'd7;

        reg [3:0]  auth_state;
        reg [31:0] challenge;
        reg [31:0] expected_response;
        reg [31:0] received_response;
        reg [1:0]  resp_byte_cnt;
        reg [5:0]  session_timer;  // 60-second rotation

        // ---- UART TX: send one byte ----
        reg        uart_send_req;
        reg [7:0]  uart_send_data;
        reg [1:0]  chal_byte_idx;  // which byte of challenge to send

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                lfsr              <= 32'h12345678; // seed from counter at boot
                auth_state        <= AUTH_IDLE;
                challenge         <= 32'd0;
                expected_response <= 32'd0;
                received_response <= 32'd0;
                resp_byte_cnt     <= 2'd0;
                session_timer     <= 6'd0;
                link_authenticated<= 1'b0;
                dongle_present    <= 1'b0;
                hmcb_tx           <= 32'd0;
                hmcb_tx_valid     <= 1'b0;
                // UART TX
                rs485_tx          <= 1'b1; // idle high
                rs485_tx_en       <= 1'b0; // receive mode
                uart_tx_div       <= 10'd0;
                uart_tx_bit       <= 4'd0;
                uart_tx_shift     <= 10'h3FF;
                uart_tx_busy      <= 1'b0;
                // UART RX
                uart_rx_div       <= 10'd0;
                uart_rx_bit       <= 4'd0;
                uart_rx_shift     <= 8'd0;
                uart_rx_busy      <= 1'b0;
                uart_rx_done      <= 1'b0;
                uart_rx_data      <= 8'd0;
                rx_prev           <= 1'b1;
                uart_send_req     <= 1'b0;
                chal_byte_idx     <= 2'd0;
            end else begin
                hmcb_tx_valid <= 1'b0;
                uart_rx_done  <= 1'b0;

                // ---- LFSR advance on each 1Hz tick ----
                if (tick_1hz) begin
                    lfsr_step;
                    if (link_authenticated) begin
                        session_timer <= session_timer + 6'd1;
                        if (session_timer >= 6'd59) begin
                            session_timer      <= 6'd0;
                            link_authenticated <= 1'b0; // force re-auth
                            auth_state         <= AUTH_IDLE;
                        end
                    end
                end

                // ============================================================
                // UART TX engine
                // ============================================================
                if (uart_tx_busy) begin
                    if (uart_tx_div >= UART_DIV - 1) begin
                        uart_tx_div <= 10'd0;
                        rs485_tx    <= uart_tx_shift[0];
                        uart_tx_shift <= {1'b1, uart_tx_shift[9:1]};
                        uart_tx_bit   <= uart_tx_bit + 4'd1;
                        if (uart_tx_bit >= 4'd9) begin
                            uart_tx_busy <= 1'b0;
                            rs485_tx_en  <= 1'b0; // back to receive
                            rs485_tx     <= 1'b1;
                        end
                    end else begin
                        uart_tx_div <= uart_tx_div + 10'd1;
                    end
                end else if (uart_send_req) begin
                    uart_send_req  <= 1'b0;
                    uart_tx_shift  <= {1'b1, uart_send_data, 1'b0}; // stop + data + start
                    uart_tx_busy   <= 1'b1;
                    uart_tx_bit    <= 4'd0;
                    uart_tx_div    <= 10'd0;
                    rs485_tx_en    <= 1'b1; // transmit mode
                    rs485_tx       <= 1'b0; // start bit
                end

                // ============================================================
                // UART RX engine
                // ============================================================
                rx_prev <= rs485_rx;
                if (!uart_rx_busy) begin
                    // Detect start bit (falling edge)
                    if (rx_prev && !rs485_rx) begin
                        uart_rx_busy <= 1'b1;
                        uart_rx_div  <= UART_DIV[9:0] / 2; // sample at mid-bit
                        uart_rx_bit  <= 4'd0;
                    end
                end else begin
                    if (uart_rx_div >= UART_DIV - 1) begin
                        uart_rx_div <= 10'd0;
                        uart_rx_bit <= uart_rx_bit + 4'd1;
                        if (uart_rx_bit >= 4'd1 && uart_rx_bit <= 4'd8) begin
                            uart_rx_shift <= {rs485_rx, uart_rx_shift[7:1]};
                        end
                        if (uart_rx_bit >= 4'd9) begin // stop bit
                            uart_rx_busy <= 1'b0;
                            uart_rx_done <= 1'b1;
                            uart_rx_data <= uart_rx_shift;
                        end
                    end else begin
                        uart_rx_div <= uart_rx_div + 10'd1;
                    end
                end

                // ============================================================
                // Auth FSM
                // ============================================================
                case (auth_state)
                    AUTH_IDLE: begin
                        // Wait for AUTH_CHALLENGE from core via HMCB
                        if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_AUTH_CHALLENGE &&
                            (`HMCB_DEST(hmcb_rx) == MID_PROP_LINK || `HMCB_DEST(hmcb_rx) == MID_BROADCAST)) begin
                            challenge <= lfsr;  // Use current LFSR state as challenge
                            expected_response <= (lfsr ^ device_secret[31:0]) ^ device_secret[63:32];
                            chal_byte_idx <= 2'd0;
                            auth_state    <= AUTH_SEND_CHAL;
                        end
                    end

                    AUTH_SEND_CHAL: begin
                        // Send 4 challenge bytes over RS-485
                        if (!uart_tx_busy && !uart_send_req) begin
                            case (chal_byte_idx)
                                2'd0: uart_send_data <= challenge[31:24];
                                2'd1: uart_send_data <= challenge[23:16];
                                2'd2: uart_send_data <= challenge[15:8];
                                2'd3: uart_send_data <= challenge[7:0];
                            endcase
                            uart_send_req <= 1'b1;
                            if (chal_byte_idx == 2'd3) begin
                                auth_state    <= AUTH_RECV_BYTES;
                                resp_byte_cnt <= 2'd0;
                                received_response <= 32'd0;
                            end else begin
                                chal_byte_idx <= chal_byte_idx + 2'd1;
                            end
                        end
                    end

                    AUTH_RECV_BYTES: begin
                        // Receive 4 response bytes from dongle
                        if (uart_rx_done) begin
                            case (resp_byte_cnt)
                                2'd0: received_response[31:24] <= uart_rx_data;
                                2'd1: received_response[23:16] <= uart_rx_data;
                                2'd2: received_response[15:8]  <= uart_rx_data;
                                2'd3: received_response[7:0]   <= uart_rx_data;
                            endcase
                            if (resp_byte_cnt == 2'd3) begin
                                auth_state <= AUTH_CHECK_RESP;
                            end else begin
                                resp_byte_cnt <= resp_byte_cnt + 2'd1;
                            end
                        end
                    end

                    AUTH_CHECK_RESP: begin
                        if (received_response == expected_response) begin
                            link_authenticated <= 1'b1;
                            dongle_present     <= 1'b1;
                            session_timer      <= 6'd0;
                            // Forward AUTH_RESPONSE + grant to core
                            hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_PROP_LINK, CMD_AUTH_RESPONSE, 8'h00, 8'h01);
                            hmcb_tx_valid <= 1'b1;
                            auth_state    <= AUTH_GRANTED;
                        end else begin
                            link_authenticated <= 1'b0;
                            dongle_present     <= 1'b0;
                            // Report failure
                            hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_PROP_LINK, CMD_AUTH_RESPONSE, 8'h00, 8'h00);
                            hmcb_tx_valid <= 1'b1;
                            auth_state    <= AUTH_IDLE;
                        end
                    end

                    AUTH_GRANTED: begin
                        // Session active; wait for timeout or re-auth request
                        if (!link_authenticated)
                            auth_state <= AUTH_IDLE;
                    end

                    default: auth_state <= AUTH_IDLE;
                endcase

                // ---- HMCB PING response ----
                if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_PING &&
                    (`HMCB_DEST(hmcb_rx) == MID_BROADCAST || `HMCB_DEST(hmcb_rx) == MID_PROP_LINK)) begin
                    hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_PROP_LINK, CMD_PONG, 8'h00, MID_PROP_LINK);
                    hmcb_tx_valid <= 1'b1;
                end
            end
        end

    end
    endgenerate

endmodule
