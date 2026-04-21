`timescale 1ns / 1ps

// 对每个有效灰度窗口拍执行固定系数 3x3 高斯平滑。
// 核系数为：
// 1 2 1
// 2 4 2
// 1 2 1
// 最终结果再整体除以 16，因此非常适合 FPGA 用移位加法实现。
module gaussian3x3_stream_std #(
    parameter integer MAX_LANES = 1,
    parameter integer DATA_W    = 8
) (
    // 时钟与复位。
    input  wire                            clk,     // 处理时钟。
    input  wire                            rst_n,   // 低有效异步复位。

    // 上游标准流接口输入。
    input  wire                            s_valid, // 当前拍上游数据有效。
    output wire                            s_ready, // 当前拍本模块可接收输入。
    input  wire [MAX_LANES*DATA_W*9-1:0]   s_data,  // 3x3 输入窗口数据，lane0 放在最低位。
    input  wire [MAX_LANES-1:0]            s_keep,  // s_data 对应的每路有效掩码。
    input  wire                            s_sof,   // 一帧中第一个有效输入像素。
    input  wire                            s_eol,   // 当前行最后一个有效输入像素。
    input  wire                            s_eof,   // 当前帧最后一个有效输入像素。

    // 下游标准流接口输出。
    output reg                             m_valid, // 当前拍滤波输出有效。
    input  wire                            m_ready, // 下游当前拍可以接收输出。
    output reg  [MAX_LANES*DATA_W-1:0]     m_data,  // 高斯平滑后的像素数据，lane0 放在最低位。
    output reg  [MAX_LANES-1:0]            m_keep,  // m_data 对应的每路有效掩码。
    output reg                             m_sof,   // 一帧中第一个有效输出像素。
    output reg                             m_eol,   // 当前行最后一个有效输出像素。
    output reg                             m_eof    // 当前帧最后一个有效输出像素。
);

    integer lane_idx;
    wire has_active_lane;

    // 读取 3x3 窗口中的第 tap_idx 个像素。
    // tap_idx=0 对应左上角，tap_idx=8 对应右下角。
    function [DATA_W-1:0] tap9;
        input [DATA_W*9-1:0] window;
        input integer tap_idx;
        begin
            tap9 = window[(8-tap_idx)*DATA_W +: DATA_W];
        end
    endfunction

    // 单窗口高斯平滑函数。
    // 先按核系数做加权求和，再整体右移 4 位，相当于除以 16。
    function [DATA_W-1:0] gaussian9;
        input [DATA_W*9-1:0] window;
        reg [DATA_W+3:0] weighted_sum;
        begin
            weighted_sum =
                tap9(window, 0) + (tap9(window, 1) << 1) + tap9(window, 2) +
                (tap9(window, 3) << 1) + (tap9(window, 4) << 2) + (tap9(window, 5) << 1) +
                tap9(window, 6) + (tap9(window, 7) << 1) + tap9(window, 8);
            gaussian9 = weighted_sum[DATA_W+3:4];
        end
    endfunction

    // 至少有一路 lane 有效，本拍才需要真正参与计算。
    assign has_active_lane = |s_keep;
    // 下游不阻塞时，本拍输入才允许推进到输出寄存器。
    assign s_ready = (~m_valid) | m_ready;

    // 输出寄存器：
    // 把当前拍每个有效 lane 的 3x3 窗口分别做一次高斯平滑，
    // 并把 keep/sof/eol/eof 元数据同步带到下游。
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
                        // 每一路 lane 完全独立，窗口内 9 个点各自进入高斯加权求和。
                        m_data[lane_idx*DATA_W +: DATA_W] <=
                            gaussian9(s_data[lane_idx*DATA_W*9 +: DATA_W*9]);
                    end else begin
                        // 对无效 lane 明确输出 0，避免下游误取无定义值。
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
