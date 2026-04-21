`timescale 1ns / 1ps

module grayscale_stream_std #(
    parameter integer MAX_LANES = 8,
    parameter integer PIX_W_IN  = 24,
    parameter integer PIX_W_OUT = 8
) (
    input  wire                           clk,
    input  wire                           rst_n,
    input  wire                           s_valid,
    output wire                           s_ready,
    input  wire [MAX_LANES*PIX_W_IN-1:0]  s_data,
    input  wire [MAX_LANES-1:0]           s_keep,
    input  wire                           s_sof,
    input  wire                           s_eol,
    input  wire                           s_eof,
    output reg                            m_valid,
    input  wire                           m_ready,
    output reg  [MAX_LANES*PIX_W_OUT-1:0] m_data,
    output reg  [MAX_LANES-1:0]           m_keep,
    output reg                            m_sof,
    output reg                            m_eol,
    output reg                            m_eof
);

    integer lane_idx;

    function [7:0] rgb888_to_gray8;
        input [23:0] rgb;
        reg [15:0] weighted_sum;
        begin
            weighted_sum = (rgb[23:16] * 8'd77) +
                           (rgb[15:8]  * 8'd150) +
                           (rgb[7:0]   * 8'd29);
            rgb888_to_gray8 = weighted_sum[15:8];
        end
    endfunction

    assign s_ready = (~m_valid) | m_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= {MAX_LANES*PIX_W_OUT{1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else if (s_ready) begin
            m_valid <= s_valid;
            if (s_valid) begin
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    m_data[lane_idx*PIX_W_OUT +: PIX_W_OUT] <=
                        rgb888_to_gray8(s_data[lane_idx*PIX_W_IN +: PIX_W_IN]);
                end
                m_keep <= s_keep;
                m_sof  <= s_sof;
                m_eol  <= s_eol;
                m_eof  <= s_eof;
            end else begin
                m_data <= {MAX_LANES*PIX_W_OUT{1'b0}};
                m_keep <= {MAX_LANES{1'b0}};
                m_sof  <= 1'b0;
                m_eol  <= 1'b0;
                m_eof  <= 1'b0;
            end
        end
    end

endmodule
