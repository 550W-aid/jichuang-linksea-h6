// SDRAM 初始化各个状态
`define I_NOP 5'd0  // 等待上电200us稳定
`define I_PCH 5'd1  // 预充电命令
`define I_TRP 5'd2  // 预充电过程等待
`define I_ARF 5'd3  // 自刷新命令
`define I_TRF 5'd4  // 自刷新过程等待
`define I_LMR 5'd5  // 模式寄存器配置命令
`define I_TRSC 5'd6 // 模式寄存器配置过程等待
`define I_DONE 5'd7 // 初始化完成

// SDRAM 工作各个状态
`define IDLE 4'd0   // 空闲状态
`define ACT 4'd1  // 行激活有效状态
`define TRCD 4'd2   // 行激活过程等待
`define WR 4'd3     // 写操作
`define WR_BE 4'd4  // 写数据
`define TWR 4'd5    // 写回
`define RD 4'd6     // 读操作
`define CL 4'd7     // 列潜伏期
`define RD_BE 4'd8  // 读数据
`define PCH 4'd9    // 预充电状态
`define TRP 4'd10   // 预充电过程等待
`define ARF 4'd11   // 自动刷新
`define TRFC 4'd12  // 自动刷新过程等待

// 延时参数
`define end_trp     O_cnt_clk == TRP  // 预充电过程等待结束
`define end_trf    O_cnt_clk == TRC  // 自动刷新过程等待结束
`define end_trsc    O_cnt_clk == TRSC // 模式寄存器配置过程等待结束
`define end_trcd    O_cnt_clk == TRCD-1  // 
`define end_cl     O_cnt_clk == TCL-1
`define end_wrburst O_cnt_clk == I_sdram_wr_burst - 1
`define end_twrite  O_cnt_clk == I_sdram_wr_burst - 1
`define end_rdburst O_cnt_clk == I_sdram_rd_burst - 4
`define end_tread   O_cnt_clk == I_sdram_rd_burst + 2
`define end_twr     O_cnt_clk == TWR

// SDRAM 操作命令 {CKE,CS_N,RAS_N,CAS_N,WE_N}
`define CMD_INIT    5'b01111    // INIT
`define CMD_NOP     5'b10111    // NOP
`define CMD_PCH     5'b10010    // PCH
`define CMD_ARF     5'b10001    // ARF
`define CMD_LMR     5'b10000    // LMR
`define CMD_ACT     5'b10011    // ACT
`define CMD_WR      5'b10100    // WR
`define CMD_RD      5'b10101    // RD
`define CMD_BT      5'b10110    // BT