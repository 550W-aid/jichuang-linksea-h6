`timescale 1ns / 1ps

// 对每个有效灰度窗口拍执行 Sobel 边缘强度计算。
// 使用的两个 3x3 梯度核为：
// Gx = [-1  0  1; -2  0  2; -1  0  1]
// Gy = [ 1  2  1;  0  0  0; -1 -2 -1]
// 这里输出的是 |Gx| + |Gy| 的近似幅值，并对结果做饱和裁剪。
module sobel3x3_stream_std #(
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
    output reg                             m_valid, // 当前拍边缘输出有效。
    input  wire                            m_ready, // 下游当前拍可以接收输出。
    output reg  [MAX_LANES*DATA_W-1:0]     m_data,  // Sobel 强度输出数据，lane0 放在最低位。
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

    // 单窗口 Sobel 计算函数。
    // 先计算水平梯度 Gx 和垂直梯度 Gy，再输出 |Gx|+|Gy|。
    function [DATA_W-1:0] sobel9;
        input [DATA_W*9-1:0] window;
        integer p0;
        integer p1;
        integer p2;
        integer p3;
        integer p4;
        integer p5;
        integer p6;
        integer p7;
        integer p8;
        integer gx;
        integer gy;
        integer magnitude;
        integer max_value;
        begin
            p0 = tap9(window, 0);
            p1 = tap9(window, 1);
            p2 = tap9(window, 2);
            p3 = tap9(window, 3);
            p4 = tap9(window, 4);
            p5 = tap9(window, 5);
            p6 = tap9(window, 6);
            p7 = tap9(window, 7);
            p8 = tap9(window, 8);

            // 水平边缘更强时，|Gx| 会更大。
            gx = -p0 + p2 - (p3 * 2) + (p5 * 2) - p6 + p8;
            // 垂直边缘更强时，|Gy| 会更大。
            gy =  p0 + (p1 * 2) + p2 - p6 - (p7 * 2) - p8;
            if (gx < 0) begin
                gx = -gx;
            end
            if (gy < 0) begin
                gy = -gy;
            end

            magnitude = gx + gy;
            max_value = (1 << DATA_W) - 1;
            if (magnitude > max_value) begin
                // 梯度和超过输出位宽时直接截到全 1，避免回卷。
                sobel9 = {DATA_W{1'b1}};
            end else begin
                sobel9 = magnitude[DATA_W-1:0];
            end
        end
    endfunction

    // 至少有一路 lane 有效，本拍才进入真实计算。
    assign has_active_lane = |s_keep;
    // 标准 ready/valid 回压。
    assign s_ready = (~m_valid) | m_ready;

    // 输出寄存器：
    // 对每一路有效窗口独立计算 Sobel 幅值，元数据同步传递。
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
                        // 每一路 lane 各自对自己的 3x3 窗口做 Sobel 计算。
                        m_data[lane_idx*DATA_W +: DATA_W] <=
                            sobel9(s_data[lane_idx*DATA_W*9 +: DATA_W*9]);
                    end else begin
                        // 无效 lane 直接清零。
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
