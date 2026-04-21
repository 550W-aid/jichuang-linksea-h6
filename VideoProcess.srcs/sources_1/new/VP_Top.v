`timescale 1 ps / 1 ps

module VP_Top(
    input               sys_clk,       // 系统时钟
    input               sys_rst_n,     // 复位，低有效

    output      [3:0]   LED,           // 调试指示

    input               eth_rxc,       // PHY RX 时钟
    input               eth_rx_ctl,    // PHY RX 数据有效
    input               eth_txc,       // PHY TX 时钟
    input       [7:0]   eth_rxd,       // PHY RX 数据
    output              eth_tx_ctl,    // PHY TX 数据有效
    output      [7:0]   eth_txd,       // PHY TX 数据
    output              GTX_CLK,       // PHY 参考时钟
    output              eth_rst_n,     // PHY 复位
    output              eth_tx_er,     // PHY TX 错误
    
    input               touch_key,
    input               i_Key_GBCR,
    input               i_Key_ANAR,
    inout               eth_mdio,
    output              eth_mdc,

    output              O_sdram_clk,
    output              O_sdram_cke,
    output              O_sdram_cs_n,
    output              O_sdram_ras_n,
    output              O_sdram_cas_n,
    output              O_sdram_we_n,
    output      [1:0]   O_sdram_bank,
    output      [12:0]  O_sdram_addr,
    inout       [15:0]  IO_sdram_dq,

    output              vga_clk,  
    output              vga_hsync,
    output              vga_vsync,
    output     [7:0]    vga_r    ,
    output     [7:0]    vga_g    ,
    output     [7:0]    vga_b    ,

    input               uart_rxd,
    output              uart_txd,

    // output     [7:0]    CMOS_D  ,
    // output              CMOS_HREF,
    output              CMOS_PCLK,
    // output              CMOS_PWDN,
    // output              CMOS_RESET,
    output              CMOS_SCL
    // output              CMOS_SDA,
    // output              CMOS_VSYNC,
    // output              CMOS_XCLK
);

    reg [10:0] cnt;
    reg [12:0] cnt1;
    assign LED[3]    = (cnt1<=4095) ? 1'b1 : 1'b0 ;
    assign LED[2]    = LED[3];

    assign CMOS_PCLK    = vga_hsync ;
    assign CMOS_SCL    = vga_vsync;
    always @(posedge sys_clk)begin
        if(!sys_rst_n) cnt<=0;
        else cnt<=cnt+1;
    end
    always @(posedge sys_clk)begin
        if(!sys_rst_n) cnt1<=0;
        else if(cnt=='d2047) cnt1<=cnt1+1;
    end

    wire clk_25M;
   
    // wire clk_125MHz;
    // wire [1:0] EthSpeedLED;

    // wire        rec_en;
    // wire [7:0]  rec_data;
    // wire [15:0] rec_byte_num;
    // reg         rec_en_d;
    // wire        rec_pkt_done;
    // wire        tx_req;
    // wire        tx_done;

    // wire        sdram_init_done;
    // wire [15:0] sdram_fifo_rd_data;
    // wire        sdram_rdempty;
    // wire        sdram_wrempty;
    // wire [9:0]  sdram_rdusedw;

    pll_1 u_pll_1 (
        .inclk0(sys_clk),
        .c0(clk_125MHz),
        .c1(clk_25M)						//output c1
    );

    // assign GTX_CLK   = clk_125MHz;
    // assign eth_tx_er = 1'b0;
    // assign LED[3]    = sdram_init_done;
    // assign LED[2]    = (state != ST_READY);
    // assign LED[1:0]  = ~EthSpeedLED;
    // assign rec_pkt_done = rec_en_d & ~rec_en;

    // eth_udp_loop u_eth_udp_loop(
    //     .sys_clk      (clk_125MHz),
    //     .sys_rst_n    (sys_rst_n),
    //     .eth_rxc      (eth_rxc),
    //     .eth_rx_ctl   (eth_rx_ctl),
    //     .eth_rxd      (eth_rxd),
    //     .eth_txc      (eth_txc),
    //     .eth_tx_ctl   (eth_tx_ctl),
    //     .eth_txd      (eth_txd),
    //     .eth_rst_n    (eth_rst_n),
    //     .rec_en       (rec_en),
    //     .rec_data     (rec_data),
    //     .rec_byte_num (rec_byte_num),
    //     .tx_req       (tx_req),
    //     .tx_done      (tx_done),
    //     .tx_start_en  (udp_tx_start_en),
    //     .tx_byte_num  (udp_tx_byte_num),
    //     .tx_data      (udp_tx_data)
    // );
    // vga_top u_vga_top(
    //     .clk_25m   ( clk_25M   ),
    //     .rst_n     ( sys_rst_n     ),
    //     .vga_clk   ( vga_clk   ),
    //     .vga_hs    ( vga_hsync ),//vga_hsync
    //     .vga_vs    ( vga_vsync ),//vga_vsync
    //     .vga_r     ( vga_r     ),
    //     .vga_g     ( vga_g     ),
    //     .vga_b     ( vga_b     )
    // );

    // mdio_rw_test u_mdio_rw_test(
    //     .sys_clk    (sys_clk),
    //     .sys_rst_n  (sys_rst_n),
    //     .eth_mdc    (eth_mdc),
    //     .eth_mdio   (eth_mdio),
    //     .i_Key_GBCR (i_Key_GBCR),
    //     .i_Key_ANAR (i_Key_ANAR),
    //     .touch_key  (touch_key),
    //     .led        (EthSpeedLED)
    // );
//=================================================================
//uart
    wire uart_tx_busy;
    reg uart_tx_en;
    reg [7:0] uart_tx_data;
    wire [7:0] rec_uart_data;
    wire uart_rx_done;
    reg uart_rx_done_d;
    wire uart_cmd_strobe;

    // assign uart_tx_en=uart_rx_done;
    // assign uart_tx_data=rec_uart_data;
    
    uart_tx u_uart_tx(
        .sys_clk          ( sys_clk          ),
        .sys_rst_n        ( sys_rst_n        ),
        .uart_en          ( uart_tx_en   ),
        .uart_din         ( uart_tx_data ),

        .uart_txd         ( uart_txd     ),
        .uart_tx_busy     ( uart_tx_busy  )
    );

    uart_rx#(
        .CLK_FRE     ( 50 ),
        .DATA_WIDTH  ( 8 ),
        .PARITY_ON   ( 0 ),
        .PARITY_TYPE ( 0 ),
        .BAUD_RATE   ( 115200 )
    )u_uart_rx(
        .i_clk_sys   ( sys_clk   ),
        .i_rst_n     ( sys_rst_n   ),
        .i_uart_rx   ( uart_rxd   ),
        .o_uart_data ( rec_uart_data ),
        .o_ld_parity (  ),
        .o_rx_done   ( uart_rx_done   )
    );

    assign uart_cmd_strobe = uart_rx_done && !uart_rx_done_d;

    always @(posedge sys_clk) begin
        if(!sys_rst_n) begin
            uart_rx_done_d <= 1'b0;
        end
        else begin
            uart_rx_done_d <= uart_rx_done;
        end
    end
//====================================================================
//sdram
    wire wr_flag;
    wire rd_flag;
    wire tx_test_flag;
    wire dbg_tx_flag;
    assign wr_flag=uart_cmd_strobe&&rec_uart_data=='h31;
    assign rd_flag=uart_cmd_strobe&&rec_uart_data=='h32;
    assign tx_test_flag=uart_cmd_strobe&&rec_uart_data=='h33;
    assign dbg_tx_flag=uart_cmd_strobe&&rec_uart_data=='h34;

    localparam SDRAM_BURST_WORDS = 10'd8;
    localparam SDRAM_BASE_ADDR = 24'd0;
    localparam SDRAM_END_ADDR = 24'd63;

    wire sdram_init_done;
    reg [15:0] sdram_fifo_wr_data;
    reg sdram_fifo_wr_req;
    reg sdram_fifo_wr_load;

    wire [15:0] sdram_fifo_rd_data;
    reg sdram_fifo_rd_req;
    reg sdram_fifo_rd_load;
    wire sdram_rdempty;
    wire [9:0] sdram_rdusedw;
    wire dbg_sdram_wr_req;
    wire dbg_sdram_wr_ack;
    wire dbg_sdram_rd_req;
    wire dbg_sdram_rd_ack;
    reg dbg_sdram_wr_req_d;
    reg dbg_sdram_wr_ack_d;
    reg dbg_sdram_rd_req_d;
    reg dbg_sdram_rd_ack_d;
    reg [7:0] dbg_wr_req_cnt;
    reg [7:0] dbg_wr_ack_cnt;
    reg [7:0] dbg_rd_req_cnt;
    reg [7:0] dbg_rd_ack_cnt;

    reg [2:0] sdram_wr_state;
    reg [4:0] wr_cnt;
    reg [5:0] wr_prep_cnt;

    always @(posedge sys_clk)begin
        if(!sys_rst_n)begin
            sdram_fifo_wr_req<=1'b0;
            sdram_fifo_wr_load<=1'b0;
            sdram_fifo_wr_data<='d0;
            sdram_wr_state<='d0;
            wr_cnt<='d0;
            wr_prep_cnt<='d0;
        end
        else begin
            sdram_fifo_wr_load<=1'b0;
            case (sdram_wr_state)
                'd0:begin
                   if(wr_flag && sdram_init_done) begin
                        sdram_fifo_wr_load<=1'b1;
                        wr_prep_cnt<='d32;
                        sdram_wr_state<='d4;
                   end
                    wr_cnt<='d0;
                    sdram_fifo_wr_req<=0;
                end
                'd1:begin
                    if(wr_cnt<'d8) begin
                        sdram_fifo_wr_data<={4{wr_cnt[3:0]}};
                        sdram_fifo_wr_req<=1'b0;
                        sdram_wr_state<='d2;
                    end
                    else begin
                        sdram_wr_state<='d3;
                        sdram_fifo_wr_req<=1'b0;
                    end
                end
                'd2:begin
                    sdram_fifo_wr_req<=1'b1;
                    wr_cnt<=wr_cnt+1'b1;
                    sdram_wr_state<='d1;
                end
                'd3:begin                    
                    sdram_fifo_wr_req<=1'b0;
                    wr_cnt<='d0;
                    sdram_wr_state<='d0;
                end
                'd4:begin
                    sdram_fifo_wr_req<=1'b0;
                    wr_cnt<='d0;
                    if(wr_prep_cnt!='d0) begin
                        wr_prep_cnt<=wr_prep_cnt-1'b1;
                    end
                    else begin
                        sdram_wr_state<='d1;
                    end
                end
                default:; 
            endcase 

        end
    end

    reg [3:0] sdram_rd_state;
    reg [4:0] rd_cnt;
    reg [1:0] uart_tx_phase;
    reg [15:0] sdram_rd_word;
    reg [4:0] test_tx_cnt;
    reg [5:0] rd_prep_cnt;
    reg sdram_read_fill_en;
    reg [15:0] rd_wait_cnt;

    always @(posedge sys_clk) begin
        if(!sys_rst_n) begin
            dbg_sdram_wr_req_d <= 1'b0;
            dbg_sdram_wr_ack_d <= 1'b0;
            dbg_sdram_rd_req_d <= 1'b0;
            dbg_sdram_rd_ack_d <= 1'b0;
            dbg_wr_req_cnt <= 8'd0;
            dbg_wr_ack_cnt <= 8'd0;
            dbg_rd_req_cnt <= 8'd0;
            dbg_rd_ack_cnt <= 8'd0;
        end
        else begin
            dbg_sdram_wr_req_d <= dbg_sdram_wr_req;
            dbg_sdram_wr_ack_d <= dbg_sdram_wr_ack;
            dbg_sdram_rd_req_d <= dbg_sdram_rd_req;
            dbg_sdram_rd_ack_d <= dbg_sdram_rd_ack;

            if(wr_flag) begin
                dbg_wr_req_cnt <= 8'd0;
                dbg_wr_ack_cnt <= 8'd0;
                dbg_rd_req_cnt <= 8'd0;
                dbg_rd_ack_cnt <= 8'd0;
            end
            else begin
                if(dbg_sdram_wr_req && !dbg_sdram_wr_req_d)
                    dbg_wr_req_cnt <= dbg_wr_req_cnt + 1'b1;
                if(dbg_sdram_wr_ack && !dbg_sdram_wr_ack_d)
                    dbg_wr_ack_cnt <= dbg_wr_ack_cnt + 1'b1;
                if(dbg_sdram_rd_req && !dbg_sdram_rd_req_d)
                    dbg_rd_req_cnt <= dbg_rd_req_cnt + 1'b1;
                if(dbg_sdram_rd_ack && !dbg_sdram_rd_ack_d)
                    dbg_rd_ack_cnt <= dbg_rd_ack_cnt + 1'b1;
            end
        end
    end


    always @(posedge sys_clk)begin
        if(!sys_rst_n)begin
            sdram_fifo_rd_req<=1'b0;
            sdram_fifo_rd_load<=1'b0;
            sdram_rd_state<='d0;
            rd_cnt<='d0;
            uart_tx_phase<='d0;
            uart_tx_en<=1'b0;
            uart_tx_data<='d0;
            sdram_rd_word<='d0;
            test_tx_cnt<='d0;
            rd_prep_cnt<='d0;
            sdram_read_fill_en<=1'b0;
            rd_wait_cnt<='d0;
        end
        else begin
            sdram_fifo_rd_load<=1'b0;
            case (sdram_rd_state)
                'd0:begin
                    if(tx_test_flag) begin
                        sdram_read_fill_en<=1'b0;
                        test_tx_cnt<='d0;
                        uart_tx_phase<='d0;
                        sdram_rd_state<='d5;
                    end
                    else if(dbg_tx_flag) begin
                        sdram_read_fill_en<=1'b0;
                        test_tx_cnt<='d0;
                        uart_tx_phase<='d0;
                        sdram_rd_state<='d9;
                    end
                    else if(rd_flag && sdram_init_done) begin
                        sdram_fifo_rd_load<=1'b1;
                        rd_prep_cnt<='d32;
                        sdram_read_fill_en<=1'b1;
                        rd_wait_cnt<='d0;
                        uart_tx_phase<='d0;
                        sdram_rd_state<='d6;
                    end
                    else begin
                        sdram_read_fill_en<=1'b0;
                        rd_wait_cnt<='d0;
                    end
                    rd_cnt<='d0;
                    sdram_fifo_rd_req<=0;
                    uart_tx_en<=1'b0;
                end
                'd1:begin
                    uart_tx_en<=1'b0;
                    if(rd_cnt<'d8) begin
                        if(!uart_tx_busy && !sdram_rdempty)begin
                            sdram_rd_word<=sdram_fifo_rd_data;
                            sdram_fifo_rd_req<=1'b1;
                            rd_wait_cnt<='d0;
                            rd_cnt<=rd_cnt+1'b1;
                            uart_tx_phase<='d0;
                            sdram_rd_state<='d2;
                        end
                        else if(rd_wait_cnt==16'd50000) begin
                            test_tx_cnt<='d0;
                            uart_tx_phase<='d0;
                            rd_wait_cnt<='d0;
                            sdram_rd_state<='d9;
                        end
                        else begin
                            rd_wait_cnt<=rd_wait_cnt+1'b1;
                        end
                    end
                    else begin
                        sdram_fifo_rd_req<=1'b0;
                        rd_wait_cnt<='d0;
                        sdram_rd_state<='b0;
                    end
                end
                'd2:begin      
                    sdram_fifo_rd_req<=1'b0;
                    uart_tx_en<=1'b0;
                    sdram_rd_state<='d3;
                end
                'd3:begin
                    uart_tx_en<=1'b0;
                    case (uart_tx_phase)
                        2'd0: begin
                            uart_tx_data<=sdram_rd_word[15:8];
                            uart_tx_phase<=2'd1;
                        end
                        2'd1: begin
                            if(!uart_tx_busy) begin
                                uart_tx_en<=1'b1;
                                uart_tx_phase<=2'd2;
                            end
                        end
                        2'd2: begin
                            if(uart_tx_busy) begin
                                uart_tx_phase<=2'd3;
                            end
                        end
                        2'd3: begin
                            if(!uart_tx_busy) begin
                                uart_tx_phase<=2'd0;
                                sdram_rd_state<='d4;
                            end
                        end
                    endcase
                end
                'd4:begin       
                    uart_tx_en<=1'b0;
                    case (uart_tx_phase)
                        2'd0: begin
                            uart_tx_data<=sdram_rd_word[7:0];
                            uart_tx_phase<=2'd1;
                        end
                        2'd1: begin
                            if(!uart_tx_busy) begin
                                uart_tx_en<=1'b1;
                                uart_tx_phase<=2'd2;
                            end
                        end
                        2'd2: begin
                            if(uart_tx_busy) begin
                                uart_tx_phase<=2'd3;
                            end
                        end
                        2'd3: begin
                            if(!uart_tx_busy) begin
                                uart_tx_phase<=2'd0;
                                sdram_rd_state<='d1;
                            end
                        end
                    endcase
                end
                'd5:begin
                    uart_tx_en<=1'b0;
                    if(test_tx_cnt<'d16) begin
                        case (uart_tx_phase)
                            2'd0: begin
                                case (test_tx_cnt)
                                    4'd0,  4'd1 : uart_tx_data <= 8'h00;
                                    4'd2,  4'd3 : uart_tx_data <= 8'h11;
                                    4'd4,  4'd5 : uart_tx_data <= 8'h22;
                                    4'd6,  4'd7 : uart_tx_data <= 8'h33;
                                    4'd8,  4'd9 : uart_tx_data <= 8'h44;
                                    4'd10, 4'd11: uart_tx_data <= 8'h55;
                                    4'd12, 4'd13: uart_tx_data <= 8'h66;
                                    default     : uart_tx_data <= 8'h77;
                                endcase
                                uart_tx_phase<=2'd1;
                            end
                            2'd1: begin
                                if(!uart_tx_busy) begin
                                    uart_tx_en<=1'b1;
                                    uart_tx_phase<=2'd2;
                                end
                            end
                            2'd2: begin
                                if(uart_tx_busy) begin
                                    uart_tx_phase<=2'd3;
                                end
                            end
                            2'd3: begin
                                if(!uart_tx_busy) begin
                                    uart_tx_phase<=2'd0;
                                    test_tx_cnt<=test_tx_cnt+1'b1;
                                end
                            end
                        endcase
                    end
                    else begin
                        uart_tx_phase<=2'd0;
                        sdram_rd_state<='d0;
                    end
                end
                'd6:begin
                    uart_tx_en<=1'b0;
                    sdram_fifo_rd_req<=1'b0;
                    rd_cnt<='d0;
                    if(rd_prep_cnt!='d0) begin
                        rd_prep_cnt<=rd_prep_cnt-1'b1;
                    end
                    else if(rd_wait_cnt==16'd512) begin
                        sdram_read_fill_en<=1'b0;
                        rd_wait_cnt<='d0;
                        sdram_rd_state<='d1;
                    end
                    else begin
                        sdram_read_fill_en<=1'b1;
                        rd_wait_cnt<=rd_wait_cnt+1'b1;
                    end
                end
                'd9:begin
                    uart_tx_en<=1'b0;
                    if(test_tx_cnt<'d16) begin
                        case (uart_tx_phase)
                            2'd0: begin
                                case (test_tx_cnt)
                                    4'd0  : uart_tx_data <= 8'hEE;
                                    4'd1  : uart_tx_data <= 8'h32;
                                    4'd2  : uart_tx_data <= {7'd0, sdram_init_done};
                                    4'd3  : uart_tx_data <= {6'd0, sdram_rdempty, sdram_read_fill_en};
                                    4'd4  : uart_tx_data <= sdram_rdusedw[7:0];
                                    4'd5  : uart_tx_data <= {6'd0, dbg_sdram_rd_ack, dbg_sdram_rd_req};
                                    4'd6  : uart_tx_data <= {6'd0, dbg_sdram_wr_ack, dbg_sdram_wr_req};
                                    4'd7  : uart_tx_data <= dbg_rd_req_cnt;
                                    4'd8  : uart_tx_data <= dbg_rd_ack_cnt;
                                    4'd9  : uart_tx_data <= dbg_wr_req_cnt;
                                    4'd10 : uart_tx_data <= dbg_wr_ack_cnt;
                                    4'd11 : uart_tx_data <= sdram_rd_state;
                                    4'd12 : uart_tx_data <= rd_prep_cnt;
                                    4'd13 : uart_tx_data <= rd_wait_cnt[7:0];
                                    4'd14 : uart_tx_data <= rd_wait_cnt[15:8];
                                    default: uart_tx_data <= 8'h5A;
                                endcase
                                uart_tx_phase<=2'd1;
                            end
                            2'd1: begin
                                if(!uart_tx_busy) begin
                                    uart_tx_en<=1'b1;
                                    uart_tx_phase<=2'd2;
                                end
                            end
                            2'd2: begin
                                if(uart_tx_busy) begin
                                    uart_tx_phase<=2'd3;
                                end
                            end
                            2'd3: begin
                                if(!uart_tx_busy) begin
                                    uart_tx_phase<=2'd0;
                                    test_tx_cnt<=test_tx_cnt+1'b1;
                                end
                            end
                        endcase
                    end
                    else begin
                        uart_tx_phase<=2'd0;
                        sdram_rd_state<='d0;
                    end
                end
                default:; 
            endcase 

        end
    end

    wire I_sdram_rd_valid;
    assign I_sdram_rd_valid=sdram_read_fill_en;

    sdram_top u_sdram_top(
        .I_ref_clk           (sys_clk),
        .I_out_clk           (sys_clk),
        .I_rst_n             (sys_rst_n),
        // 写部分
        .I_fifo_wr_clk       (sys_clk),
        .I_fifo_wr_req       (sdram_fifo_wr_req),
        .I_fifo_wr_data      (sdram_fifo_wr_data),
        .I_fifo_wr_load      (sdram_fifo_wr_load),

        .I_wr_burst          (SDRAM_BURST_WORDS),
        .I_wr_saddr          (SDRAM_BASE_ADDR),
        .I_wr_eaddr          (SDRAM_END_ADDR),
        // 读部分
        .I_fifo_rd_clk       (sys_clk),
        .I_fifo_rd_req       (sdram_fifo_rd_req),
        .O_fifo_rd_data      (sdram_fifo_rd_data),
        .I_fifo_rd_load      (sdram_fifo_rd_load),

        .I_rd_burst          (SDRAM_BURST_WORDS),
        .I_rd_saddr          (SDRAM_BASE_ADDR),
        .I_rd_eaddr          (SDRAM_END_ADDR),
        // 使能端口
        .I_sdram_rd_valid    (I_sdram_rd_valid),
        .I_sdram_pingpang_en (1'b0),
        .O_sdram_init_done   (sdram_init_done),
        // SDRAM 芯片接口
        .O_sdram_clk         (O_sdram_clk),
        .O_sdram_cke         (O_sdram_cke),
        .O_sdram_cs_n        (O_sdram_cs_n),
        .O_sdram_ras_n       (O_sdram_ras_n),
        .O_sdram_cas_n       (O_sdram_cas_n),
        .O_sdram_we_n        (O_sdram_we_n),
        .O_sdram_bank        (O_sdram_bank),
        .O_sdram_addr        (O_sdram_addr),
        .IO_sdram_dq         (IO_sdram_dq),
        .rdempty             (sdram_rdempty),
        .rdusedw             (sdram_rdusedw),
        .dbg_sdram_wr_req    (dbg_sdram_wr_req),
        .dbg_sdram_wr_ack    (dbg_sdram_wr_ack),
        .dbg_sdram_rd_req    (dbg_sdram_rd_req),
        .dbg_sdram_rd_ack    (dbg_sdram_rd_ack)
    );



endmodule
