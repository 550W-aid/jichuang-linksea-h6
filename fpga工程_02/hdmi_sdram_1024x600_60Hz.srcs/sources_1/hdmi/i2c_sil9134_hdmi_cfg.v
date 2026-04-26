// -----------------------------------------------------------------------------
// Copyright (c) 2024-2025 All rights reserved
// -----------------------------------------------------------------------------
// Author : 1224024832@njupt.edu.cn
// Wechat : secret
// File   : i2c_sil9134_hdmi_cfg.v
// Create : 2025-03-27 10:50:28
// Revise : 2026-04-23
// Editor : sublime text3, tab size (4)
// -----------------------------------------------------------------------------
`timescale  1ns/1ps

module i2c_sil9134_hdmi_cfg(
    input  wire             clk      ,
    input  wire             rst_n    ,
    input  wire             i2c_done ,

    output reg              i2c_exec ,
    output reg  [23:0]      i2c_data ,
    output reg              i2c_rh_wl,
    output reg              init_done
);

localparam REG_NUM      = 3'd4;
localparam CNT_WAIT_MAX = 10'd1023;

reg [9:0] start_init_cnt;
reg [2:0] init_reg_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        start_init_cnt <= 10'd0;
    else if (start_init_cnt < CNT_WAIT_MAX)
        start_init_cnt <= start_init_cnt + 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        init_reg_cnt <= 3'd0;
    else if (i2c_exec)
        init_reg_cnt <= init_reg_cnt + 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        i2c_exec <= 1'b0;
    else if (start_init_cnt == (CNT_WAIT_MAX - 1))
        i2c_exec <= 1'b1;
    else if (i2c_done && (init_reg_cnt < REG_NUM))
        i2c_exec <= 1'b1;
    else
        i2c_exec <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        i2c_rh_wl <= 1'b0;
    else begin
        i2c_rh_wl <= 1'b0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        init_done <= 1'b0;
    else if ((init_reg_cnt == REG_NUM) && i2c_done)
        init_done <= 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        i2c_data <= 24'b0;
    else begin
        case (init_reg_cnt)
            3'd0  : i2c_data <= {8'h76, 8'h08, 8'h35};
            3'd1  : i2c_data <= {8'h76, 8'h49, 8'h00};
            3'd2  : i2c_data <= {8'h76, 8'h4A, 8'h00};
            3'd3  : i2c_data <= {8'h7E, 8'h2F, 8'h00};
            default: i2c_data <= {8'h76, 8'h08, 8'h35};
        endcase
    end
end

endmodule
