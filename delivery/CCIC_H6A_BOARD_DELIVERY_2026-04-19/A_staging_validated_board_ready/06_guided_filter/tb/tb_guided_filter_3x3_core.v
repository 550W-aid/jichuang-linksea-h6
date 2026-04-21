`timescale 1ns / 1ps

module tb_guided_filter_3x3_core;

localparam [7:0] EDGE_THRESH = 8'd12;
localparam [3:0] EDGE_GAIN   = 4'd3;
localparam [3:0] FLAT_GAIN   = 4'd1;

reg         clk;
reg         rst_n;
reg         i_valid;
reg  [71:0] i_window;
reg         o_ready;
wire        i_ready;
wire        o_valid;
wire [7:0]  o_pixel;

reg [7:0] expected_pixel;
integer mismatch_count;

function [7:0] sat_u8_ref;
    input integer value;
    begin
        if (value < 0) begin
            sat_u8_ref = 8'd0;
        end else if (value > 255) begin
            sat_u8_ref = 8'hFF;
        end else begin
            sat_u8_ref = value[7:0];
        end
    end
endfunction

function [7:0] guided_ref;
    input [71:0] window;
    reg [7:0] p00;
    reg [7:0] p01;
    reg [7:0] p02;
    reg [7:0] p10;
    reg [7:0] p11;
    reg [7:0] p12;
    reg [7:0] p20;
    reg [7:0] p21;
    reg [7:0] p22;
    reg [11:0] sum_all;
    reg [7:0] mean9;
    reg signed [8:0] diff;
    reg [7:0] abs_diff;
    reg [3:0] gain_sel;
    reg signed [12:0] enhanced;
    begin
        p00 = window[71:64];
        p01 = window[63:56];
        p02 = window[55:48];
        p10 = window[47:40];
        p11 = window[39:32];
        p12 = window[31:24];
        p20 = window[23:16];
        p21 = window[15:8];
        p22 = window[7:0];

        sum_all = p00 + p01 + p02 + p10 + p11 + p12 + p20 + p21 + p22;
        mean9 = (sum_all * 57) >> 9;
        diff = $signed({1'b0, p11}) - $signed({1'b0, mean9});
        abs_diff = diff[8] ? (~diff[7:0] + 8'd1) : diff[7:0];
        gain_sel = (abs_diff > EDGE_THRESH) ? EDGE_GAIN : FLAT_GAIN;
        enhanced = $signed({1'b0, mean9}) + ((diff * $signed({1'b0, gain_sel})) >>> 1);
        guided_ref = sat_u8_ref(enhanced);
    end
endfunction

guided_filter_3x3_core #(
    .EDGE_THRESH(EDGE_THRESH),
    .EDGE_GAIN  (EDGE_GAIN),
    .FLAT_GAIN  (FLAT_GAIN)
) dut (
    .clk    (clk),
    .rst_n  (rst_n),
    .i_valid(i_valid),
    .i_ready(i_ready),
    .i_window(i_window),
    .o_valid(o_valid),
    .o_ready(o_ready),
    .o_pixel(o_pixel)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

task drive_and_check;
    input [71:0] window;
    begin
        @(negedge clk);
        if (!i_ready) begin
            mismatch_count = mismatch_count + 1;
            $display("core mismatch: i_ready deasserted before drive");
        end
        i_valid <= 1'b1;
        i_window <= window;
        expected_pixel = guided_ref(window);

        @(negedge clk);
        i_valid <= 1'b0;
        i_window <= 72'd0;

        while (!o_valid) begin
            @(posedge clk);
        end
        if (o_pixel !== expected_pixel) begin
            mismatch_count = mismatch_count + 1;
            $display("core mismatch: got=%0d exp=%0d window=%h", o_pixel, expected_pixel, window);
        end
        @(posedge clk);
    end
endtask

initial begin
    rst_n = 1'b0;
    i_valid = 1'b0;
    i_window = 72'd0;
    o_ready = 1'b1;
    expected_pixel = 8'd0;
    mismatch_count = 0;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    drive_and_check({
        8'd20, 8'd20, 8'd24,
        8'd20, 8'd20, 8'd24,
        8'd22, 8'd22, 8'd96
    });

    drive_and_check({
        8'd20, 8'd24, 8'd28,
        8'd22, 8'd96, 8'd26,
        8'd24, 8'd28, 8'd32
    });

    repeat (2) @(posedge clk);
    if (mismatch_count != 0) begin
        $fatal(1, "tb_guided_filter_3x3_core mismatch_count=%0d", mismatch_count);
    end
    $display("tb_guided_filter_3x3_core passed.");
    $finish;
end

endmodule
