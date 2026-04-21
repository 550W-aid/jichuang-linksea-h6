module sdram_control(
    input   wire    I_ref_clk,  // 参考时钟
    input   wire    I_rst_n,    // 复位信号，低电平有效

    // SDRAM 控制器写端口
    input   wire    I_sdram_wr_req, // 写sdram请求信号
    output  wire    O_sdram_wr_ack, // 写sdram响应信号
    input   wire    [23:0]I_sdram_wr_addr,  // 写sdram时地址
    input   wire    [9:0]I_sdram_wr_burst,  // 写sdram时数据突发长度
    input   wire    [15:0]I_sdram_wr_data,  // 写入sdram的数据

    // SDRAM 控制器读端口
    input   wire    I_sdram_rd_req, // 读sdram请求信号
    output  wire    O_sdram_rd_ack, // 读sdram响应信号
    input   wire    [23:0]I_sdram_rd_addr,  // 读sdram时地址
    input   wire    [9:0]I_sdram_rd_burst,  // 读sdram时数据突发长度
    output  wire    [15:0]O_sdram_rd_data,  // 读出sdram的数据

    output  wire    O_sdram_init_done,  // SDRAM初始化完成

    // SDRAM PHY
    output  wire    O_sdram_cke,    // SDRAM 时钟有效信号
    output  wire    O_sdram_cs_n,   // SDRAM 片选信号
    output  wire    O_sdram_ras_n,  // SDRAM 行选信号
    output  wire    O_sdram_cas_n,  // SDRAM 列选信号
    output  wire    O_sdram_we_n,   // SDRAM 写使能信号
    output  wire    [1:0]O_sdram_bank,  // SDRAM Bank地址线
    output  wire    [12:0]O_sdram_addr, // SDRAM 地址总线
    inout   wire    [15:0]IO_sdram_dq   // SDRAM 数据总线
);

    // sdram_ctrl
    wire [4:0]sdram_init_state;
    wire [3:0]sdram_work_state;
    wire [9:0]cnt_clk;
    wire sdram_rd_wr;

    // sdram_cmd
    sdram_cmd sdram_cmd(
        .I_sys_clk          (I_ref_clk),  // 系统时钟
        .I_rst_n            (I_rst_n),    // 复位信号，低电平有效

        // 输入控制命令
        .I_sdram_wr_addr    (I_sdram_wr_addr),    // sdram写地址
        .I_sdram_rd_addr    (I_sdram_rd_addr),    // sdram读地址
        .I_sdram_wr_burst   (I_sdram_wr_burst),   // 突发写sdram字节数
        .I_sdram_rd_burst   (I_sdram_rd_burst),   // 突发读sdram字节数

        // sdram工作状态
        .I_init_state       (sdram_init_state),   // sdram初始化状态
        .I_work_state       (sdram_work_state),   // sdram工作状态
        .O_cnt_clk          (cnt_clk),  // 延时计数器
        .I_sdram_rd_wr      (sdram_rd_wr),  // sdram读/写控制信号

        // 输出控制命令
        .O_sdram_cke        (O_sdram_cke),    // sdram时钟使能
        .O_sdram_cs_n       (O_sdram_cs_n),   // sdram片选信号
        .O_sdram_ras_n      (O_sdram_ras_n),  // sdram行选信号
        .O_sdram_cas_n      (O_sdram_cas_n),  // sdram列选信号
        .O_sdram_we_n       (O_sdram_we_n),   // sdram写使能信号
        .O_sdram_bank       (O_sdram_bank),   // sdram BANK地址
        .O_sdram_addr       (O_sdram_addr)    // sdram 地址总线
    );

    // sdram_ctrl
    sdram_ctrl sdram_ctrl(
        .I_ref_clk          (I_ref_clk),  // 参考时钟
        .I_rst_n            (I_rst_n),    // 复位信号，低电平有效

        .I_sdram_wr_req     (I_sdram_wr_req),    // sdram写请求
        .I_sdram_rd_req     (I_sdram_rd_req),     // sdram读请求
        .I_sdram_wr_burst   (I_sdram_wr_burst), // sdram写突发长度
        .I_sdram_rd_burst   (I_sdram_rd_burst),   // sdram读突发长度

        .O_sdram_wr_ack     (O_sdram_wr_ack), // sdram写响应
        .O_sdram_rd_ack     (O_sdram_rd_ack), // sdram读响应
        .O_sdram_init_done  (O_sdram_init_done),  // sdram初始化完成标志
        .O_sdram_init_state (sdram_init_state),   // sdram初始化状态
        .O_sdram_work_state (sdram_work_state),   // sdram工作状态
        .O_cnt_clk          (cnt_clk),  // 时钟计数器
        .O_sdram_rd_wr      (sdram_rd_wr)   // sdram读写控制信号
    );

    // sdram_data
    sdram_data sdram_data(
        .I_sys_clk      (I_ref_clk),  // 系统时钟
        .I_rst_n        (I_rst_n),    // 系统复位，低电平有效

        .I_sdram_data   (I_sdram_wr_data),   // 写入sdram中的数据
        .O_sdram_data   (O_sdram_rd_data),   // 读出sdram的数据
        .I_work_state   (sdram_work_state),   // sdram的工作状态
        .I_cnt_clk      (cnt_clk),     // 时钟计数

        .IO_sdram_data  (IO_sdram_dq)  // sdram数据总线
    );

endmodule