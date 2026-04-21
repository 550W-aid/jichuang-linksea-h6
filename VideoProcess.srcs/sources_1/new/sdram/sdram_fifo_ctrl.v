module sdram_fifo_ctrl(
    input   wire    I_ref_clk,  // 参考时钟
    input   wire    I_rst_n,    // 系统复位,低电平有效

    // 写部分:外部-->FIFO
    input   wire    I_fifo_wr_clk,   // fifo写时钟
    input   wire    I_fifo_wr_req,   // 写入fifo请求
    input   wire    [15:0]I_fifo_wr_data,  // 写入fifo的数据
    input   wire    [23:0]I_wr_saddr, // 写入sdram的起始地址
    input   wire    [23:0]I_wr_eaddr, // 写入sdram的终止地址
    input   wire    [9:0]I_wr_brust, // 写入sdram的突发长度
    input   wire    I_fifo_wr_load,  // 写入fifo数据清空

    // wr_fifo:FIFO(写)-->SDRAM(读)
    output  reg     O_sdram_wr_req, // 数据写入sdram写请求
    input   wire    I_sdram_wr_ack, // 数据写入sdram写响应
    output  reg     [23:0]O_sdram_wr_addr,    // 写数据进sdram的地址
    output  wire    [15:0]O_sdram_wr_data,    // 写入sdram的数据

    // rd_fifo:SDRAM(写)-->FIFO(读)
    output  reg     O_sdram_rd_req, // 数据读出sdram读请求
    input   wire    I_sdram_rd_ack, // 数据读出sdram读响应
    output  reg     [23:0]O_sdram_rd_addr,    // 读数据进fifo的地址
    input   wire    [15:0]I_sdram_rd_data,    // 读入fifo的数据

    // 读部分:FIFO-->外部
    input   wire    I_fifo_rd_clk,  // 数据读出fifo读时钟
    input   wire    I_fifo_rd_req,  // 数据读出fifo读请求
    output  wire    [15:0]O_fifo_rd_data, // 读出fifo的数据
    input   wire    [23:0]I_rd_saddr,    // 读出sdram的起始地址
    input   wire    [23:0]I_rd_eaddr,    // 读出sdram的终止地址
    input   wire    [9:0]I_rd_brust,     // 读出sdram的突发长度
    input   wire    I_fifo_rd_load, // 读出fifo数据清空

    // sdram
    input   wire    I_sdram_init_done,  // sdram初始化完成
    input   wire    I_sdram_rd_valid,   // sdram数据读使能
    input   wire    I_sdram_pingpang_en,  // sdram乒乓操作使能

    output  wire    rdempty,
    // output  wire    wrempty,
    output  wire    [9:0]rdusedw
);

    // 写fifo数据清空信号缓存
    reg fifo_wr_load_r1;
    reg fifo_wr_load_r2;
    // 读fifo数据清空缓存
    reg fifo_rd_load_r1;
    reg fifo_rd_load_r2;
    // sdram写响应信号缓存
    reg sdram_wr_ack1;
    reg sdram_wr_ack2;
    // sdram读响应信号缓存
    reg sdram_rd_ack1;
    reg sdram_rd_ack2;
    // sdram读使能信号
    reg sdram_rd_valid1;
    reg sdram_rd_valid2;
    // 写fifo数据清空信号上升沿
    wire fifo_wr_load_p;
    // 读fifo数据清空信号上升沿
    wire fifo_rd_load_p;
    // 写sdram响应信号下降沿
    wire sdram_wr_ack_n;
    // 写sdram响应信号下降沿
    wire sdram_rd_ack_n;
    // sdram_wr_fifo
    wire [9:0]wr_fifo_use;
    // sdram_rd_fifo
    wire [9:0]rd_fifo_use;

    // 写fifo数据清空信号缓存
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n == 1'b0)begin
            fifo_wr_load_r1 <= 1'b0;
            fifo_wr_load_r2 <= 1'b0;
        end
        else begin
            fifo_wr_load_r1 <= I_fifo_wr_load;
            fifo_wr_load_r2 <= fifo_wr_load_r1;
        end
    end

    // 读fifo数据清空缓存
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n == 1'b0)begin
            fifo_rd_load_r1 <= 1'b0;
            fifo_rd_load_r2 <= 1'b0;
        end
        else begin
            fifo_rd_load_r1 <= I_fifo_rd_load;
            fifo_rd_load_r2 <= fifo_rd_load_r1;
        end
    end

    // sdram写响应信号缓存
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n == 1'b0)begin
            sdram_wr_ack1 <= 1'b0;
            sdram_wr_ack2 <= 1'b0;
        end
        else begin
            sdram_wr_ack1 <= I_sdram_wr_ack;
            sdram_wr_ack2 <= sdram_wr_ack1;
        end
    end

    // sdram读响应信号缓存
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n == 1'b0)begin
            sdram_rd_ack1 <= 1'b0;
            sdram_rd_ack2 <= 1'b0;
        end
        else begin
            sdram_rd_ack1 <= I_sdram_rd_ack;
            sdram_rd_ack2 <= sdram_rd_ack1;
        end
    end

    // sdram读使能信号
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)begin
            sdram_rd_valid1 <= 1'b0;
            sdram_rd_valid2 <= 1'b0;
        end
        else begin
            sdram_rd_valid1 <= I_sdram_rd_valid;
            sdram_rd_valid2 <= sdram_rd_valid1;
        end
    end

    // sdram写地址产生模块
    reg sw_bank_en;     // 切换BANK使能信号
    reg rw_bank_flag;   // 读写BANK的标志
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)begin
            O_sdram_wr_addr <= 24'd0;
            sw_bank_en <= 1'b0;
            rw_bank_flag <= 1'b0;
        end
        else if(fifo_wr_load_p)begin
            O_sdram_wr_addr <= I_wr_saddr;
            sw_bank_en <= 1'b0;
            rw_bank_flag <= 1'b0;
        end
        else if(sdram_wr_ack_n)begin
            if(I_sdram_pingpang_en)begin
                if(O_sdram_wr_addr[22:0] < (I_wr_eaddr - I_wr_brust))begin
                    O_sdram_wr_addr <= O_sdram_wr_addr+I_wr_brust;
                end
                else begin
                    rw_bank_flag <= ~rw_bank_flag;
                    sw_bank_en <= 1'b1;
                end
            end
            else if(O_sdram_wr_addr < (I_wr_eaddr - I_wr_brust))
                O_sdram_wr_addr <= O_sdram_wr_addr + I_wr_brust;
            else
                O_sdram_wr_addr <= I_wr_saddr;
        end
        else if(sw_bank_en)begin
            sw_bank_en <= 1'b0;
            if(rw_bank_flag == 1'b0)
                O_sdram_wr_addr <= {1'b0,I_wr_saddr[22:0]};
            else
                O_sdram_wr_addr <= {1'b1,I_wr_saddr[22:0]};
        end
    end

    // sdram读地址产生模块
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)begin
            O_sdram_rd_addr <= 24'd0;
        end
        else if(fifo_rd_load_p)begin
            O_sdram_rd_addr <= I_rd_saddr;
        end
        else if(sdram_rd_ack_n)begin
            if(I_sdram_pingpang_en)begin
                if(O_sdram_rd_addr[22:0] < (I_rd_eaddr - I_rd_brust))begin
                    O_sdram_rd_addr <= O_sdram_rd_addr + I_rd_brust;
                end
                else begin
                    if(rw_bank_flag == 1'b0)
                        O_sdram_rd_addr <= {1'b1,I_rd_saddr[22:0]};
                    else
                        O_sdram_rd_addr <= {1'b0,I_rd_saddr[22:0]};
                end
            end
            else if(O_sdram_rd_addr < I_rd_eaddr - I_rd_brust)
                O_sdram_rd_addr <= O_sdram_rd_addr + I_rd_brust;
            else
                O_sdram_rd_addr <= I_rd_saddr;
        end
    end

    // sdram读写请求产生模块
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)begin
            O_sdram_wr_req <= 1'b0;
            O_sdram_rd_req <= 1'b0;
        end
        else if(I_sdram_init_done)begin
            if(wr_fifo_use>=I_wr_brust)begin
                O_sdram_wr_req <= 1'b1;
                O_sdram_rd_req <= 1'b0;
            end
            else if((rd_fifo_use<I_rd_brust)&&sdram_rd_valid2)begin
                O_sdram_wr_req <= 1'b0;
                O_sdram_rd_req <= 1'b1;
            end
            else begin
                O_sdram_wr_req <= 1'b0;
                O_sdram_rd_req <= 1'b0;
            end
        end
        else begin
            O_sdram_wr_req <= 1'b0;
            O_sdram_rd_req <= 1'b0;
        end
    end

    // 写fifo数据清空信号上升沿
    assign fifo_wr_load_p = (~fifo_wr_load_r2)&(fifo_wr_load_r1);

    // 读fifo数据清空信号上升沿
    assign fifo_rd_load_p = (~fifo_rd_load_r2)&(fifo_rd_load_r1);

    // 写sdram响应信号下降沿
    assign sdram_wr_ack_n = (sdram_wr_ack2)&(~sdram_wr_ack1);
    
    // 写sdram响应信号下降沿
    assign sdram_rd_ack_n = (sdram_rd_ack2)&(~sdram_rd_ack1);

    // sdram_wr_fifo
    sdram_wr_fifo   sdram_wr_fifo_inst (
        .wrclk ( I_fifo_wr_clk ),
        .wrreq ( I_fifo_wr_req ),
        .data ( I_fifo_wr_data ),

        .rdclk ( I_ref_clk ),
        .rdreq ( I_sdram_wr_ack ),
        .q ( O_sdram_wr_data ),
        
        .aclr ( ~I_rst_n|fifo_wr_load_p),
        .rdusedw ( wr_fifo_use )
    );

    // sdram_rd_fifo
    sdram_rd_fifo   sdram_rd_fifo_inst (
        .wrclk ( I_ref_clk ),
        .wrreq ( I_sdram_rd_ack ),
        .data ( I_sdram_rd_data ), 
        
        .rdclk ( I_fifo_rd_clk ),
        .rdreq ( I_fifo_rd_req ),
        .q ( O_fifo_rd_data ),

        .aclr ( ~I_rst_n|fifo_rd_load_p ),
        .rdempty (rdempty),      //output    rdempty
        .wrusedw ( rd_fifo_use )
    );

endmodule
