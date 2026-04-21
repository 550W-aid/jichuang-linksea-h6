`timescale 1ns / 1ps

// 使用固定阈值将灰度拍数据转换为二值拍数据。
module binary_threshold_stream_std #(
    parameter integer MAX_LANES = 1,
    parameter integer DATA_W    = 8,
    parameter [DATA_W-1:0] THRESHOLD = 8'd128
) (
    // 时钟与复位。
    input  wire                        clk,     // 处理时钟。
    input  wire                        rst_n,   // 低有效异步复位。

    // 上游标准流接口输入。
    input  wire                        s_valid, // 当前拍上游数据有效。
    output wire                        s_ready, // 当前拍本模块可接收输入。
    input  wire [MAX_LANES*DATA_W-1:0] s_data,  // 灰度输入数据，lane0 放在最低位。
    input  wire [MAX_LANES-1:0]        s_keep,  // s_data 对应的每路有效掩码。
    input  wire                        s_sof,   // 一帧中第一个有效输入像素。
    input  wire                        s_eol,   // 当前行最后一个有效输入像素。
    input  wire                        s_eof,   // 当前帧最后一个有效输入像素。

    // 下游标准流接口输出。
    output reg                         m_valid, // 当前拍二值输出有效。
    input  wire                        m_ready, // 下游当前拍可以接收输出。
    output reg  [MAX_LANES*DATA_W-1:0] m_data,  // 二值输出数据，lane0 放在最低位。
    output reg  [MAX_LANES-1:0]        m_keep,  // m_data 对应的每路有效掩码。
    output reg                         m_sof,   // 一帧中第一个有效输出像素。
    output reg                         m_eol,   // 当前行最后一个有效输出像素。
    output reg                         m_eof    // 当前帧最后一个有效输出像素。
);

    integer lane_idx;
    wire has_active_lane;

    assign has_active_lane = |s_keep;
    assign s_ready = (~m_valid) | m_ready;

    // 输出寄存器：仅在下游允许接收时锁存一拍阈值化结果。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= {MAX_LANES*DATA_W{1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else if (s_ready) begin
            m_valid <= s_valid && has_active_lane;
            if (s_valid && has_active_lane) begin
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    if (s_keep[lane_idx]) begin
                        m_data[lane_idx*DATA_W +: DATA_W] <=
                            (s_data[lane_idx*DATA_W +: DATA_W] >= THRESHOLD) ? {DATA_W{1'b1}} : {DATA_W{1'b0}};
                    end else begin
                        m_data[lane_idx*DATA_W +: DATA_W] <= {DATA_W{1'b0}};
                    end
                end
                m_keep <= s_keep;
                m_sof  <= s_sof;
                m_eol  <= s_eol;
                m_eof  <= s_eof;
            end else begin
                m_data <= {MAX_LANES*DATA_W{1'b0}};
                m_keep <= {MAX_LANES{1'b0}};
                m_sof  <= 1'b0;
                m_eol  <= 1'b0;
                m_eof  <= 1'b0;
            end
        end
    end

endmodule
