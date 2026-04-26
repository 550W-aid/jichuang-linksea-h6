`timescale 1 ns / 1 ps

module fifo_ctrl
(
    input   wire            sys_clk,
    input   wire            sys_rst_n,
    input   wire            wr_fifo_wr_clk,
    input   wire            wr_fifo_wr_req,
    input   wire    [15:0]  wr_fifo_wr_data,
    input   wire    [23:0]  sdram_wr_b_addr,
    input   wire    [23:0]  sdram_wr_e_addr,
    input   wire    [9:0]   wr_burst_len,
    input   wire            wr_rst,
    input   wire            rd_fifo_rd_clk,
    input   wire            rd_fifo_rd_req,
    input   wire    [23:0]  sdram_rd_b_addr,
    input   wire    [23:0]  sdram_rd_e_addr,
    input   wire    [9:0]   rd_burst_len,
    input   wire            rd_rst,
    output  wire    [15:0]  rd_fifo_rd_data,
    output  wire    [9:0]   rd_fifo_num,
    input   wire            read_valid,
    input   wire            rd_flip_v,
    input   wire            init_end,
    input   wire            pingpang_en,
    input   wire            sdram_wr_ack,
    output  reg             sdram_wr_req,
    output  reg     [23:0]  sdram_wr_addr,
    output  wire    [15:0]  sdram_data_in,
    input   wire            sdram_rd_ack,
    input   wire    [15:0]  sdram_data_out,
    output  reg             sdram_rd_req,
    output  reg     [23:0]  sdram_rd_addr
);

wire            wr_ack_fall;
wire            rd_ack_fall;
wire    [9:0]   wr_fifo_num;

reg             wr_ack_dly;
reg             rd_ack_dly;
reg             bank_en;
reg             bank_flag;
reg     [23:0]  rd_line_start_addr_r;

localparam [23:0] RD_LINE_WORDS = 24'd1024;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        wr_ack_dly <= 1'b0;
    end else begin
        wr_ack_dly <= sdram_wr_ack;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        rd_ack_dly <= 1'b0;
    end else begin
        rd_ack_dly <= sdram_rd_ack;
    end
end

assign wr_ack_fall = wr_ack_dly & ~sdram_wr_ack;
assign rd_ack_fall = rd_ack_dly & ~sdram_rd_ack;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        bank_en   <= 1'b0;
        bank_flag <= 1'b0;
    end else if (wr_ack_fall && pingpang_en) begin
        if (sdram_wr_addr[21:0] < (sdram_wr_e_addr - wr_burst_len)) begin
            bank_en   <= bank_en;
            bank_flag <= bank_flag;
        end else begin
            bank_flag <= ~bank_flag;
            bank_en   <= 1'b1;
        end
    end else if (bank_en) begin
        bank_en   <= 1'b0;
        bank_flag <= bank_flag;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        sdram_wr_addr <= 24'd0;
    end else if (wr_rst) begin
        sdram_wr_addr <= sdram_wr_b_addr;
    end else if (wr_ack_fall) begin
        if (sdram_wr_addr < (sdram_wr_e_addr - wr_burst_len)) begin
            sdram_wr_addr <= sdram_wr_addr + wr_burst_len;
        end else begin
            sdram_wr_addr <= sdram_wr_b_addr;
        end
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        sdram_rd_addr        <= 24'd0;
        rd_line_start_addr_r <= 24'd0;
    end else if (rd_rst) begin
        if (rd_flip_v) begin
            rd_line_start_addr_r <= sdram_rd_e_addr - RD_LINE_WORDS;
            sdram_rd_addr        <= sdram_rd_e_addr - RD_LINE_WORDS;
        end else begin
            rd_line_start_addr_r <= sdram_rd_b_addr;
            sdram_rd_addr        <= sdram_rd_b_addr;
        end
    end else if (rd_ack_fall) begin
        if (rd_flip_v) begin
            if ((sdram_rd_addr + rd_burst_len) < (rd_line_start_addr_r + RD_LINE_WORDS)) begin
                sdram_rd_addr <= sdram_rd_addr + rd_burst_len;
            end else if (rd_line_start_addr_r > sdram_rd_b_addr) begin
                rd_line_start_addr_r <= rd_line_start_addr_r - RD_LINE_WORDS;
                sdram_rd_addr        <= rd_line_start_addr_r - RD_LINE_WORDS;
            end else begin
                rd_line_start_addr_r <= sdram_rd_e_addr - RD_LINE_WORDS;
                sdram_rd_addr        <= sdram_rd_e_addr - RD_LINE_WORDS;
            end
        end else begin
            if (sdram_rd_addr < (sdram_rd_e_addr - rd_burst_len)) begin
                sdram_rd_addr <= sdram_rd_addr + rd_burst_len;
            end else begin
                sdram_rd_addr <= sdram_rd_b_addr;
            end
            rd_line_start_addr_r <= sdram_rd_b_addr;
        end
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        sdram_wr_req <= 1'b0;
        sdram_rd_req <= 1'b0;
    end else if (init_end) begin
        if (wr_fifo_num >= wr_burst_len) begin
            sdram_wr_req <= 1'b1;
            sdram_rd_req <= 1'b0;
        end else if ((rd_fifo_num < rd_burst_len) && read_valid) begin
            sdram_wr_req <= 1'b0;
            sdram_rd_req <= 1'b1;
        end else begin
            sdram_wr_req <= 1'b0;
            sdram_rd_req <= 1'b0;
        end
    end else begin
        sdram_wr_req <= 1'b0;
        sdram_rd_req <= 1'b0;
    end
end

fifo_data wr_fifo_data(
    .wrclk      (wr_fifo_wr_clk),
    .wrreq      (wr_fifo_wr_req),
    .data       (wr_fifo_wr_data),
    .rdclk      (sys_clk),
    .rdreq      (sdram_wr_ack),
    .q          (sdram_data_in),
    .rdusedw    (wr_fifo_num),
    .wrusedw    (),
    .aclr       (~sys_rst_n)
);

fifo_data rd_fifo_data(
    .wrclk      (sys_clk),
    .wrreq      (sdram_rd_ack),
    .data       (sdram_data_out),
    .rdclk      (rd_fifo_rd_clk),
    .rdreq      (rd_fifo_rd_req),
    .q          (rd_fifo_rd_data),
    .rdusedw    (),
    .wrusedw    (rd_fifo_num),
    .aclr       (~sys_rst_n || rd_rst)
);

endmodule