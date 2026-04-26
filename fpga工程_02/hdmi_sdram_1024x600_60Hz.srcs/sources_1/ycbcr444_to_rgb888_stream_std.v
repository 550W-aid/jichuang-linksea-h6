`timescale 1ns / 1ps

module ycbcr444_to_rgb888_stream_std #(
    parameter integer MAX_LANES = 8
) (
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        s_valid,
    output wire                        s_ready,
    input  wire [MAX_LANES*24-1:0]     s_data,
    input  wire [MAX_LANES-1:0]        s_keep,
    input  wire                        s_sof,
    input  wire                        s_eol,
    input  wire                        s_eof,
    output reg                         m_valid,
    input  wire                        m_ready,
    output reg  [MAX_LANES*24-1:0]     m_data,
    output reg  [MAX_LANES-1:0]        m_keep,
    output reg                         m_sof,
    output reg                         m_eol,
    output reg                         m_eof
);

    localparam integer TMP_W = 90;

    integer lane_idx;
    wire has_active_lane;
    wire stage1_ready;
    wire stage0_ready;

    reg                         stage0_valid;
    reg  [MAX_LANES*TMP_W-1:0]  stage0_data;
    reg  [MAX_LANES-1:0]        stage0_keep;
    reg                         stage0_sof;
    reg                         stage0_eol;
    reg                         stage0_eof;

    function [7:0] clamp_u8;
        input [31:0] value;
        begin
            if (value > 255) begin
                clamp_u8 = 8'hFF;
            end else begin
                clamp_u8 = value[7:0];
            end
        end
    endfunction

    function [TMP_W-1:0] ycbcr_to_rgb_stage0_lane;
        input [23:0] ycbcr;
        reg [17:0] y_mul_298;
        reg [17:0] cr_mul_408;
        reg [17:0] cb_mul_100;
        reg [17:0] cr_mul_208;
        reg [17:0] cb_mul_516;
        begin
            y_mul_298  = 18'd298 * ycbcr[23:16];
            cr_mul_408 = 18'd408 * ycbcr[7:0];
            cb_mul_100 = 18'd100 * ycbcr[15:8];
            cr_mul_208 = 18'd208 * ycbcr[7:0];
            cb_mul_516 = 18'd516 * ycbcr[15:8];
            ycbcr_to_rgb_stage0_lane = {
                y_mul_298,
                cr_mul_408,
                cb_mul_100,
                cr_mul_208,
                cb_mul_516
            };
        end
    endfunction

    function [23:0] ycbcr_to_rgb_stage1_lane;
        input [TMP_W-1:0] lane_tmp;
        reg [31:0] y_mul_298;
        reg [31:0] cr_mul_408;
        reg [31:0] cb_mul_100;
        reg [31:0] cr_mul_208;
        reg [31:0] cb_mul_516;
        reg [31:0] r_base;
        reg [31:0] g_base;
        reg [31:0] g_sub;
        reg [31:0] b_base;
        reg [31:0] r_tmp;
        reg [31:0] g_tmp;
        reg [31:0] b_tmp;
        begin
            y_mul_298  = lane_tmp[89:72];
            cr_mul_408 = lane_tmp[71:54];
            cb_mul_100 = lane_tmp[53:36];
            cr_mul_208 = lane_tmp[35:18];
            cb_mul_516 = lane_tmp[17:0];

            r_base = y_mul_298 + cr_mul_408;
            g_base = y_mul_298 + 32'd34816;
            g_sub  = cb_mul_100 + cr_mul_208;
            b_base = y_mul_298 + cb_mul_516;

            if (r_base <= 32'd57088) begin
                r_tmp = 32'd0;
            end else begin
                r_tmp = (r_base - 32'd57088) >> 8;
            end

            if (g_base <= g_sub) begin
                g_tmp = 32'd0;
            end else begin
                g_tmp = (g_base - g_sub) >> 8;
            end

            if (b_base <= 32'd70912) begin
                b_tmp = 32'd0;
            end else begin
                b_tmp = (b_base - 32'd70912) >> 8;
            end

            ycbcr_to_rgb_stage1_lane = {
                clamp_u8(r_tmp),
                clamp_u8(g_tmp),
                clamp_u8(b_tmp)
            };
        end
    endfunction

    assign has_active_lane = |s_keep;
    assign stage1_ready = (~m_valid) | m_ready;
    assign stage0_ready = (~stage0_valid) | stage1_ready;
    assign s_ready = stage0_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage0_valid <= 1'b0;
            stage0_data  <= {MAX_LANES*TMP_W{1'b0}};
            stage0_keep  <= {MAX_LANES{1'b0}};
            stage0_sof   <= 1'b0;
            stage0_eol   <= 1'b0;
            stage0_eof   <= 1'b0;
            m_valid      <= 1'b0;
            m_data       <= {MAX_LANES*24{1'b0}};
            m_keep       <= {MAX_LANES{1'b0}};
            m_sof        <= 1'b0;
            m_eol        <= 1'b0;
            m_eof        <= 1'b0;
        end else begin
            if (stage1_ready) begin
                m_valid <= stage0_valid;
                if (stage0_valid) begin
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (stage0_keep[lane_idx]) begin
                            m_data[lane_idx*24 +: 24] <= ycbcr_to_rgb_stage1_lane(stage0_data[lane_idx*TMP_W +: TMP_W]);
                        end else begin
                            m_data[lane_idx*24 +: 24] <= 24'd0;
                        end
                    end
                    m_keep <= stage0_keep;
                    m_sof  <= stage0_sof;
                    m_eol  <= stage0_eol;
                    m_eof  <= stage0_eof;
                end else begin
                    m_data <= {MAX_LANES*24{1'b0}};
                    m_keep <= {MAX_LANES{1'b0}};
                    m_sof  <= 1'b0;
                    m_eol  <= 1'b0;
                    m_eof  <= 1'b0;
                end
            end

            if (stage0_ready) begin
                stage0_valid <= s_valid && has_active_lane;
                if (s_valid && has_active_lane) begin
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (s_keep[lane_idx]) begin
                            stage0_data[lane_idx*TMP_W +: TMP_W] <= ycbcr_to_rgb_stage0_lane(s_data[lane_idx*24 +: 24]);
                        end else begin
                            stage0_data[lane_idx*TMP_W +: TMP_W] <= {TMP_W{1'b0}};
                        end
                    end
                    stage0_keep <= s_keep;
                    stage0_sof  <= s_sof;
                    stage0_eol  <= s_eol;
                    stage0_eof  <= s_eof;
                end else begin
                    stage0_data <= {MAX_LANES*TMP_W{1'b0}};
                    stage0_keep <= {MAX_LANES{1'b0}};
                    stage0_sof  <= 1'b0;
                    stage0_eol  <= 1'b0;
                    stage0_eof  <= 1'b0;
                end
            end
        end
    end

endmodule
