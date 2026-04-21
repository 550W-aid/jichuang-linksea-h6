`timescale 1ns / 1ps

module bilateral_3x3_core #(
    parameter integer RANGE_SHIFT = 4
) (
    input  wire        clk,      // processing clock
    input  wire        rst_n,    // active-low reset
    input  wire        i_valid,  // input window valid
    output wire        i_ready,  // input window ready
    input  wire [71:0] i_window, // 3x3 grayscale window, p00..p22
    output wire        o_valid,  // output pixel valid
    input  wire        o_ready,  // downstream ready
    output wire [7:0]  o_pixel   // filtered grayscale output
);
    reg         s1_valid;
    reg [7:0]   s1_pix0;
    reg [7:0]   s1_pix1;
    reg [7:0]   s1_pix2;
    reg [7:0]   s1_pix3;
    reg [7:0]   s1_pix4;
    reg [7:0]   s1_pix5;
    reg [7:0]   s1_pix6;
    reg [7:0]   s1_pix7;
    reg [7:0]   s1_pix8;
    reg [4:0]   s1_range0;
    reg [4:0]   s1_range1;
    reg [4:0]   s1_range2;
    reg [4:0]   s1_range3;
    reg [4:0]   s1_range4;
    reg [4:0]   s1_range5;
    reg [4:0]   s1_range6;
    reg [4:0]   s1_range7;
    reg [4:0]   s1_range8;

    reg         s2_valid;
    reg [15:0]  s2_weighted0;
    reg [15:0]  s2_weighted1;
    reg [15:0]  s2_weighted2;
    reg [15:0]  s2_weighted3;
    reg [15:0]  s2_weighted4;
    reg [15:0]  s2_weighted5;
    reg [15:0]  s2_weighted6;
    reg [15:0]  s2_weighted7;
    reg [15:0]  s2_weighted8;
    reg [9:0]   s2_weight0;
    reg [9:0]   s2_weight1;
    reg [9:0]   s2_weight2;
    reg [9:0]   s2_weight3;
    reg [9:0]   s2_weight4;
    reg [9:0]   s2_weight5;
    reg [9:0]   s2_weight6;
    reg [9:0]   s2_weight7;
    reg [9:0]   s2_weight8;

    reg         s3_valid;
    reg [15:0]  s3_weighted_row0;
    reg [15:0]  s3_weighted_row1;
    reg [15:0]  s3_weighted_row2;
    reg [9:0]   s3_weight_row0;
    reg [9:0]   s3_weight_row1;
    reg [9:0]   s3_weight_row2;

    reg         s4_valid;
    reg [15:0]  s4_weighted_sum;
    reg [9:0]   s4_weight_sum;

    wire        div_in_ready;
    wire        div_out_valid;
    wire [7:0]  div_out_quotient;
    wire        s4_ready;
    wire        s3_ready;
    wire        s2_ready;
    wire        s1_ready;

    wire [7:0] pix0_w;
    wire [7:0] pix1_w;
    wire [7:0] pix2_w;
    wire [7:0] pix3_w;
    wire [7:0] pix4_w;
    wire [7:0] pix5_w;
    wire [7:0] pix6_w;
    wire [7:0] pix7_w;
    wire [7:0] pix8_w;
    wire [7:0] center_w;

    wire [7:0] diff0_w;
    wire [7:0] diff1_w;
    wire [7:0] diff2_w;
    wire [7:0] diff3_w;
    wire [7:0] diff4_w;
    wire [7:0] diff5_w;
    wire [7:0] diff6_w;
    wire [7:0] diff7_w;
    wire [7:0] diff8_w;

    wire [4:0] range0_w;
    wire [4:0] range1_w;
    wire [4:0] range2_w;
    wire [4:0] range3_w;
    wire [4:0] range4_w;
    wire [4:0] range5_w;
    wire [4:0] range6_w;
    wire [4:0] range7_w;
    wire [4:0] range8_w;

    wire [12:0] pix0_mul_range0_w;
    wire [12:0] pix1_mul_range1_w;
    wire [12:0] pix2_mul_range2_w;
    wire [12:0] pix3_mul_range3_w;
    wire [12:0] pix4_mul_range4_w;
    wire [12:0] pix5_mul_range5_w;
    wire [12:0] pix6_mul_range6_w;
    wire [12:0] pix7_mul_range7_w;
    wire [12:0] pix8_mul_range8_w;

    wire [15:0] weighted0_w;
    wire [15:0] weighted1_w;
    wire [15:0] weighted2_w;
    wire [15:0] weighted3_w;
    wire [15:0] weighted4_w;
    wire [15:0] weighted5_w;
    wire [15:0] weighted6_w;
    wire [15:0] weighted7_w;
    wire [15:0] weighted8_w;

    wire [9:0] weight0_w;
    wire [9:0] weight1_w;
    wire [9:0] weight2_w;
    wire [9:0] weight3_w;
    wire [9:0] weight4_w;
    wire [9:0] weight5_w;
    wire [9:0] weight6_w;
    wire [9:0] weight7_w;
    wire [9:0] weight8_w;

    wire [15:0] weighted_row0_w;
    wire [15:0] weighted_row1_w;
    wire [15:0] weighted_row2_w;
    wire [9:0]  weight_row0_w;
    wire [9:0]  weight_row1_w;
    wire [9:0]  weight_row2_w;

    // Return the absolute difference between two 8-bit pixels.
    function [7:0] abs_diff8;
        input [7:0] a;
        input [7:0] b;
        begin
            if (a > b) begin
                abs_diff8 = a - b;
            end else begin
                abs_diff8 = b - a;
            end
        end
    endfunction

    // Clamp the bilateral range weight into [1, 16] for the validated default
    // RANGE_SHIFT path, avoiding accidental underflow in synthesis.
    function [4:0] range_weight;
        input [7:0] diff_value;
        reg [7:0] shifted;
        begin
            shifted = diff_value >> RANGE_SHIFT;
            if (shifted >= 8'd15) begin
                range_weight = 5'd1;
            end else begin
                range_weight = 5'd16 - shifted[4:0];
            end
        end
    endfunction

    assign pix0_w   = i_window[71:64];
    assign pix1_w   = i_window[63:56];
    assign pix2_w   = i_window[55:48];
    assign pix3_w   = i_window[47:40];
    assign pix4_w   = i_window[39:32];
    assign pix5_w   = i_window[31:24];
    assign pix6_w   = i_window[23:16];
    assign pix7_w   = i_window[15:8];
    assign pix8_w   = i_window[7:0];
    assign center_w = pix4_w;

    assign diff0_w = abs_diff8(pix0_w, center_w);
    assign diff1_w = abs_diff8(pix1_w, center_w);
    assign diff2_w = abs_diff8(pix2_w, center_w);
    assign diff3_w = abs_diff8(pix3_w, center_w);
    assign diff4_w = abs_diff8(pix4_w, center_w);
    assign diff5_w = abs_diff8(pix5_w, center_w);
    assign diff6_w = abs_diff8(pix6_w, center_w);
    assign diff7_w = abs_diff8(pix7_w, center_w);
    assign diff8_w = abs_diff8(pix8_w, center_w);

    assign range0_w = range_weight(diff0_w);
    assign range1_w = range_weight(diff1_w);
    assign range2_w = range_weight(diff2_w);
    assign range3_w = range_weight(diff3_w);
    assign range4_w = range_weight(diff4_w);
    assign range5_w = range_weight(diff5_w);
    assign range6_w = range_weight(diff6_w);
    assign range7_w = range_weight(diff7_w);
    assign range8_w = range_weight(diff8_w);

    assign pix0_mul_range0_w = s1_pix0 * s1_range0;
    assign pix1_mul_range1_w = s1_pix1 * s1_range1;
    assign pix2_mul_range2_w = s1_pix2 * s1_range2;
    assign pix3_mul_range3_w = s1_pix3 * s1_range3;
    assign pix4_mul_range4_w = s1_pix4 * s1_range4;
    assign pix5_mul_range5_w = s1_pix5 * s1_range5;
    assign pix6_mul_range6_w = s1_pix6 * s1_range6;
    assign pix7_mul_range7_w = s1_pix7 * s1_range7;
    assign pix8_mul_range8_w = s1_pix8 * s1_range8;

    assign weighted0_w = {3'd0, pix0_mul_range0_w};
    assign weighted1_w = {2'd0, pix1_mul_range1_w, 1'b0};
    assign weighted2_w = {3'd0, pix2_mul_range2_w};
    assign weighted3_w = {2'd0, pix3_mul_range3_w, 1'b0};
    assign weighted4_w = {1'd0, pix4_mul_range4_w, 2'b00};
    assign weighted5_w = {2'd0, pix5_mul_range5_w, 1'b0};
    assign weighted6_w = {3'd0, pix6_mul_range6_w};
    assign weighted7_w = {2'd0, pix7_mul_range7_w, 1'b0};
    assign weighted8_w = {3'd0, pix8_mul_range8_w};

    assign weight0_w = {5'd0, s1_range0};
    assign weight1_w = {4'd0, s1_range1, 1'b0};
    assign weight2_w = {5'd0, s1_range2};
    assign weight3_w = {4'd0, s1_range3, 1'b0};
    assign weight4_w = {3'd0, s1_range4, 2'b00};
    assign weight5_w = {4'd0, s1_range5, 1'b0};
    assign weight6_w = {5'd0, s1_range6};
    assign weight7_w = {4'd0, s1_range7, 1'b0};
    assign weight8_w = {5'd0, s1_range8};

    assign weighted_row0_w = s2_weighted0 + s2_weighted1 + s2_weighted2;
    assign weighted_row1_w = s2_weighted3 + s2_weighted4 + s2_weighted5;
    assign weighted_row2_w = s2_weighted6 + s2_weighted7 + s2_weighted8;
    assign weight_row0_w   = s2_weight0 + s2_weight1 + s2_weight2;
    assign weight_row1_w   = s2_weight3 + s2_weight4 + s2_weight5;
    assign weight_row2_w   = s2_weight6 + s2_weight7 + s2_weight8;

    assign s4_ready = (~s4_valid) | div_in_ready;
    assign s3_ready = (~s3_valid) | s4_ready;
    assign s2_ready = (~s2_valid) | s3_ready;
    assign s1_ready = (~s1_valid) | s2_ready;
    assign i_ready  = s1_ready;

    u16_u10_div_pipe8 u_div (
        .clk    (clk),
        .rst_n  (rst_n),
        .i_valid(s4_valid),
        .i_ready(div_in_ready),
        .i_num  (s4_weighted_sum),
        .i_den  (s4_weight_sum),
        .o_valid(div_out_valid),
        .o_ready(o_ready),
        .o_quot (div_out_quotient)
    );

    assign o_valid = div_out_valid;
    assign o_pixel = div_out_quotient;

    // Stage 1: register the input window and the per-pixel bilateral range
    // weights so the following multiplier bank starts from stable inputs.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid  <= 1'b0;
            s1_pix0   <= 8'd0;
            s1_pix1   <= 8'd0;
            s1_pix2   <= 8'd0;
            s1_pix3   <= 8'd0;
            s1_pix4   <= 8'd0;
            s1_pix5   <= 8'd0;
            s1_pix6   <= 8'd0;
            s1_pix7   <= 8'd0;
            s1_pix8   <= 8'd0;
            s1_range0 <= 5'd0;
            s1_range1 <= 5'd0;
            s1_range2 <= 5'd0;
            s1_range3 <= 5'd0;
            s1_range4 <= 5'd0;
            s1_range5 <= 5'd0;
            s1_range6 <= 5'd0;
            s1_range7 <= 5'd0;
            s1_range8 <= 5'd0;
        end else if (s1_ready) begin
            s1_valid <= i_valid;
            if (i_valid) begin
                s1_pix0   <= pix0_w;
                s1_pix1   <= pix1_w;
                s1_pix2   <= pix2_w;
                s1_pix3   <= pix3_w;
                s1_pix4   <= pix4_w;
                s1_pix5   <= pix5_w;
                s1_pix6   <= pix6_w;
                s1_pix7   <= pix7_w;
                s1_pix8   <= pix8_w;
                s1_range0 <= range0_w;
                s1_range1 <= range1_w;
                s1_range2 <= range2_w;
                s1_range3 <= range3_w;
                s1_range4 <= range4_w;
                s1_range5 <= range5_w;
                s1_range6 <= range6_w;
                s1_range7 <= range7_w;
                s1_range8 <= range8_w;
            end else begin
                s1_pix0   <= 8'd0;
                s1_pix1   <= 8'd0;
                s1_pix2   <= 8'd0;
                s1_pix3   <= 8'd0;
                s1_pix4   <= 8'd0;
                s1_pix5   <= 8'd0;
                s1_pix6   <= 8'd0;
                s1_pix7   <= 8'd0;
                s1_pix8   <= 8'd0;
                s1_range0 <= 5'd0;
                s1_range1 <= 5'd0;
                s1_range2 <= 5'd0;
                s1_range3 <= 5'd0;
                s1_range4 <= 5'd0;
                s1_range5 <= 5'd0;
                s1_range6 <= 5'd0;
                s1_range7 <= 5'd0;
                s1_range8 <= 5'd0;
            end
        end
    end

    // Stage 2: register the nine weighted products and weight terms directly,
    // isolating multiplier depth from the later adder tree.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid     <= 1'b0;
            s2_weighted0 <= 16'd0;
            s2_weighted1 <= 16'd0;
            s2_weighted2 <= 16'd0;
            s2_weighted3 <= 16'd0;
            s2_weighted4 <= 16'd0;
            s2_weighted5 <= 16'd0;
            s2_weighted6 <= 16'd0;
            s2_weighted7 <= 16'd0;
            s2_weighted8 <= 16'd0;
            s2_weight0   <= 10'd0;
            s2_weight1   <= 10'd0;
            s2_weight2   <= 10'd0;
            s2_weight3   <= 10'd0;
            s2_weight4   <= 10'd0;
            s2_weight5   <= 10'd0;
            s2_weight6   <= 10'd0;
            s2_weight7   <= 10'd0;
            s2_weight8   <= 10'd0;
        end else if (s2_ready) begin
            s2_valid <= s1_valid;
            if (s1_valid) begin
                s2_weighted0 <= weighted0_w;
                s2_weighted1 <= weighted1_w;
                s2_weighted2 <= weighted2_w;
                s2_weighted3 <= weighted3_w;
                s2_weighted4 <= weighted4_w;
                s2_weighted5 <= weighted5_w;
                s2_weighted6 <= weighted6_w;
                s2_weighted7 <= weighted7_w;
                s2_weighted8 <= weighted8_w;
                s2_weight0   <= weight0_w;
                s2_weight1   <= weight1_w;
                s2_weight2   <= weight2_w;
                s2_weight3   <= weight3_w;
                s2_weight4   <= weight4_w;
                s2_weight5   <= weight5_w;
                s2_weight6   <= weight6_w;
                s2_weight7   <= weight7_w;
                s2_weight8   <= weight8_w;
            end else begin
                s2_weighted0 <= 16'd0;
                s2_weighted1 <= 16'd0;
                s2_weighted2 <= 16'd0;
                s2_weighted3 <= 16'd0;
                s2_weighted4 <= 16'd0;
                s2_weighted5 <= 16'd0;
                s2_weighted6 <= 16'd0;
                s2_weighted7 <= 16'd0;
                s2_weighted8 <= 16'd0;
                s2_weight0   <= 10'd0;
                s2_weight1   <= 10'd0;
                s2_weight2   <= 10'd0;
                s2_weight3   <= 10'd0;
                s2_weight4   <= 10'd0;
                s2_weight5   <= 10'd0;
                s2_weight6   <= 10'd0;
                s2_weight7   <= 10'd0;
                s2_weight8   <= 10'd0;
            end
        end
    end

    // Stage 3: collapse the registered tap terms into three row sums.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_valid         <= 1'b0;
            s3_weighted_row0 <= 16'd0;
            s3_weighted_row1 <= 16'd0;
            s3_weighted_row2 <= 16'd0;
            s3_weight_row0   <= 10'd0;
            s3_weight_row1   <= 10'd0;
            s3_weight_row2   <= 10'd0;
        end else if (s3_ready) begin
            s3_valid <= s2_valid;
            if (s2_valid) begin
                s3_weighted_row0 <= weighted_row0_w;
                s3_weighted_row1 <= weighted_row1_w;
                s3_weighted_row2 <= weighted_row2_w;
                s3_weight_row0   <= weight_row0_w;
                s3_weight_row1   <= weight_row1_w;
                s3_weight_row2   <= weight_row2_w;
            end else begin
                s3_weighted_row0 <= 16'd0;
                s3_weighted_row1 <= 16'd0;
                s3_weighted_row2 <= 16'd0;
                s3_weight_row0   <= 10'd0;
                s3_weight_row1   <= 10'd0;
                s3_weight_row2   <= 10'd0;
            end
        end
    end

    // Stage 4: collapse the three row sums into a single numerator and
    // denominator, then hand them to the pipelined divider.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s4_valid        <= 1'b0;
            s4_weighted_sum <= 16'd0;
            s4_weight_sum   <= 10'd0;
        end else if (s4_ready) begin
            s4_valid <= s3_valid;
            if (s3_valid) begin
                s4_weighted_sum <= s3_weighted_row0 + s3_weighted_row1 + s3_weighted_row2;
                s4_weight_sum   <= s3_weight_row0 + s3_weight_row1 + s3_weight_row2;
            end else begin
                s4_weighted_sum <= 16'd0;
                s4_weight_sum   <= 10'd0;
            end
        end
    end
endmodule
