`timescale 1ns / 1ps

module config_registers (
    input wire clk,
    input wire reset,
    input wire load_temp_btn,      
    input wire load_light_btn,     
    input wire [7:0] switch_input, 
    output reg [7:0] temp_threshold,
    output reg [7:0] light_threshold
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            temp_threshold <= 8'd30;   
            light_threshold <= 8'd100; 
        end else begin
            if (load_temp_btn) 
                temp_threshold <= switch_input;
            if (load_light_btn) 
                light_threshold <= switch_input;
        end
    end
endmodule