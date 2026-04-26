`timescale 1ns/1ps

module ov5640_data (
    input  wire        sys_rst_n,
    input  wire        capture_enable,
    input  wire        ov5640_pclk,
    input  wire        ov5640_href,
    input  wire        ov5640_vsync,
    input  wire [7:0]  ov5640_data,
    output wire        ov5640_wr_en,
    output wire [15:0] ov5640_data_out
);

parameter PIC_WAIT = 4'd10;

wire pic_flag;
wire capture_start_w;

reg        ov5640_vsync_dly;
reg [3:0]  cnt_pic;
reg        pic_valid;
reg [7:0]  pic_data_reg;
reg [15:0] data_out_reg;
reg        data_flag;
reg        data_flag_dly1;
reg        capture_enable_dly;

assign capture_start_w = capture_enable & ~capture_enable_dly;
assign pic_flag = (~ov5640_vsync_dly) & ov5640_vsync;

always @(posedge ov5640_pclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        capture_enable_dly <= 1'b0;
    end else begin
        capture_enable_dly <= capture_enable;
    end
end

always @(posedge ov5640_pclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        ov5640_vsync_dly <= 1'b0;
    end else if (capture_start_w) begin
        ov5640_vsync_dly <= 1'b0;
    end else begin
        ov5640_vsync_dly <= ov5640_vsync;
    end
end

always @(posedge ov5640_pclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        cnt_pic <= 4'd0;
    end else if (capture_start_w) begin
        cnt_pic <= 4'd0;
    end else if (capture_enable && (cnt_pic < PIC_WAIT)) begin
        cnt_pic <= cnt_pic + 1'b1;
    end
end

always @(posedge ov5640_pclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        pic_valid <= 1'b0;
    end else if (capture_start_w) begin
        pic_valid <= 1'b0;
    end else if (capture_enable && (cnt_pic == PIC_WAIT) && pic_flag) begin
        pic_valid <= 1'b1;
    end
end

always @(posedge ov5640_pclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        data_out_reg <= 16'd0;
        pic_data_reg <= 8'd0;
        data_flag    <= 1'b0;
    end else if (capture_start_w) begin
        data_out_reg <= 16'd0;
        pic_data_reg <= 8'd0;
        data_flag    <= 1'b0;
    end else if (capture_enable && ov5640_href) begin
        data_flag    <= ~data_flag;
        pic_data_reg <= ov5640_data;
        if (data_flag) begin
            data_out_reg <= {pic_data_reg, ov5640_data};
        end
    end else if (capture_enable) begin
        data_flag    <= 1'b0;
        pic_data_reg <= 8'd0;
    end
end

always @(posedge ov5640_pclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        data_flag_dly1 <= 1'b0;
    end else if (capture_start_w) begin
        data_flag_dly1 <= 1'b0;
    end else begin
        data_flag_dly1 <= data_flag;
    end
end

assign ov5640_data_out = pic_valid ? data_out_reg : 16'd0;
assign ov5640_wr_en    = pic_valid ? data_flag_dly1 : 1'b0;

endmodule
