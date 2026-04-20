`timescale 1ns / 1ps

// 将 RGB888 流式拍数据转换为 Gray8 流式拍数据。
// 算法采用常见近似公式：
// Y = (77 * R + 150 * G + 29 * B) >> 8
// 其中 77/256≈0.3008，150/256≈0.5859，29/256≈0.1133，
// 与常见的 0.299/0.587/0.114 非常接近，适合 FPGA 用移位加法实现。
module grayscale_stream_std #(
    parameter integer MAX_LANES = 1,
    parameter integer PIX_W_IN  = 24,
    parameter integer PIX_W_OUT = 8
) (
    // 时钟与复位。
    input  wire                           clk,     // 处理时钟。
    input  wire                           rst_n,   // 低有效异步复位。

    // 上游标准流接口输入。
    input  wire                           s_valid, // 当前拍上游数据有效。
    output wire                           s_ready, // 当前拍本模块可接收输入。
    input  wire [MAX_LANES*PIX_W_IN-1:0]  s_data,  // RGB888 输入数据，lane0 放在最低位。
    input  wire [MAX_LANES-1:0]           s_keep,  // s_data 对应的每路有效掩码。
    input  wire                           s_sof,   // 一帧中第一个有效像素。
    input  wire                           s_eol,   // 当前行最后一个有效像素。
    input  wire                           s_eof,   // 当前帧最后一个有效像素。

    // 下游标准流接口输出。
    output reg                            m_valid, // 当前拍灰度输出有效。
    input  wire                           m_ready, // 下游当前拍可以接收输出。
    output reg  [MAX_LANES*PIX_W_OUT-1:0] m_data,  // Gray8 输出数据，lane0 放在最低位。
    output reg  [MAX_LANES-1:0]           m_keep,  // m_data 对应的每路有效掩码。
    output reg                            m_sof,   // 一帧中第一个有效输出像素。
    output reg                            m_eol,   // 当前行最后一个有效输出像素。
    output reg                            m_eof    // 当前帧最后一个有效输出像素。
);

    integer lane_idx;
    wire has_active_lane;

    // 单像素灰度变换函数。
    // 这里只处理一个 RGB888 像素，外层 for 循环负责把多个 lane 并行展开。
    function [7:0] rgb888_to_gray8;
        input [23:0] rgb;
        reg [15:0] weighted_sum;
        reg [15:0] r_ext;
        reg [15:0] g_ext;
        reg [15:0] b_ext;
        begin
            r_ext = {8'b0, rgb[23:16]};
            g_ext = {8'b0, rgb[15:8]};
            b_ext = {8'b0, rgb[7:0]};

            // 用移位加法代替乘法：
            // 77  = 64 + 8 + 4 + 1
            // 150 = 128 + 16 + 4 + 2
            // 29  = 16 + 8 + 4 + 1
            weighted_sum = (r_ext << 6) + (r_ext << 3) + (r_ext << 2) + r_ext +
                           (g_ext << 7) + (g_ext << 4) + (g_ext << 2) + (g_ext << 1) +
                           (b_ext << 4) + (b_ext << 3) + (b_ext << 2) + b_ext;
            // 前面的系数都按 256 倍展开了，这里直接取高 8 位，相当于整体再右移 8 位。
            rgb888_to_gray8 = weighted_sum[15:8];
        end
    endfunction

    // 只要本拍至少有一路 lane 有效，就认为这拍值得进入流水。
    assign has_active_lane = |s_keep;
    // 标准 ready/valid 回压关系：
    // 当前输出寄存器为空，或者下游本拍愿意接收，才能继续吃上游输入。
    assign s_ready = (~m_valid) | m_ready;

    // 输出寄存器：
    // 1. 当 s_ready=1 时，说明本模块这一拍允许推进。
    // 2. 若 s_valid 且至少一路 s_keep 有效，就把当前拍 RGB 转成 Gray8 后送到输出寄存器。
    // 3. 元数据 s_keep/s_sof/s_eol/s_eof 与像素数据严格同拍对齐传递给下游。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= {MAX_LANES*PIX_W_OUT{1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else if (s_ready) begin
            m_valid <= s_valid && has_active_lane;
            if (s_valid && has_active_lane) begin
                // 多 lane 并行展开：每一路各自独立做一次 RGB->Gray。
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    if (s_keep[lane_idx]) begin
                        m_data[lane_idx*PIX_W_OUT +: PIX_W_OUT] <=
                            rgb888_to_gray8(s_data[lane_idx*PIX_W_IN +: PIX_W_IN]);
                    end else begin
                        // 被 s_keep 屏蔽的 lane 明确清零，避免无效位传播成脏数据。
                        m_data[lane_idx*PIX_W_OUT +: PIX_W_OUT] <= {PIX_W_OUT{1'b0}};
                    end
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
