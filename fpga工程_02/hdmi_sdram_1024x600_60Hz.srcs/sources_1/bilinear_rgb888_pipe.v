`timescale 1ns / 1ps

module bilinear_rgb888_pipe (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ce,
    input  wire        i_valid,
    input  wire [23:0] i_p00,
    input  wire [23:0] i_p01,
    input  wire [23:0] i_p10,
    input  wire [23:0] i_p11,
    input  wire [7:0]  i_fx,
    input  wire [7:0]  i_fy,
    input  wire        i_sof,
    input  wire        i_eol,
    input  wire        i_eof,
    output reg         o_valid,
    output reg  [23:0] o_pixel,
    output reg         o_sof,
    output reg         o_eol,
    output reg         o_eof
);

    reg         v0_q;
    reg [23:0]  p00_q;
    reg [23:0]  p01_q;
    reg [23:0]  p10_q;
    reg [23:0]  p11_q;
    reg [8:0]   inv_fx_q;
    reg [8:0]   inv_fy_q;
    reg [8:0]   fx_q;
    reg [8:0]   fy_q;
    reg         sof0_q;
    reg         eol0_q;
    reg         eof0_q;

    reg         v1_q;
    reg [16:0]  top_r_mul0_q;
    reg [16:0]  top_r_mul1_q;
    reg [16:0]  top_g_mul0_q;
    reg [16:0]  top_g_mul1_q;
    reg [16:0]  top_b_mul0_q;
    reg [16:0]  top_b_mul1_q;
    reg [16:0]  bot_r_mul0_q;
    reg [16:0]  bot_r_mul1_q;
    reg [16:0]  bot_g_mul0_q;
    reg [16:0]  bot_g_mul1_q;
    reg [16:0]  bot_b_mul0_q;
    reg [16:0]  bot_b_mul1_q;
    reg [8:0]   inv_fy1_q;
    reg [8:0]   fy1_q;
    reg         sof1_q;
    reg         eol1_q;
    reg         eof1_q;

    reg         v2_q;
    reg [17:0]  top_r_q;
    reg [17:0]  top_g_q;
    reg [17:0]  top_b_q;
    reg [17:0]  bot_r_q;
    reg [17:0]  bot_g_q;
    reg [17:0]  bot_b_q;
    reg [8:0]   inv_fy2_q;
    reg [8:0]   fy2_q;
    reg         sof2_q;
    reg         eol2_q;
    reg         eof2_q;

    reg         v3_q;
    reg [26:0]  mix_r_q;
    reg [26:0]  mix_g_q;
    reg [26:0]  mix_b_q;
    reg         sof3_q;
    reg         eol3_q;
    reg         eof3_q;

    // Stage 0: register the input sample neighborhood and interpolation fractions.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v0_q <= 1'b0;
            p00_q <= 24'd0;
            p01_q <= 24'd0;
            p10_q <= 24'd0;
            p11_q <= 24'd0;
            inv_fx_q <= 9'd0;
            inv_fy_q <= 9'd0;
            fx_q <= 9'd0;
            fy_q <= 9'd0;
            sof0_q <= 1'b0;
            eol0_q <= 1'b0;
            eof0_q <= 1'b0;
        end else if (ce) begin
            v0_q <= i_valid;
            p00_q <= i_p00;
            p01_q <= i_p01;
            p10_q <= i_p10;
            p11_q <= i_p11;
            inv_fx_q <= 9'd256 - {1'b0, i_fx};
            inv_fy_q <= 9'd256 - {1'b0, i_fy};
            fx_q <= {1'b0, i_fx};
            fy_q <= {1'b0, i_fy};
            sof0_q <= i_sof;
            eol0_q <= i_eol;
            eof0_q <= i_eof;
        end
    end

    // Stage 1: compute the horizontal multiply terms.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v1_q <= 1'b0;
            top_r_mul0_q <= 17'd0;
            top_r_mul1_q <= 17'd0;
            top_g_mul0_q <= 17'd0;
            top_g_mul1_q <= 17'd0;
            top_b_mul0_q <= 17'd0;
            top_b_mul1_q <= 17'd0;
            bot_r_mul0_q <= 17'd0;
            bot_r_mul1_q <= 17'd0;
            bot_g_mul0_q <= 17'd0;
            bot_g_mul1_q <= 17'd0;
            bot_b_mul0_q <= 17'd0;
            bot_b_mul1_q <= 17'd0;
            inv_fy1_q <= 9'd0;
            fy1_q <= 9'd0;
            sof1_q <= 1'b0;
            eol1_q <= 1'b0;
            eof1_q <= 1'b0;
        end else if (ce) begin
            v1_q <= v0_q;
            top_r_mul0_q <= p00_q[23:16] * inv_fx_q;
            top_r_mul1_q <= p01_q[23:16] * fx_q;
            top_g_mul0_q <= p00_q[15:8]  * inv_fx_q;
            top_g_mul1_q <= p01_q[15:8]  * fx_q;
            top_b_mul0_q <= p00_q[7:0]   * inv_fx_q;
            top_b_mul1_q <= p01_q[7:0]   * fx_q;
            bot_r_mul0_q <= p10_q[23:16] * inv_fx_q;
            bot_r_mul1_q <= p11_q[23:16] * fx_q;
            bot_g_mul0_q <= p10_q[15:8]  * inv_fx_q;
            bot_g_mul1_q <= p11_q[15:8]  * fx_q;
            bot_b_mul0_q <= p10_q[7:0]   * inv_fx_q;
            bot_b_mul1_q <= p11_q[7:0]   * fx_q;
            inv_fy1_q <= inv_fy_q;
            fy1_q <= fy_q;
            sof1_q <= sof0_q;
            eol1_q <= eol0_q;
            eof1_q <= eof0_q;
        end
    end

    // Stage 2: sum the horizontal products into top and bottom mixes.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v2_q <= 1'b0;
            top_r_q <= 18'd0;
            top_g_q <= 18'd0;
            top_b_q <= 18'd0;
            bot_r_q <= 18'd0;
            bot_g_q <= 18'd0;
            bot_b_q <= 18'd0;
            inv_fy2_q <= 9'd0;
            fy2_q <= 9'd0;
            sof2_q <= 1'b0;
            eol2_q <= 1'b0;
            eof2_q <= 1'b0;
        end else if (ce) begin
            v2_q <= v1_q;
            top_r_q <= top_r_mul0_q + top_r_mul1_q;
            top_g_q <= top_g_mul0_q + top_g_mul1_q;
            top_b_q <= top_b_mul0_q + top_b_mul1_q;
            bot_r_q <= bot_r_mul0_q + bot_r_mul1_q;
            bot_g_q <= bot_g_mul0_q + bot_g_mul1_q;
            bot_b_q <= bot_b_mul0_q + bot_b_mul1_q;
            inv_fy2_q <= inv_fy1_q;
            fy2_q <= fy1_q;
            sof2_q <= sof1_q;
            eol2_q <= eol1_q;
            eof2_q <= eof1_q;
        end
    end

    // Stage 3: vertical interpolation for each color channel.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v3_q <= 1'b0;
            mix_r_q <= 27'd0;
            mix_g_q <= 27'd0;
            mix_b_q <= 27'd0;
            sof3_q <= 1'b0;
            eol3_q <= 1'b0;
            eof3_q <= 1'b0;
        end else if (ce) begin
            v3_q <= v2_q;
            mix_r_q <= (top_r_q * inv_fy2_q) + (bot_r_q * fy2_q);
            mix_g_q <= (top_g_q * inv_fy2_q) + (bot_g_q * fy2_q);
            mix_b_q <= (top_b_q * inv_fy2_q) + (bot_b_q * fy2_q);
            sof3_q <= sof2_q;
            eol3_q <= eol2_q;
            eof3_q <= eof2_q;
        end
    end

    // Stage 4: round/truncate to RGB888 and present the output sample.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_valid <= 1'b0;
            o_pixel <= 24'd0;
            o_sof <= 1'b0;
            o_eol <= 1'b0;
            o_eof <= 1'b0;
        end else if (ce) begin
            o_valid <= v3_q;
            o_pixel[23:16] <= mix_r_q[23:16];
            o_pixel[15:8]  <= mix_g_q[23:16];
            o_pixel[7:0]   <= mix_b_q[23:16];
            o_sof <= sof3_q;
            o_eol <= eol3_q;
            o_eof <= eof3_q;
        end
    end

endmodule
