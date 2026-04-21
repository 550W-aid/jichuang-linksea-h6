`include "sdram_param.v"

module sdram_data(
    input   wire    I_sys_clk,  // 系统时钟
    input   wire    I_rst_n,    // 系统复位，低电平有效

    input   wire    [15:0]I_sdram_data,   // 写入sdram中的数据
    output  wire    [15:0]O_sdram_data,   // 读出sdram的数据
    input   wire    [3:0]I_work_state,   // sdram的工作状态
    input   wire    [9:0]I_cnt_clk,     // 时钟计数

    inout   wire    [15:0]IO_sdram_data   // sdram数据总线
);

    // SDRAM数据总线为输出状态
    reg sdram_dq_out_en;

    // 将写入数据送至SDRAM数据总线上
    reg [15:0]sdram_dq_in;

    // 读数据时，寄存SDRAM数据总线数据
    reg [15:0]sdram_dq_out;

    // SDRAM数据总线为输出状态
    always@(posedge I_sys_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)
            sdram_dq_out_en <= 1'b0;
        else if((I_work_state==`WR)||(I_work_state==`WR_BE))begin
            sdram_dq_out_en <= 1'b1;
        end
        else
            sdram_dq_out_en <= 1'b0;
    end

    // 将写入数据送至SDRAM数据总线上
    always@(posedge I_sys_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)
            sdram_dq_in <= 'd0;
        else if((I_work_state==`WR)||(I_work_state==`WR_BE))
            sdram_dq_in <= I_sdram_data;
        else
            sdram_dq_in <= sdram_dq_in;
    end

    // 读数据时，寄存SDRAM数据总线数据
    always@(posedge I_sys_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)
            sdram_dq_out <= 'd0;
        else if(I_work_state==`RD_BE)
            sdram_dq_out <= IO_sdram_data;
        else
            sdram_dq_out <= sdram_dq_out;
    end

    // SDRAM 双向数据线作为输入时保持高阻态
    assign IO_sdram_data = sdram_dq_out_en?sdram_dq_in:16'hzzzz;
    // 输出SDRAM中读取的数据
    assign O_sdram_data = sdram_dq_out;

endmodule