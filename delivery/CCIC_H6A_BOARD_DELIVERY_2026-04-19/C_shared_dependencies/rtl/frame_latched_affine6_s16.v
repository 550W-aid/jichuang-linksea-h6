`timescale 1ns / 1ps

module frame_latched_affine6_s16 (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               cfg_valid,
    output wire               cfg_ready,
    input  wire signed [15:0] cfg_m00,
    input  wire signed [15:0] cfg_m01,
    input  wire signed [15:0] cfg_m02,
    input  wire signed [15:0] cfg_m10,
    input  wire signed [15:0] cfg_m11,
    input  wire signed [15:0] cfg_m12,
    input  wire               frame_start_pulse,
    output reg  signed [15:0] active_m00,
    output reg  signed [15:0] active_m01,
    output reg  signed [15:0] active_m02,
    output reg  signed [15:0] active_m10,
    output reg  signed [15:0] active_m11,
    output reg  signed [15:0] active_m12,
    output wire signed [15:0] frame_m00,
    output wire signed [15:0] frame_m01,
    output wire signed [15:0] frame_m02,
    output wire signed [15:0] frame_m10,
    output wire signed [15:0] frame_m11,
    output wire signed [15:0] frame_m12
);

    reg               pending_valid;
    reg signed [15:0] pending_m00;
    reg signed [15:0] pending_m01;
    reg signed [15:0] pending_m02;
    reg signed [15:0] pending_m10;
    reg signed [15:0] pending_m11;
    reg signed [15:0] pending_m12;

    assign cfg_ready = 1'b1;
    assign frame_m00 = (frame_start_pulse && pending_valid) ? pending_m00 : active_m00;
    assign frame_m01 = (frame_start_pulse && pending_valid) ? pending_m01 : active_m01;
    assign frame_m02 = (frame_start_pulse && pending_valid) ? pending_m02 : active_m02;
    assign frame_m10 = (frame_start_pulse && pending_valid) ? pending_m10 : active_m10;
    assign frame_m11 = (frame_start_pulse && pending_valid) ? pending_m11 : active_m11;
    assign frame_m12 = (frame_start_pulse && pending_valid) ? pending_m12 : active_m12;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_valid <= 1'b0;
            pending_m00   <= 16'sd256;
            pending_m01   <= 16'sd0;
            pending_m02   <= 16'sd0;
            pending_m10   <= 16'sd0;
            pending_m11   <= 16'sd256;
            pending_m12   <= 16'sd0;
            active_m00    <= 16'sd256;
            active_m01    <= 16'sd0;
            active_m02    <= 16'sd0;
            active_m10    <= 16'sd0;
            active_m11    <= 16'sd256;
            active_m12    <= 16'sd0;
        end else begin
            if (cfg_valid) begin
                pending_valid <= 1'b1;
                pending_m00   <= cfg_m00;
                pending_m01   <= cfg_m01;
                pending_m02   <= cfg_m02;
                pending_m10   <= cfg_m10;
                pending_m11   <= cfg_m11;
                pending_m12   <= cfg_m12;
            end

            if (frame_start_pulse && pending_valid) begin
                active_m00    <= pending_m00;
                active_m01    <= pending_m01;
                active_m02    <= pending_m02;
                active_m10    <= pending_m10;
                active_m11    <= pending_m11;
                active_m12    <= pending_m12;
                pending_valid <= 1'b0;
            end
        end
    end

endmodule
