`include "sdram_param.v"

module sdram_ctrl(
    input   wire    I_ref_clk,  // 参考时钟
    input   wire    I_rst_n,    // 复位信号，低电平有效

    input   wire    I_sdram_wr_req,    // sdram写请求
    input   wire    I_sdram_rd_req,     // sdram读请求
    input   wire    [9:0]I_sdram_wr_burst, // sdram写突发长度
    input   wire    [9:0]I_sdram_rd_burst,   // sdram读突发长度

    output  wire    O_sdram_wr_ack, // sdram写响应
    output  wire    O_sdram_rd_ack, // sdram读响应
    output  wire    O_sdram_init_done,  // sdram初始化完成标志
    output  reg     [4:0]O_sdram_init_state,   // sdram初始化状态
    output  reg     [3:0]O_sdram_work_state,   // sdram工作状态
    output  reg     [9:0]O_cnt_clk,  // 时钟计数器
    output  reg     O_sdram_rd_wr   // sdram读写控制信号
);

    // 时钟个数 100Mhz下(10ns)
    parameter   TRP = 10'd4,    // 预充电周期,这里选择为20ns
                TRC = 10'd6,    // 自动刷新周期,这里选择为70ns
                TRSC = 10'd6,    // 模式配置延迟,这里选择2个时钟周期
                TRCD = 10'd2,   // 行选通周期，这里选择为2个时钟周期
                TCL = 10'd4,    // 列潜伏期，这里选择为2个时钟周期
                TWR = 10'd2,    // 写入校正，这里选择为2个时钟周期
                T_200US = 15'd20_000,   // 200us计数个数
                T_AUTO_AREF = 11'd781;   // 64ms

    // 上电200us,等待SDRAM稳定
    reg [14:0]cnt_200us;

    // 自刷新计数
    reg [10:0]cnt_auto_ref;

    // 自刷新请求
    reg auto_ref_req;

    // 初始化过程对自动刷新操作计数
    reg [3:0]init_arf_cnt;

    // 计数器控制逻辑
    reg cnt_rst_n;

    // SDRAM上电200us稳定
    wire t_200us_done;

    // SDRAM自动刷新应答信号
    wire sdram_ref_ack;

    // 上电200us,等待SDRAM稳定
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)
            cnt_200us <= 'd0;
        else if(cnt_200us < T_200US)
            cnt_200us <= cnt_200us + 1'b1;
        else
            cnt_200us <= cnt_200us;
    end

    // 自刷新计数
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)
            cnt_auto_ref <= 'd0;
        else if(cnt_auto_ref < T_AUTO_AREF)
            cnt_auto_ref <= cnt_auto_ref + 1'b1;
        else
            cnt_auto_ref <= 'd0;
    end

    // 自刷新请求
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)
            auto_ref_req <= 1'b0;
        else if(cnt_auto_ref == T_AUTO_AREF-1)
            auto_ref_req <= 1'b1;
        else if(sdram_ref_ack)
            auto_ref_req <= 1'b0;
        else
            auto_ref_req <= auto_ref_req;
    end

    // 延时计数器对时钟计数
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)
            O_cnt_clk <= 10'd0;
        else if(cnt_rst_n==1'b0)
            O_cnt_clk <= 10'd0;
        else
            O_cnt_clk <= O_cnt_clk + 1'b1;
    end

    // 初始化过程对自动刷新操作计数
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)
            init_arf_cnt <= 4'd0;
        else if(O_sdram_init_state == `I_NOP)
            init_arf_cnt <= 4'd0;
        else if(O_sdram_init_state == `I_ARF)
            init_arf_cnt <= init_arf_cnt + 1'b1;
        else
            init_arf_cnt <= init_arf_cnt;
    end

    // SDRAM的初始化状态机
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)
            O_sdram_init_state <= `I_NOP;
        else begin
            case(O_sdram_init_state)
                // 上电复位后200us延迟
                `I_NOP:O_sdram_init_state <= t_200us_done?`I_PCH:`I_NOP;
                // 预充电状态
                `I_PCH:O_sdram_init_state <= `I_TRP;
                // 预充电等待
                `I_TRP:O_sdram_init_state <= (`end_trp)?`I_ARF:`I_TRP;
                // 自刷新状态
                `I_ARF:O_sdram_init_state <= `I_TRF;
                // 等待自动刷新结束
                `I_TRF:O_sdram_init_state <= (`end_trf)?
                                             ((init_arf_cnt==4'd8)?`I_LMR:`I_ARF):`I_TRF;
                // 配置模式寄存器
                `I_LMR:O_sdram_init_state <= `I_TRSC;
                // 等待模式寄存器设置完
                `I_TRSC:O_sdram_init_state <= (`end_trsc)?`I_DONE:`I_TRSC;
                // SDRAM初始化完成
                `I_DONE:O_sdram_init_state <= O_sdram_init_state;
                default:O_sdram_init_state <= `I_NOP;
            endcase
        end
    end

    // SDRAM的工作状态机
    always@(posedge I_ref_clk or negedge I_rst_n)begin
        if(I_rst_n==1'b0)
            O_sdram_work_state <= `IDLE;    // 空闲状态
        else begin
            case(O_sdram_work_state)
            `IDLE:begin
                // 跳转自动刷新
                if(auto_ref_req&O_sdram_init_done)begin
                    O_sdram_work_state <= `ARF;
                    O_sdram_rd_wr <= 1'b1;
                end
                else if(I_sdram_wr_req&O_sdram_init_done)begin
                    O_sdram_work_state <= `ACT;
                    O_sdram_rd_wr <= 1'b0;
                end
                else if(I_sdram_rd_req&O_sdram_init_done)begin
                    O_sdram_work_state <= `ACT;
                    O_sdram_rd_wr <= 1'b1;
                end
                else begin
                    O_sdram_work_state <= `IDLE;
                    O_sdram_rd_wr <= 1'b1;
                end
            end
            `ACT:begin
                O_sdram_work_state <= `TRCD;
            end
            `TRCD:begin
                if(`end_trcd)begin
                    if(O_sdram_rd_wr==1'b1)
                        O_sdram_work_state <= `RD;
                    else
                        O_sdram_work_state <= `WR;
                end
                else
                    O_sdram_work_state <= `TRCD;
            end
            `WR:begin
                O_sdram_work_state <= `WR_BE;
            end
            `WR_BE:begin
                O_sdram_work_state <= (`end_twrite)?`TWR:`WR_BE;
            end
            `TWR:begin
                O_sdram_work_state <= (`end_twr)?`PCH:`TWR;
            end
            `RD:begin
                O_sdram_work_state <= `CL;
            end
            `CL:begin
                O_sdram_work_state <= (`end_cl)?`RD_BE:`CL;
            end
            `RD_BE:begin
                O_sdram_work_state <= (`end_tread)?`PCH:`RD_BE;
            end
            `PCH:begin
                O_sdram_work_state <= `TRP;
            end
            `TRP:begin
                O_sdram_work_state <= (`end_trp)?`IDLE:`TRP;
            end
            `ARF:begin
                O_sdram_work_state <= `TRFC;
            end
            `TRFC:begin
                O_sdram_work_state <= (`end_trf)?`IDLE:`TRFC;
            end
            default: O_sdram_work_state <= `IDLE;
            endcase
        end
    end

    // 计数器控制逻辑
    always@(*)begin
        case(O_sdram_init_state)
            `I_NOP: cnt_rst_n <= 1'b0;
            `I_PCH: cnt_rst_n <= 1'b1;
            `I_TRP: cnt_rst_n <= (`end_trp)?1'b0:1'b1;
            `I_ARF: cnt_rst_n <= 1'b1;
            `I_TRF: cnt_rst_n <= (`end_trf)?1'b0:1'b1;
            `I_LMR: cnt_rst_n <= 1'b1;
            `I_TRSC: cnt_rst_n <= (`end_trsc)?1'b0:1'b1;
            `I_DONE:begin
                case(O_sdram_work_state)
                    `IDLE: cnt_rst_n <= 1'b0;
                    `ACT:   cnt_rst_n <= 1'b1;
                    `TRCD:  cnt_rst_n <= (`end_trcd)?1'b0:1'b1;
                    `WR_BE: cnt_rst_n <= (`end_twrite)?1'b0:1'b1;
                    `TWR: cnt_rst_n <= (`end_twr)?1'b0:1'b1;
                    `CL: cnt_rst_n <= (`end_cl)?1'b0:1'b1;
                    `RD_BE: cnt_rst_n <= (`end_tread)?1'b0:1'b1;
                    `TRP: cnt_rst_n <= (`end_trp)?1'b0:1'b1;
                    `TRFC: cnt_rst_n <= (`end_trf)?1'b0:1'b1;
                    default: cnt_rst_n <= 1'b0;
                endcase
            end
            default: cnt_rst_n <= 1'b0;
        endcase
    end

    // SDRAM上电200us稳定
    assign t_200us_done = (cnt_200us == T_200US);

    // SDRAM初始化完成标志
    assign O_sdram_init_done = (O_sdram_init_state == `I_DONE);

    // SDRAM自动刷新应答信号
    assign sdram_ref_ack = (O_sdram_work_state == `ARF);

    // 写SDRAM响应信号
    assign O_sdram_wr_ack = ((O_sdram_work_state==`TRCD)&(~O_sdram_rd_wr)|
                            (O_sdram_work_state==`WR)|
                            (O_sdram_work_state==`WR_BE)&(O_cnt_clk<I_sdram_wr_burst-2'd2));

    // 读SDRAM响应信号
    assign O_sdram_rd_ack = (O_sdram_work_state==`RD_BE)&
                            (O_cnt_clk>=10'd1)&(O_cnt_clk<I_sdram_rd_burst+2'd1);

endmodule
