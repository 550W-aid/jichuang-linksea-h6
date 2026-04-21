`timescale 1ns / 1ps

module guided_filter_3x3_core #(
    parameter [7:0] EDGE_THRESH = 8'd12,
    parameter [3:0] EDGE_GAIN   = 4'd3,
    parameter [3:0] FLAT_GAIN   = 4'd1
) (
    input  wire        clk,      // processing clock
    input  wire        rst_n,    // active-low reset
    input  wire        i_valid,  // input window valid
    output wire        i_ready,  // input window ready
    input  wire [71:0] i_window, // 3x3 grayscale window, p00..p22
    output reg         o_valid,  // filtered pixel valid
    input  wire        o_ready,  // downstream ready
    output reg  [7:0]  o_pixel   // filtered grayscale pixel
);
    reg         s1_valid;
    reg [11:0]  s1_sum_all;
    reg [7:0]   s1_center;

    reg         s2_valid;
    reg [19:0]  s2_mean_mult;
    reg [7:0]   s2_center;

    reg         s3_valid;
    reg [7:0]   s3_mean9;
    reg [7:0]   s3_center;

    reg         s4_valid;
    reg [7:0]   s4_mean9;
    reg signed [8:0] s4_diff;
    reg [3:0]   s4_gain_sel;

    reg         s5_valid;
    reg [7:0]   s5_mean9;
    reg signed [12:0] s5_scaled_diff;

    reg         s6_valid;
    reg signed [12:0] s6_enhanced;

    wire s7_ready;
    wire s6_ready;
    wire s5_ready;
    wire s4_ready;
    wire s3_ready;
    wire s2_ready;
    wire s1_ready;

    wire [7:0] p00;
    wire [7:0] p01;
    wire [7:0] p02;
    wire [7:0] p10;
    wire [7:0] p11;
    wire [7:0] p12;
    wire [7:0] p20;
    wire [7:0] p21;
    wire [7:0] p22;

    wire [9:0]  row_sum0_w;
    wire [9:0]  row_sum1_w;
    wire [9:0]  row_sum2_w;
    wire [11:0] sum_all_w;
    wire [19:0] mean_mult_w;
    wire [7:0]  mean9_w;
    wire signed [8:0] diff_w;
    wire [7:0]  abs_diff_w;
    wire [3:0]  gain_sel_w;
    wire signed [12:0] scaled_diff_w;
    wire signed [12:0] enhanced_w;

    // Saturate a signed intermediate value into 8-bit unsigned output.
    function [7:0] sat_u8;
        input signed [12:0] value;
        begin
            if (value < 0) begin
                sat_u8 = 8'd0;
            end else if (value > 13'sd255) begin
                sat_u8 = 8'hFF;
            end else begin
                sat_u8 = value[7:0];
            end
        end
    endfunction

    assign p00 = i_window[71:64];
    assign p01 = i_window[63:56];
    assign p02 = i_window[55:48];
    assign p10 = i_window[47:40];
    assign p11 = i_window[39:32];
    assign p12 = i_window[31:24];
    assign p20 = i_window[23:16];
    assign p21 = i_window[15:8];
    assign p22 = i_window[7:0];

    assign row_sum0_w = p00 + p01 + p02;
    assign row_sum1_w = p10 + p11 + p12;
    assign row_sum2_w = p20 + p21 + p22;
    assign sum_all_w  = row_sum0_w + row_sum1_w + row_sum2_w;

    assign mean_mult_w   = {8'd0, s1_sum_all} * 8'd57;
    assign mean9_w       = s2_mean_mult[19:9];
    assign diff_w        = $signed({1'b0, s3_center}) - $signed({1'b0, s3_mean9});
    assign abs_diff_w    = diff_w[8] ? (~diff_w[7:0] + 8'd1) : diff_w[7:0];
    assign gain_sel_w    = (abs_diff_w > EDGE_THRESH) ? EDGE_GAIN : FLAT_GAIN;
    assign scaled_diff_w = s4_diff * $signed({1'b0, s4_gain_sel});
    assign enhanced_w    = $signed({1'b0, s5_mean9}) + (s5_scaled_diff >>> 1);

    assign s7_ready = (~o_valid)  | o_ready;
    assign s6_ready = (~s6_valid) | s7_ready;
    assign s5_ready = (~s5_valid) | s6_ready;
    assign s4_ready = (~s4_valid) | s5_ready;
    assign s3_ready = (~s3_valid) | s4_ready;
    assign s2_ready = (~s2_valid) | s3_ready;
    assign s1_ready = (~s1_valid) | s2_ready;
    assign i_ready  = s1_ready;

    // Pipeline the guided-filter arithmetic so DSP and carry chains do not
    // share one cycle at 138.5 MHz.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid      <= 1'b0;
            s1_sum_all    <= 12'd0;
            s1_center     <= 8'd0;
            s2_valid      <= 1'b0;
            s2_mean_mult  <= 20'd0;
            s2_center     <= 8'd0;
            s3_valid      <= 1'b0;
            s3_mean9      <= 8'd0;
            s3_center     <= 8'd0;
            s4_valid      <= 1'b0;
            s4_mean9      <= 8'd0;
            s4_diff       <= 9'sd0;
            s4_gain_sel   <= 4'd0;
            s5_valid      <= 1'b0;
            s5_mean9      <= 8'd0;
            s5_scaled_diff <= 13'sd0;
            s6_valid      <= 1'b0;
            s6_enhanced   <= 13'sd0;
            o_valid       <= 1'b0;
            o_pixel       <= 8'd0;
        end else begin
            if (s1_ready) begin
                s1_valid <= i_valid;
                if (i_valid) begin
                    s1_sum_all <= sum_all_w;
                    s1_center  <= p11;
                end else begin
                    s1_sum_all <= 12'd0;
                    s1_center  <= 8'd0;
                end
            end

            if (s2_ready) begin
                s2_valid <= s1_valid;
                if (s1_valid) begin
                    s2_mean_mult <= mean_mult_w;
                    s2_center    <= s1_center;
                end else begin
                    s2_mean_mult <= 20'd0;
                    s2_center    <= 8'd0;
                end
            end

            if (s3_ready) begin
                s3_valid <= s2_valid;
                if (s2_valid) begin
                    s3_mean9  <= mean9_w;
                    s3_center <= s2_center;
                end else begin
                    s3_mean9  <= 8'd0;
                    s3_center <= 8'd0;
                end
            end

            if (s4_ready) begin
                s4_valid <= s3_valid;
                if (s3_valid) begin
                    s4_mean9    <= s3_mean9;
                    s4_diff     <= diff_w;
                    s4_gain_sel <= gain_sel_w;
                end else begin
                    s4_mean9    <= 8'd0;
                    s4_diff     <= 9'sd0;
                    s4_gain_sel <= 4'd0;
                end
            end

            if (s5_ready) begin
                s5_valid <= s4_valid;
                if (s4_valid) begin
                    s5_mean9       <= s4_mean9;
                    s5_scaled_diff <= scaled_diff_w;
                end else begin
                    s5_mean9       <= 8'd0;
                    s5_scaled_diff <= 13'sd0;
                end
            end

            if (s6_ready) begin
                s6_valid <= s5_valid;
                if (s5_valid) begin
                    s6_enhanced <= enhanced_w;
                end else begin
                    s6_enhanced <= 13'sd0;
                end
            end

            if (s7_ready) begin
                o_valid <= s6_valid;
                if (s6_valid) begin
                    o_pixel <= sat_u8(s6_enhanced);
                end else begin
                    o_pixel <= 8'd0;
                end
            end
        end
    end
endmodule
