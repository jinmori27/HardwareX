// ============================================================================
// HomeGuardX v2.0 — Multi-Sensor Hub (Module 0x7)
// Aggregates DHT22 (humidity+temp), MQ-2 (gas/smoke), MQ-7 (CO)
// Serial shift-register ADC interface, 1Hz sampling
// Reports data and raises alarms via HMCB
// ============================================================================
`timescale 1ns / 1ps

module multi_sensor_hub #(
    parameter MODULE_PRESENT = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,

    // Serial ADC interface (shift-register style)
    output reg         adc_cs_n,       // Chip select (active low)
    output reg         adc_sclk,       // Serial clock
    input  wire        adc_miso,       // Serial data in
    output reg  [1:0]  adc_ch_sel,     // Channel select (0=DHT_hum, 1=DHT_temp, 2=MQ2, 3=MQ7)

    // DHT22 one-wire interface (for humidity/temperature)
    inout  wire        dht22_data,

    // Thresholds
    input  wire [7:0]  humidity_threshold,
    input  wire [7:0]  gas_threshold,
    input  wire [7:0]  co_threshold,

    // HMCB interface
    input  wire [31:0] hmcb_rx,
    input  wire        hmcb_rx_valid,
    output reg  [31:0] hmcb_tx,
    output reg         hmcb_tx_valid,

    // Sensor data outputs (directly usable by other modules)
    output reg  [7:0]  temp_reading,
    output reg  [7:0]  humidity_reading,
    output reg  [7:0]  gas_reading,
    output reg  [7:0]  co_reading,
    output reg  [7:0]  light_reading   // ambient light from ADC ch if available
);

    `include "hmcb_pkg.vh"

    generate
    if (MODULE_PRESENT == 0) begin : gen_stub
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                hmcb_tx         <= 32'd0;
                hmcb_tx_valid   <= 1'b0;
                temp_reading    <= 8'd25;
                humidity_reading<= 8'd50;
                gas_reading     <= 8'd0;
                co_reading      <= 8'd0;
                light_reading   <= 8'd128;
                adc_cs_n        <= 1'b1;
                adc_sclk        <= 1'b0;
                adc_ch_sel      <= 2'd0;
            end else begin
                hmcb_tx_valid <= 1'b0;
            end
        end
        assign dht22_data = 1'bz;
    end else begin : gen_full

        // ---- ADC shift-register read FSM ----
        // Simplified 8-bit serial read: CS low, clock 8 bits in, CS high
        localparam ADC_IDLE    = 3'd0;
        localparam ADC_START   = 3'd1;
        localparam ADC_SHIFT   = 3'd2;
        localparam ADC_DONE    = 3'd3;
        localparam ADC_NEXT    = 3'd4;
        localparam ADC_REPORT  = 3'd5;

        reg [2:0]  adc_state;
        reg [2:0]  bit_cnt;
        reg [7:0]  shift_reg;
        reg [1:0]  channel;        // current channel being read
        reg [9:0]  sclk_div;       // clock divider for ADC serial clock
        localparam SCLK_DIV_MAX = 10'd499; // 100MHz / 1000 = 100kHz SCLK

        // DHT22 is complex one-wire; for simplification, we route it
        // through the ADC as channels 0,1 (humidity, temp)
        // In real hardware, a separate DHT22 FSM would be needed.
        // Here we model it as ADC channels for synthesis compatibility.

        reg        dht22_out;
        reg        dht22_oe;
        assign dht22_data = dht22_oe ? dht22_out : 1'bz;

        // Alarm flags
        reg hum_alarm, gas_alarm, co_alarm;

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                adc_state       <= ADC_IDLE;
                adc_cs_n        <= 1'b1;
                adc_sclk        <= 1'b0;
                adc_ch_sel      <= 2'd0;
                bit_cnt         <= 3'd0;
                shift_reg       <= 8'd0;
                channel         <= 2'd0;
                sclk_div        <= 10'd0;
                temp_reading    <= 8'd25;
                humidity_reading<= 8'd50;
                gas_reading     <= 8'd0;
                co_reading      <= 8'd0;
                light_reading   <= 8'd128;
                hmcb_tx         <= 32'd0;
                hmcb_tx_valid   <= 1'b0;
                hum_alarm       <= 1'b0;
                gas_alarm       <= 1'b0;
                co_alarm        <= 1'b0;
                dht22_out       <= 1'b1;
                dht22_oe        <= 1'b0;
            end else begin
                hmcb_tx_valid <= 1'b0;

                case (adc_state)
                    ADC_IDLE: begin
                        adc_cs_n <= 1'b1;
                        adc_sclk <= 1'b0;
                        if (tick_1hz) begin
                            channel   <= 2'd0;
                            adc_state <= ADC_START;
                        end
                    end

                    ADC_START: begin
                        adc_cs_n   <= 1'b0;
                        adc_ch_sel <= channel;
                        bit_cnt    <= 3'd0;
                        shift_reg  <= 8'd0;
                        sclk_div   <= 10'd0;
                        adc_state  <= ADC_SHIFT;
                    end

                    ADC_SHIFT: begin
                        if (sclk_div == SCLK_DIV_MAX) begin
                            sclk_div <= 10'd0;
                            adc_sclk <= ~adc_sclk;
                            if (adc_sclk) begin // falling edge: sample
                                shift_reg <= {shift_reg[6:0], adc_miso};
                                bit_cnt   <= bit_cnt + 3'd1;
                                if (bit_cnt == 3'd7)
                                    adc_state <= ADC_DONE;
                            end
                        end else begin
                            sclk_div <= sclk_div + 10'd1;
                        end
                    end

                    ADC_DONE: begin
                        adc_cs_n <= 1'b1;
                        adc_sclk <= 1'b0;
                        // Store reading
                        case (channel)
                            2'd0: humidity_reading <= shift_reg;
                            2'd1: temp_reading     <= shift_reg;
                            2'd2: gas_reading      <= shift_reg;
                            2'd3: co_reading       <= shift_reg;
                        endcase
                        adc_state <= ADC_NEXT;
                    end

                    ADC_NEXT: begin
                        if (channel == 2'd3) begin
                            adc_state <= ADC_REPORT;
                        end else begin
                            channel   <= channel + 2'd1;
                            adc_state <= ADC_START;
                        end
                    end

                    ADC_REPORT: begin
                        // Check thresholds and report
                        // Report temp + humidity
                        hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_SENSOR_HUB, CMD_DATA_REPORT, temp_reading, humidity_reading);
                        hmcb_tx_valid <= 1'b1;

                        // Alarm checks
                        hum_alarm <= (humidity_reading > humidity_threshold);
                        gas_alarm <= (gas_reading > gas_threshold);
                        co_alarm  <= (co_reading > co_threshold);

                        adc_state <= ADC_IDLE;
                    end

                    default: adc_state <= ADC_IDLE;
                endcase

                // ---- Alarm broadcasts (one per tick cycle, prioritized) ----
                if (adc_state == ADC_IDLE && !hmcb_tx_valid) begin
                    if (gas_alarm) begin
                        hmcb_tx       <= `HMCB_PKT(MID_BROADCAST, MID_SENSOR_HUB, CMD_ALARM_RAISE, 8'h00, 8'h10);
                        hmcb_tx_valid <= 1'b1;
                    end else if (co_alarm) begin
                        hmcb_tx       <= `HMCB_PKT(MID_BROADCAST, MID_SENSOR_HUB, CMD_ALARM_RAISE, 8'h00, 8'h11);
                        hmcb_tx_valid <= 1'b1;
                    end else if (hum_alarm) begin
                        hmcb_tx       <= `HMCB_PKT(MID_BROADCAST, MID_SENSOR_HUB, CMD_ALARM_RAISE, 8'h00, 8'h12);
                        hmcb_tx_valid <= 1'b1;
                    end
                end

                // ---- HMCB PING response ----
                if (hmcb_rx_valid && `HMCB_CMD(hmcb_rx) == CMD_PING &&
                    (`HMCB_DEST(hmcb_rx) == MID_BROADCAST || `HMCB_DEST(hmcb_rx) == MID_SENSOR_HUB)) begin
                    hmcb_tx       <= `HMCB_PKT(MID_CORE, MID_SENSOR_HUB, CMD_PONG, 8'h00, MID_SENSOR_HUB);
                    hmcb_tx_valid <= 1'b1;
                end
            end
        end

    end
    endgenerate

endmodule
