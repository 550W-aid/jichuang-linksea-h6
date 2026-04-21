`include "sdram_param.v"

module sdram_cmd(
    input   wire    I_sys_clk,  // 系统时钟
    input   wire    I_rst_n,    // 复位信号，低电平有效

    // 输入控制命令
    input   wire    [23:0]I_sdram_wr_addr,    // sdram写地址
    input   wire    [23:0]I_sdram_rd_addr,    // sdram读地址
    input   wire    [9:0]I_sdram_wr_burst,   // 突发写sdram字节数
    input   wire    [9:0]I_sdram_rd_burst,   // 突发读sdram字节数

    // sdram工作状态
    input   wire    [4:0]I_init_state,   // sdram初始化状态
    input   wire    [3:0]I_work_state,   // sdram工作状态
    input   wire    [9:0]O_cnt_clk,  // 延时计数器
    input   wire    I_sdram_rd_wr,  // sdram读/写控制信号

    // 输出控制命令
    output  wire    O_sdram_cke,    // sdram时钟使能
    output  wire    O_sdram_cs_n,   // sdram片选信号
    output  wire    O_sdram_ras_n,  // sdram行选信号
    output  wire    O_sdram_cas_n,  // sdram列选信号
    output  wire    O_sdram_we_n,   // sdram写使能信号
    output  reg     [1:0]O_sdram_bank,   // sdram BANK地址
    output  reg     [12:0]O_sdram_addr    // sdram 地址总线
);

    parameter WRITE_MODE = 1'b0;    // 写模式
    parameter CL = 3'b011; // 列潜伏期3
    parameter BURST_TYPE = 1'b0; // 突发顺序 0:顺序，1:交错
    parameter BURST_LENGTH = 3'b111; // 突发长度，页突发

    // SDRAM 操作指令控制
    reg [4:0]sdram_cmd;

    // SDRAM 读/写地址总线控制
    wire [23:0]sdram_addr;

    // SDRAM 操作指令控制
    always@(posedge I_sys_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)begin
            sdram_cmd <= `CMD_INIT;
            O_sdram_bank <= 2'b11;
            O_sdram_addr <= 13'h1fff;
        end
        else begin
            case(I_init_state)
                `I_NOP,`I_TRP,`I_TRF,`I_TRSC:begin  // 初始化过程中,以下状态执行空操作
                    sdram_cmd <= `CMD_NOP;
                    O_sdram_bank <= 2'b11;
                    O_sdram_addr <= 13'h1fff;
                end
                `I_PCH:begin    // 预充电指令
                    sdram_cmd <= `CMD_PCH;
                    O_sdram_bank <= 2'b11;
                    O_sdram_addr <= 13'h1fff;
                end
                `I_ARF:begin    // 自动刷新指令
                    sdram_cmd <= `CMD_ARF;
                    O_sdram_bank <= 2'b11;
                    O_sdram_addr <= 13'h1fff;
                end
                `I_LMR:begin    // 模式寄存器设置指令
                    sdram_cmd <= `CMD_LMR;
                    O_sdram_bank <= 2'b00;
                    O_sdram_addr <= { // 利用地址线设置模式寄存器
                        3'b000,  // 预留
                        WRITE_MODE, // A[9] Write Mode写模式
                        2'b00,  // A[8:7] 运行模式，普通用户置开放标准模式A[8:7]=2'b00
                        CL, // A[6:4] 列潜伏期配置
                        BURST_TYPE, // A[3] 突发顺序类型
                        BURST_LENGTH    // A[2:0] 突发长度
                    };
                end
                `I_DONE:begin   // SDRAM初始化完成
                    case(I_work_state)
                        `IDLE,`TRCD,`CL,`TWR,`TRP,`TRFC:begin   // 此状态进行空操作
                            sdram_cmd <= `CMD_NOP;
                            O_sdram_bank <= 2'b11;
                            O_sdram_addr <= 13'h1fff;
                        end
                        `ACT:begin    // 行有效命令
                            sdram_cmd <= `CMD_ACT;
                            O_sdram_bank <= sdram_addr[23:22];
                            O_sdram_addr <= sdram_addr[21:9];
                        end
                        `WR:begin   // 写操作指令
                            sdram_cmd <= `CMD_WR;
                            O_sdram_bank <= sdram_addr[23:22];
                            O_sdram_addr <= {4'b0000,sdram_addr[8:0]};
                        end
                        `WR_BE:begin    // 突发写终止指令
                            if(`end_wrburst)
                                sdram_cmd <= `CMD_BT;
                            else begin
                                sdram_cmd <= `CMD_NOP;
                                O_sdram_bank <= 2'b11;
                                O_sdram_addr <= 13'h1fff;
                            end
                        end
                        `RD:begin
                            sdram_cmd <= `CMD_RD;
                            O_sdram_bank <= sdram_addr[23:22];
                            O_sdram_addr <= {4'b0000,sdram_addr[8:0]};
                        end
                        `RD_BE:begin // 突发读终止命令
                            if(`end_rdburst)
                                sdram_cmd <= `CMD_BT;
                            else begin
                                sdram_cmd <= `CMD_NOP;
                                O_sdram_bank <= 2'b11;
                                O_sdram_addr <= 13'h1fff;
                            end
                        end
                        `PCH:begin  // 预充电命令
                            sdram_cmd <= `CMD_PCH;
                            O_sdram_bank <= sdram_addr[23:22];
                            O_sdram_addr <= 13'h0000;
                        end
                        `ARF:begin  // 自动刷新命令
                            sdram_cmd <= `CMD_ARF;
                            O_sdram_bank <= 2'b11;
                            O_sdram_addr <= 13'h1fff;
                        end
                        default:begin
                            sdram_cmd <= `CMD_NOP;
                            O_sdram_bank <= 2'b11;
                            O_sdram_addr <= 13'h1fff;
                        end
                    endcase
                end
                default:begin
                        sdram_cmd <= `CMD_NOP;
                        O_sdram_bank <= 2'b11;
                        O_sdram_addr <= 13'h1fff;
                end
            endcase
        end
    end

    // SDRAM控制信号线复制
    assign {O_sdram_cke,O_sdram_cs_n,O_sdram_ras_n,O_sdram_cas_n,O_sdram_we_n} = sdram_cmd;

    // SDRAM 读/写地址总线控制
    assign sdram_addr = I_sdram_rd_wr?I_sdram_rd_addr:I_sdram_wr_addr;

endmodule