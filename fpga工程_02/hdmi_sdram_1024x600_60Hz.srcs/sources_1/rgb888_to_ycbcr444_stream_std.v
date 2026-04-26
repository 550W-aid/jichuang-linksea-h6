`timescale 1ns / 1ps

module rgb888_to_ycbcr444_stream_std #(
    parameter integer MAX_LANES = 8
) (
    input  wire                        clk,             
    input  wire                        rst_n,
    input  wire                        s_valid,      //本次数据有效
    output wire                        s_ready,      //上游可以发送数据
    input  wire [MAX_LANES*24-1:0]     s_data,      //输入数据，每24位一个像素，格式为{R,G,B}，R在高位  
    input  wire [MAX_LANES-1:0]        s_keep,      //输入数据有效字节指示，每位对应一个像素，1表示对应像素数据有效，0表示无效
    input  wire                        s_sof,       //输入数据帧开始信号，表示当前数据是新一帧的第一个像素
    input  wire                        s_eol,       //输入数据行结束信号，表示当前数据是所在行的最后一个像素
    input  wire                        s_eof,       //输入数据帧结束信号，表示当前数据是所在帧的最后一个像素
    output reg                         m_valid,     //输出数据有效，表示当前输出数据有效
    input  wire                        m_ready,     //下游可以接受数据
    output reg  [MAX_LANES*24-1:0]     m_data,      //输出数据，每24位一个像素，格式为{Y,Cb,Cr}，Y在高位
    output reg  [MAX_LANES-1:0]        m_keep,      //输出数据有效字节指示，每位对应一个像素，1表示对应像素数据有效，0表示无效
    output reg                         m_sof,       //输出数据帧开始信号，表示当前数据是新一帧的第一个像素
    output reg                         m_eol,       //输出数据行结束信号，表示当前数据是所在行的最后一个像素
    output reg                         m_eof        //输出数据帧结束信号，表示当前数据是所在帧的最后一个像素
);

    localparam integer TMP_W = 144;                   

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

    function [TMP_W-1:0] rgb_to_ycbcr_stage0_lane;   //流水线零级操作
        input [23:0] rgb;
        reg [15:0] y_r_mul;
        reg [15:0] y_g_mul;
        reg [15:0] y_b_mul;
        reg [15:0] cb_b_mul;
        reg [15:0] cb_r_mul;
        reg [15:0] cb_g_mul;
        reg [15:0] cr_r_mul;
        reg [15:0] cr_g_mul;
        reg [15:0] cr_b_mul;
        begin
            y_r_mul  = 16'd66  * rgb[23:16];
            y_g_mul  = 16'd129 * rgb[15:8];
            y_b_mul  = 16'd25  * rgb[7:0];
            cb_b_mul = 16'd112 * rgb[7:0];
            cb_r_mul = 16'd38  * rgb[23:16];
            cb_g_mul = 16'd74  * rgb[15:8];
            cr_r_mul = 16'd112 * rgb[23:16];
            cr_g_mul = 16'd94  * rgb[15:8];
            cr_b_mul = 16'd18  * rgb[7:0];
            rgb_to_ycbcr_stage0_lane = {
                y_r_mul,
                y_g_mul,
                y_b_mul,
                cb_b_mul,
                cb_r_mul,
                cb_g_mul,
                cr_r_mul,
                cr_g_mul,
                cr_b_mul
            };
        end
    endfunction

    function [23:0] rgb_to_ycbcr_stage1_lane;       //流水线一级操作
        input [TMP_W-1:0] lane_tmp;
        reg [31:0] y_r_mul;
        reg [31:0] y_g_mul;
        reg [31:0] y_b_mul;
        reg [31:0] cb_b_mul;
        reg [31:0] cb_r_mul;
        reg [31:0] cb_g_mul;
        reg [31:0] cr_r_mul;
        reg [31:0] cr_g_mul;
        reg [31:0] cr_b_mul;
        reg [31:0] y_tmp;
        reg [31:0] cb_pos;
        reg [31:0] cb_neg;
        reg [31:0] cb_tmp;
        reg [31:0] cr_pos;
        reg [31:0] cr_neg;
        reg [31:0] cr_tmp;
        begin
            y_r_mul  = lane_tmp[143:128];
            y_g_mul  = lane_tmp[127:112];
            y_b_mul  = lane_tmp[111:96];
            cb_b_mul = lane_tmp[95:80];
            cb_r_mul = lane_tmp[79:64];
            cb_g_mul = lane_tmp[63:48];
            cr_r_mul = lane_tmp[47:32];
            cr_g_mul = lane_tmp[31:16];
            cr_b_mul = lane_tmp[15:0];

            y_tmp  = 32'd4096 + y_r_mul + y_g_mul + y_b_mul;
            cb_pos = 32'd32768 + cb_b_mul;
            cb_neg = cb_r_mul + cb_g_mul;
            cb_tmp = cb_pos - cb_neg;
            cr_pos = 32'd32768 + cr_r_mul;
            cr_neg = cr_g_mul + cr_b_mul;
            cr_tmp = cr_pos - cr_neg;

            rgb_to_ycbcr_stage1_lane = {
                clamp_u8(y_tmp >> 8),
                clamp_u8(cb_tmp >> 8),
                clamp_u8(cr_tmp >> 8)
            };
        end
    endfunction

    assign has_active_lane = |s_keep;                           //判断当前输入数据中是否有有效像素
    assign stage1_ready = (~m_valid) | m_ready;                 //判断流水线一级是否准备好接受数据(如果当前输出数据无效或者下游准备好接受数据，则流水线一级准备好)
    assign stage0_ready = (~stage0_valid) | stage1_ready;       //判断流水线零级是否准备好接受数据(如果当前零级数据无效或者一级准备好接受数据，则零级准备好)
    assign s_ready = stage0_ready;                              //上游可以发送数据的条件是流水线零级准备好接受数据

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
                            m_data[lane_idx*24 +: 24] <= rgb_to_ycbcr_stage1_lane(stage0_data[lane_idx*TMP_W +: TMP_W]);        //如果当前像素有效，则进行流水线一级操作得到最终的YCBCR值
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

            if (stage0_ready) begin                                                                                             //当流水线零级准备好接受数据时，如果当前输入数据有效且有至少一个有效像素，则进行流水线零级操作得到中间结果
                stage0_valid <= s_valid && has_active_lane;
                if (s_valid && has_active_lane) begin
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (s_keep[lane_idx]) begin
                            stage0_data[lane_idx*TMP_W +: TMP_W] <= rgb_to_ycbcr_stage0_lane(s_data[lane_idx*24 +: 24]);
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
