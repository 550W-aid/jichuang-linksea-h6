`timescale 1ns / 1ps

module histogram_equalizer_stream_std #(
    parameter integer MAX_LANES = 8
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     s_valid,
    output wire                     s_ready,
    input  wire [MAX_LANES*8-1:0]   s_data,
    input  wire [MAX_LANES-1:0]     s_keep,
    input  wire                     s_sof,
    input  wire                     s_eol,
    input  wire                     s_eof,
    input  wire [MAX_LANES*8-1:0]   s_map_data,
    output reg                      m_valid,
    input  wire                     m_ready,
    output reg  [MAX_LANES*8-1:0]   m_data,
    output reg  [MAX_LANES-1:0]     m_keep,
    output reg                      m_sof,
    output reg                      m_eol,
    output reg                      m_eof
);

    integer lane_idx;
    wire pipe_advance;
    wire has_active_lane;

    assign pipe_advance  = (~m_valid) | m_ready;
    assign has_active_lane = |s_keep;
    assign s_ready = pipe_advance;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= {MAX_LANES*8{1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else if (pipe_advance) begin
            m_valid <= s_valid && has_active_lane;
            if (s_valid && has_active_lane) begin
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    if (s_keep[lane_idx]) begin
                        m_data[lane_idx*8 +: 8] <= s_map_data[lane_idx*8 +: 8];
                    end else begin
                        m_data[lane_idx*8 +: 8] <= 8'd0;
                    end
                end
                m_keep <= s_keep;
                m_sof  <= s_sof;
                m_eol  <= s_eol;
                m_eof  <= s_eof;
            end else begin
                m_data <= {MAX_LANES*8{1'b0}};
                m_keep <= {MAX_LANES{1'b0}};
                m_sof  <= 1'b0;
                m_eol  <= 1'b0;
                m_eof  <= 1'b0;
            end
        end
    end

endmodule
