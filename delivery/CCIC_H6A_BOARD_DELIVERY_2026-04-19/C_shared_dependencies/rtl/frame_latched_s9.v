`timescale 1ns / 1ps

module frame_latched_s9 (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              cfg_valid,
    output wire              cfg_ready,
    input  wire signed [8:0] cfg_data,
    input  wire              frame_start_pulse,
    output reg  signed [8:0] active_data,
    output wire signed [8:0] frame_data
);

    reg              pending_valid;
    reg signed [8:0] pending_data;

    assign cfg_ready = 1'b1;
    assign frame_data = (frame_start_pulse && pending_valid) ? pending_data : active_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_valid <= 1'b0;
            pending_data  <= 9'sd0;
            active_data   <= 9'sd0;
        end else begin
            if (cfg_valid) begin
                pending_valid <= 1'b1;
                pending_data  <= cfg_data;
            end

            if (frame_start_pulse && pending_valid) begin
                active_data   <= pending_data;
                pending_valid <= 1'b0;
            end
        end
    end

endmodule
