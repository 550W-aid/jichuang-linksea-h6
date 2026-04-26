`timescale 1ns/1ps
module ov5640_top(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        sys_init_done,
    input  wire        ov5640_pclk,
    input  wire        ov5640_href,
    input  wire        ov5640_vsync,
    input  wire [7:0]  ov5640_data,
    output wire        cfg_done,
    output wire        sccb_scl,
    inout  wire        sccb_sda,
    output wire        ov5640_wr_en,
    output wire [15:0] ov5640_data_out,
    output wire [15:0] dbg_rd_addr_o,
    output wire [7:0]  dbg_rd_data_o,
    output wire        dbg_rd_ack_o,
    output wire        dbg_rd_busy_o,
    output wire        dbg_rd_done_o,
    output wire        dbg_rd_timeout_o,
    output wire [2:0]  dbg_rd_state_o,
    output wire [3:0]  dbg_rd_index_o
);

parameter SLAVE_ADDR = 7'h3C;
parameter BIT_CTRL   = 1'b1;
parameter CLK_FREQ   = 26'd50_000_000;
parameter I2C_FREQ   = 18'd250_000;

localparam [2:0] DBG_IDLE        = 3'd0;
localparam [2:0] DBG_START       = 3'd1;
localparam [2:0] DBG_WAIT        = 3'd2;
localparam [11:0] DBG_GAP_MAX    = 12'd1024;
localparam [11:0] DBG_TIMEOUT_MAX= 12'd4095;

wire        cfg_end;
wire        cfg_end_w;
wire        cfg_start;
wire [23:0] cfg_data;
wire        cfg_clk;
wire        i2c_start_w;
wire [15:0] i2c_addr_w;
wire [7:0]  i2c_wr_data_w;
wire [7:0]  i2c_rd_data_w;
wire        i2c_rd_en_w;
wire        i2c_wr_en_w;
wire        i2c_end_w;

reg         dbg_start_r;
reg         dbg_ack_r;
reg         dbg_busy_r;
reg         dbg_done_r;
reg         dbg_timeout_r;
reg         sys_init_done_meta_pclk_r;
reg         sys_init_done_sync_pclk_r;
reg [2:0]   dbg_state_r;
reg [3:0]   dbg_index_r;
reg [15:0]  dbg_addr_r;
reg [7:0]   dbg_data_r;
reg [11:0]  dbg_gap_cnt_r;
reg [11:0]  dbg_timeout_cnt_r;

function [15:0] dbg_reg_addr;
    input [3:0] index;
    begin
        case (index)
            4'd0: dbg_reg_addr = 16'h3807;
            4'd1: dbg_reg_addr = 16'h3808;
            4'd2: dbg_reg_addr = 16'h3809;
            4'd3: dbg_reg_addr = 16'h380a;
            4'd4: dbg_reg_addr = 16'h380b;
            4'd5: dbg_reg_addr = 16'h3820;
            4'd6: dbg_reg_addr = 16'h3821;
            default: dbg_reg_addr = 16'h3036;
        endcase
    end
endfunction

assign i2c_wr_en_w   = ~cfg_done;
assign i2c_rd_en_w   = cfg_done;
assign i2c_start_w   = cfg_done ? dbg_start_r : cfg_start;
assign i2c_addr_w    = cfg_done ? dbg_addr_r  : cfg_data[23:8];
assign i2c_wr_data_w = cfg_done ? 8'h00       : cfg_data[7:0];
assign cfg_end_w     = i2c_end_w & ~cfg_done;

assign dbg_rd_addr_o    = dbg_addr_r;
assign dbg_rd_data_o    = dbg_data_r;
assign dbg_rd_ack_o     = dbg_ack_r;
assign dbg_rd_busy_o    = dbg_busy_r;
assign dbg_rd_done_o    = dbg_done_r;
assign dbg_rd_timeout_o = dbg_timeout_r;
assign dbg_rd_state_o   = dbg_state_r;
assign dbg_rd_index_o   = dbg_index_r;

always @(posedge ov5640_pclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        sys_init_done_meta_pclk_r <= 1'b0;
        sys_init_done_sync_pclk_r <= 1'b0;
    end else begin
        sys_init_done_meta_pclk_r <= sys_init_done;
        sys_init_done_sync_pclk_r <= sys_init_done_meta_pclk_r;
    end
end

always @(posedge cfg_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        dbg_start_r       <= 1'b0;
        dbg_ack_r         <= 1'b0;
        dbg_busy_r        <= 1'b0;
        dbg_done_r        <= 1'b0;
        dbg_timeout_r     <= 1'b0;
        dbg_state_r       <= DBG_IDLE;
        dbg_index_r       <= 4'd0;
        dbg_addr_r        <= 16'h3807;
        dbg_data_r        <= 8'h00;
        dbg_gap_cnt_r     <= 12'd0;
        dbg_timeout_cnt_r <= 12'd0;
    end else begin
        dbg_start_r   <= 1'b0;
        dbg_done_r    <= 1'b0;
        dbg_timeout_r <= 1'b0;

        if (!cfg_done) begin
            dbg_ack_r         <= 1'b0;
            dbg_busy_r        <= 1'b0;
            dbg_state_r       <= DBG_IDLE;
            dbg_index_r       <= 4'd0;
            dbg_addr_r        <= 16'h3807;
            dbg_data_r        <= 8'h00;
            dbg_gap_cnt_r     <= 12'd0;
            dbg_timeout_cnt_r <= 12'd0;
        end else begin
            case (dbg_state_r)
                DBG_IDLE: begin
                    dbg_busy_r <= 1'b0;
                    if (dbg_gap_cnt_r == DBG_GAP_MAX) begin
                        dbg_addr_r        <= dbg_reg_addr(dbg_index_r);
                        dbg_start_r       <= 1'b1;
                        dbg_busy_r        <= 1'b1;
                        dbg_state_r       <= DBG_START;
                        dbg_timeout_cnt_r <= 12'd0;
                        dbg_gap_cnt_r     <= 12'd0;
                    end else begin
                        dbg_gap_cnt_r <= dbg_gap_cnt_r + 12'd1;
                    end
                end
                DBG_START: begin
                    dbg_state_r <= DBG_WAIT;
                end
                DBG_WAIT: begin
                    dbg_busy_r <= 1'b1;
                    if (i2c_end_w) begin
                        dbg_data_r        <= i2c_rd_data_w;
                        dbg_ack_r         <= 1'b1;
                        dbg_done_r        <= 1'b1;
                        dbg_busy_r        <= 1'b0;
                        dbg_state_r       <= DBG_IDLE;
                        dbg_timeout_cnt_r <= 12'd0;
                        dbg_index_r       <= (dbg_index_r == 4'd7) ? 4'd0 : (dbg_index_r + 4'd1);
                    end else if (dbg_timeout_cnt_r == DBG_TIMEOUT_MAX) begin
                        dbg_ack_r         <= 1'b0;
                        dbg_timeout_r     <= 1'b1;
                        dbg_busy_r        <= 1'b0;
                        dbg_state_r       <= DBG_IDLE;
                        dbg_timeout_cnt_r <= 12'd0;
                        dbg_index_r       <= (dbg_index_r == 4'd7) ? 4'd0 : (dbg_index_r + 4'd1);
                    end else begin
                        dbg_timeout_cnt_r <= dbg_timeout_cnt_r + 12'd1;
                    end
                end
                default: begin
                    dbg_state_r <= DBG_IDLE;
                end
            endcase
        end
    end
end

i2c_ctrl #(
    .DEVICE_ADDR  (SLAVE_ADDR),
    .SYS_CLK_FREQ (CLK_FREQ),
    .SCL_FREQ     (I2C_FREQ)
) i2c_ctrl_inst (
    .sys_clk   (sys_clk),
    .sys_rst_n (sys_rst_n),
    .wr_en     (i2c_wr_en_w),
    .rd_en     (i2c_rd_en_w),
    .i2c_start (i2c_start_w),
    .addr_num  (BIT_CTRL),
    .byte_addr (i2c_addr_w),
    .wr_data   (i2c_wr_data_w),
    .i2c_clk   (cfg_clk),
    .i2c_end   (i2c_end_w),
    .rd_data   (i2c_rd_data_w),
    .i2c_scl   (sccb_scl),
    .i2c_sda   (sccb_sda)
);

ov5640_cfg ov5640_cfg_inst(
    .sys_clk   (cfg_clk),
    .sys_rst_n (sys_rst_n),
    .cfg_end   (cfg_end_w),
    .cfg_start (cfg_start),
    .cfg_data  (cfg_data),
    .cfg_done  (cfg_done)
);

ov5640_data ov5640_data_inst(
    .sys_rst_n       (sys_rst_n),
    .capture_enable  (sys_init_done_sync_pclk_r),
    .ov5640_pclk     (ov5640_pclk),
    .ov5640_href     (ov5640_href),
    .ov5640_vsync    (ov5640_vsync),
    .ov5640_data     (ov5640_data),
    .ov5640_wr_en    (ov5640_wr_en),
    .ov5640_data_out (ov5640_data_out)
);

endmodule
