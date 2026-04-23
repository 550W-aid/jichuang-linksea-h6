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

`ifdef CODEX_BOARD_VIDEO_ONLY
    // Macro-enabled board signoff mode that keeps the VGA image path active
    // while freezing unrelated subsystems for a cleaner image-only boundary.
    localparam BOARD_VIDEO_ONLY = 1'b1;
`else
    // Default integration build keeps the original mixed-feature top behavior.
    localparam BOARD_VIDEO_ONLY = 1'b0;
`endif
    // Board bring-up currently focuses on making ARP reply TX reliable first.
    // Keep the demo UDP sender disabled so it does not contend for GMII TX.
    localparam ENABLE_UDP_DIAG_TX = 1'b0;
    localparam [15:0] UDP_LOOPBACK_MAX_BYTES = 16'd1472;

    reg [10:0] cnt;
    reg [12:0] cnt1;
    wire [2:0] algo_mode_dbg;
    wire clk_25M;
    wire clk_125MHz;
    wire clk_125MHz_tx_shift;
    wire [1:0] EthSpeedLED;
    wire        rec_en;
    wire [7:0]  rec_data;
    wire [15:0] rec_byte_num;
    wire        tx_req;
    wire        tx_done;
    reg         udp_tx_start_en;
    reg  [15:0] udp_tx_byte_num;
    reg  [7:0]  udp_tx_data;
    wire        eth_tx_ctl_udp;
    wire [7:0]  eth_txd_udp;
    wire        eth_rst_n_udp;
    wire        rec_en_udp;
    wire [7:0]  rec_data_udp;
    wire [15:0] rec_byte_num_udp;
    wire        tx_req_udp;
    wire        tx_done_udp;
    (* preserve, noprune *) reg        eth_rx_rec_en_d;
    (* preserve, noprune *) reg        eth_rx_pkt_seen;
    (* preserve, noprune *) reg [7:0]  eth_rx_last_data;
    (* preserve, noprune *) reg [15:0] eth_rx_last_len;
    (* preserve, noprune *) reg [7:0]  eth_tx_clk_mon;
    reg         eth_rx_ctl_d;
    reg         eth_raw_rx_toggle_rx;
    reg  [3:0]  eth_raw_byte_idx_rx;
    reg  [7:0]  eth_raw_b0_rx;
    reg  [7:0]  eth_raw_b1_rx;
    reg  [7:0]  eth_raw_b2_rx;
    reg  [7:0]  eth_raw_b3_rx;
    reg  [7:0]  eth_raw_b4_rx;
    reg  [7:0]  eth_raw_b5_rx;
    reg  [7:0]  eth_raw_b6_rx;
    reg  [7:0]  eth_raw_b7_rx;
    reg  [7:0]  eth_raw_b8_rx;
    reg  [7:0]  eth_raw_b9_rx;
    reg  [7:0]  eth_raw_b10_rx;
    reg  [7:0]  eth_raw_b11_rx;
    reg         eth_rx_pkt_toggle_rx;
    reg         udp_reply_toggle_rx;
    reg  [15:0] udp_reply_len_rx;
    reg  [7:0]  udp_reply_last_data_rx;
    reg         udp_reply_toggle_tx_d0;
    reg         udp_reply_toggle_tx_d1;
    reg  [15:0] udp_reply_len_tx_d0;
    reg  [15:0] udp_reply_len_tx_d1;
    reg  [7:0]  udp_reply_last_data_tx_d0;
    reg  [7:0]  udp_reply_last_data_tx_d1;
    reg  [15:0] udp_reply_len_hold;
    reg  [7:0]  udp_reply_last_data_hold;
    reg         udp_tx_pending;
    reg         udp_tx_active;
    reg  [1:0]  udp_tx_byte_idx;
    reg  [26:0] udp_beacon_cnt;
    reg         eth_tx_launch_toggle_tx;
    reg         eth_tx_done_toggle_tx;
    reg         eth_beacon_toggle_tx;
    reg  [7:0]  eth_last_tx_kind_tx;
    reg  [15:0] eth_last_tx_len_tx;
    reg         eth_rx_pkt_toggle_sys_d0;
    reg         eth_rx_pkt_toggle_sys_d1;
    reg         eth_raw_rx_toggle_sys_d0;
    reg         eth_raw_rx_toggle_sys_d1;
    reg  [7:0]  eth_raw_b0_sys_d0;
    reg  [7:0]  eth_raw_b0_sys_d1;
    reg  [7:0]  eth_raw_b1_sys_d0;
    reg  [7:0]  eth_raw_b1_sys_d1;
    reg  [7:0]  eth_raw_b2_sys_d0;
    reg  [7:0]  eth_raw_b2_sys_d1;
    reg  [7:0]  eth_raw_b3_sys_d0;
    reg  [7:0]  eth_raw_b3_sys_d1;
    reg  [7:0]  eth_raw_b4_sys_d0;
    reg  [7:0]  eth_raw_b4_sys_d1;
    reg  [7:0]  eth_raw_b5_sys_d0;
    reg  [7:0]  eth_raw_b5_sys_d1;
    reg  [7:0]  eth_raw_b6_sys_d0;
    reg  [7:0]  eth_raw_b6_sys_d1;
    reg  [7:0]  eth_raw_b7_sys_d0;
    reg  [7:0]  eth_raw_b7_sys_d1;
    reg  [7:0]  eth_raw_b8_sys_d0;
    reg  [7:0]  eth_raw_b8_sys_d1;
    reg  [7:0]  eth_raw_b9_sys_d0;
    reg  [7:0]  eth_raw_b9_sys_d1;
    reg  [7:0]  eth_raw_b10_sys_d0;
    reg  [7:0]  eth_raw_b10_sys_d1;
    reg  [7:0]  eth_raw_b11_sys_d0;
    reg  [7:0]  eth_raw_b11_sys_d1;
    reg         eth_rx_pkt_seen_sys_d0;
    reg         eth_rx_pkt_seen_sys_d1;
    reg  [15:0] eth_rx_last_len_sys_d0;
    reg  [15:0] eth_rx_last_len_sys_d1;
    reg  [7:0]  eth_rx_last_data_sys_d0;
    reg  [7:0]  eth_rx_last_data_sys_d1;
    reg  [7:0]  eth_tx_clk_mon_sys_d0;
    reg  [7:0]  eth_tx_clk_mon_sys_d1;
    reg         udp_tx_pending_sys_d0;
    reg         udp_tx_pending_sys_d1;
    reg         udp_tx_active_sys_d0;
    reg         udp_tx_active_sys_d1;
    reg         eth_tx_launch_toggle_sys_d0;
    reg         eth_tx_launch_toggle_sys_d1;
    reg         eth_tx_done_toggle_sys_d0;
    reg         eth_tx_done_toggle_sys_d1;
    reg         eth_beacon_toggle_sys_d0;
    reg         eth_beacon_toggle_sys_d1;
    reg  [7:0]  eth_last_tx_kind_sys_d0;
    reg  [7:0]  eth_last_tx_kind_sys_d1;
    reg  [15:0] eth_last_tx_len_sys_d0;
    reg  [15:0] eth_last_tx_len_sys_d1;
    reg  [7:0]  eth_dbg_rx_pkt_cnt;
    reg  [7:0]  eth_dbg_raw_rx_cnt;
    reg  [7:0]  eth_dbg_tx_launch_cnt;
    reg  [7:0]  eth_dbg_tx_done_cnt;
    reg  [7:0]  eth_dbg_beacon_cnt;
    wire        rec_pkt_done;

    // LED[3] keeps a visible heartbeat while LED[2:0] expose the current demo mode.
    assign LED = {((cnt1 <= 13'd4095) ? 1'b1 : 1'b0), algo_mode_dbg};

    // Ethernet clock forwarding is excluded from the video-only signoff netlist
    // because the eLinx packer cannot consume the Quartus DDIO IO atom there.
    generate
        if (!BOARD_VIDEO_ONLY) begin : g_gtx_clk_fwd
            // Forward a phase-shifted 125 MHz clock to the PHY so the external
            // sample edge lands near the center of the GMII data eye.
            altddio_out #(
                .width(1),
                .intended_device_family("Stratix"),
                .lpm_type("altddio_out"),
                .power_up_high("OFF")
            ) u_gtx_clk_fwd (
                .datain_h  (1'b1),
                .datain_l  (1'b0),
                .outclock  (clk_125MHz_tx_shift),
                .outclocken(1'b1),
                .aset      (1'b0),
                .aclr      (1'b0),
                .sset      (1'b0),
                .sclr      (1'b0),
                .oe        (1'b1),
                .dataout   (GTX_CLK),
                .oe_out    ()
            );
        end
        else begin : g_gtx_clk_static
            // Keep the PHY transmit clock pin quiet when Ethernet is outside
            // the board-facing video signoff boundary.
            assign GTX_CLK = 1'b0;
        end
    endgenerate
    assign eth_tx_ctl = BOARD_VIDEO_ONLY ? 1'b0 : eth_tx_ctl_udp;
    assign eth_txd = BOARD_VIDEO_ONLY ? 8'h00 : eth_txd_udp;
    assign eth_rst_n = BOARD_VIDEO_ONLY ? sys_rst_n : eth_rst_n_udp;
    assign rec_en = BOARD_VIDEO_ONLY ? 1'b0 : rec_en_udp;
    assign rec_data = BOARD_VIDEO_ONLY ? 8'd0 : rec_data_udp;
    assign rec_byte_num = BOARD_VIDEO_ONLY ? 16'd0 : rec_byte_num_udp;
    assign tx_req = BOARD_VIDEO_ONLY ? 1'b0 : tx_req_udp;
    assign tx_done = BOARD_VIDEO_ONLY ? 1'b0 : tx_done_udp;
    assign eth_tx_er  = 1'b0;
    assign rec_pkt_done = eth_rx_rec_en_d & ~rec_en;

    assign CMOS_PCLK    = vga_hsync ;
    assign CMOS_SCL    = vga_vsync;

    always @(posedge sys_clk)begin
        if(!sys_rst_n) cnt<=0;
        else cnt<=cnt+11'd1;
    end
    always @(posedge sys_clk)begin
        if(!sys_rst_n) cnt1<=0;
        else if(cnt==11'd2047) cnt1<=cnt1+13'd1;
    end

    always @(posedge eth_rxc or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            eth_rx_rec_en_d <= 1'b0;
            eth_rx_pkt_seen <= 1'b0;
            eth_rx_last_data <= 8'd0;
            eth_rx_last_len <= 16'd0;
            eth_rx_ctl_d <= 1'b0;
            eth_raw_rx_toggle_rx <= 1'b0;
            eth_raw_byte_idx_rx <= 4'd0;
            eth_raw_b0_rx <= 8'd0;
            eth_raw_b1_rx <= 8'd0;
            eth_raw_b2_rx <= 8'd0;
            eth_raw_b3_rx <= 8'd0;
            eth_raw_b4_rx <= 8'd0;
            eth_raw_b5_rx <= 8'd0;
            eth_raw_b6_rx <= 8'd0;
            eth_raw_b7_rx <= 8'd0;
            eth_raw_b8_rx <= 8'd0;
            eth_raw_b9_rx <= 8'd0;
            eth_raw_b10_rx <= 8'd0;
            eth_raw_b11_rx <= 8'd0;
            eth_rx_pkt_toggle_rx <= 1'b0;
            udp_reply_toggle_rx <= 1'b0;
            udp_reply_len_rx <= 16'd0;
            udp_reply_last_data_rx <= 8'd0;
        end
        else if(BOARD_VIDEO_ONLY) begin
            eth_rx_rec_en_d <= 1'b0;
            eth_rx_pkt_seen <= 1'b0;
            eth_rx_last_data <= 8'd0;
            eth_rx_last_len <= 16'd0;
            eth_rx_ctl_d <= 1'b0;
            eth_raw_rx_toggle_rx <= 1'b0;
            eth_raw_byte_idx_rx <= 4'd0;
            eth_raw_b0_rx <= 8'd0;
            eth_raw_b1_rx <= 8'd0;
            eth_raw_b2_rx <= 8'd0;
            eth_raw_b3_rx <= 8'd0;
            eth_raw_b4_rx <= 8'd0;
            eth_raw_b5_rx <= 8'd0;
            eth_raw_b6_rx <= 8'd0;
            eth_raw_b7_rx <= 8'd0;
            eth_raw_b8_rx <= 8'd0;
            eth_raw_b9_rx <= 8'd0;
            eth_raw_b10_rx <= 8'd0;
            eth_raw_b11_rx <= 8'd0;
            eth_rx_pkt_toggle_rx <= 1'b0;
            udp_reply_toggle_rx <= 1'b0;
            udp_reply_len_rx <= 16'd0;
            udp_reply_last_data_rx <= 8'd0;
        end
        else begin
            eth_rx_ctl_d <= eth_rx_ctl;
            eth_rx_rec_en_d <= rec_en;
            if(rec_en) begin
                eth_rx_last_data <= rec_data;
            end
            if(!eth_rx_ctl_d && eth_rx_ctl) begin
                eth_raw_rx_toggle_rx <= ~eth_raw_rx_toggle_rx;
                eth_raw_byte_idx_rx <= 4'd1;
                eth_raw_b0_rx <= eth_rxd;
            end
            else if(eth_rx_ctl && (eth_raw_byte_idx_rx < 4'd12)) begin
                case(eth_raw_byte_idx_rx)
                    4'd1:  eth_raw_b1_rx <= eth_rxd;
                    4'd2:  eth_raw_b2_rx <= eth_rxd;
                    4'd3:  eth_raw_b3_rx <= eth_rxd;
                    4'd4:  eth_raw_b4_rx <= eth_rxd;
                    4'd5:  eth_raw_b5_rx <= eth_rxd;
                    4'd6:  eth_raw_b6_rx <= eth_rxd;
                    4'd7:  eth_raw_b7_rx <= eth_rxd;
                    4'd8:  eth_raw_b8_rx <= eth_rxd;
                    4'd9:  eth_raw_b9_rx <= eth_rxd;
                    4'd10: eth_raw_b10_rx <= eth_rxd;
                    4'd11: eth_raw_b11_rx <= eth_rxd;
                    default: begin end
                endcase
                eth_raw_byte_idx_rx <= eth_raw_byte_idx_rx + 4'd1;
            end
            else if(!eth_rx_ctl) begin
                eth_raw_byte_idx_rx <= 4'd0;
            end

            if(rec_pkt_done) begin
                eth_rx_pkt_seen <= ~eth_rx_pkt_seen;
                eth_rx_last_len <= rec_byte_num;
                eth_rx_pkt_toggle_rx <= ~eth_rx_pkt_toggle_rx;
                if((rec_byte_num != 16'd0) && (rec_byte_num <= UDP_LOOPBACK_MAX_BYTES)) begin
                    udp_reply_len_rx <= rec_byte_num;
                    udp_reply_last_data_rx <= eth_rx_last_data;
                    udp_reply_toggle_rx <= ~udp_reply_toggle_rx;
                end
            end
        end
    end

    always @(posedge clk_125MHz or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            eth_tx_clk_mon <= 8'd0;
            udp_reply_toggle_tx_d0 <= 1'b0;
            udp_reply_toggle_tx_d1 <= 1'b0;
            udp_reply_len_tx_d0 <= 16'd0;
            udp_reply_len_tx_d1 <= 16'd0;
            udp_reply_last_data_tx_d0 <= 8'd0;
            udp_reply_last_data_tx_d1 <= 8'd0;
            udp_reply_len_hold <= 16'd0;
            udp_reply_last_data_hold <= 8'd0;
            udp_tx_start_en <= 1'b0;
            udp_tx_byte_num <= 16'd0;
            udp_tx_data <= 8'd0;
            udp_tx_pending <= 1'b0;
            udp_tx_active <= 1'b0;
            udp_tx_byte_idx <= 2'd0;
            udp_beacon_cnt <= 27'd0;
            eth_tx_launch_toggle_tx <= 1'b0;
            eth_tx_done_toggle_tx <= 1'b0;
            eth_beacon_toggle_tx <= 1'b0;
            eth_last_tx_kind_tx <= 8'd0;
            eth_last_tx_len_tx <= 16'd0;
        end
        else if(BOARD_VIDEO_ONLY) begin
            eth_tx_clk_mon <= 8'd0;
            udp_reply_toggle_tx_d0 <= 1'b0;
            udp_reply_toggle_tx_d1 <= 1'b0;
            udp_reply_len_tx_d0 <= 16'd0;
            udp_reply_len_tx_d1 <= 16'd0;
            udp_reply_last_data_tx_d0 <= 8'd0;
            udp_reply_last_data_tx_d1 <= 8'd0;
            udp_reply_len_hold <= 16'd0;
            udp_reply_last_data_hold <= 8'd0;
            udp_tx_start_en <= 1'b0;
            udp_tx_byte_num <= 16'd0;
            udp_tx_data <= 8'd0;
            udp_tx_pending <= 1'b0;
            udp_tx_active <= 1'b0;
            udp_tx_byte_idx <= 2'd0;
            udp_beacon_cnt <= 27'd0;
            eth_tx_launch_toggle_tx <= 1'b0;
            eth_tx_done_toggle_tx <= 1'b0;
            eth_beacon_toggle_tx <= 1'b0;
            eth_last_tx_kind_tx <= 8'd0;
            eth_last_tx_len_tx <= 16'd0;
        end
        else begin
            eth_tx_clk_mon <= eth_tx_clk_mon + 8'd1;
            udp_reply_toggle_tx_d0 <= udp_reply_toggle_rx;
            udp_reply_toggle_tx_d1 <= udp_reply_toggle_tx_d0;
            udp_reply_len_tx_d0 <= udp_reply_len_rx;
            udp_reply_len_tx_d1 <= udp_reply_len_tx_d0;
            udp_reply_last_data_tx_d0 <= udp_reply_last_data_rx;
            udp_reply_last_data_tx_d1 <= udp_reply_last_data_tx_d0;
            udp_tx_start_en <= 1'b0;

            if(ENABLE_UDP_DIAG_TX) begin
                if(udp_beacon_cnt == 27'd124999999)
                    udp_beacon_cnt <= 27'd0;
                else
                    udp_beacon_cnt <= udp_beacon_cnt + 27'd1;

                if((udp_reply_toggle_tx_d1 ^ udp_reply_toggle_tx_d0) && !udp_tx_pending && !udp_tx_active) begin
                    udp_reply_len_hold <= udp_reply_len_tx_d1;
                    udp_reply_last_data_hold <= udp_reply_last_data_tx_d1;
                    udp_tx_byte_num <= 16'd4;
                    udp_tx_data <= 8'hE1;
                    udp_tx_byte_idx <= 2'd1;
                    udp_tx_pending <= 1'b1;
                    eth_tx_launch_toggle_tx <= ~eth_tx_launch_toggle_tx;
                    eth_last_tx_kind_tx <= 8'hE1;
                    eth_last_tx_len_tx <= udp_reply_len_tx_d1;
                end
                else if((udp_beacon_cnt == 27'd124999999) && !udp_tx_pending && !udp_tx_active) begin
                    udp_reply_len_hold <= 16'hBEEF;
                    udp_reply_last_data_hold <= 8'hA5;
                    udp_tx_byte_num <= 16'd4;
                    udp_tx_data <= 8'hE2;
                    udp_tx_byte_idx <= 2'd1;
                    udp_tx_pending <= 1'b1;
                    eth_tx_launch_toggle_tx <= ~eth_tx_launch_toggle_tx;
                    eth_beacon_toggle_tx <= ~eth_beacon_toggle_tx;
                    eth_last_tx_kind_tx <= 8'hE2;
                    eth_last_tx_len_tx <= 16'hBEEF;
                end

                if(udp_tx_pending && !udp_tx_active)
                    udp_tx_start_en <= 1'b1;

                if(tx_req) begin
                    udp_tx_start_en <= 1'b0;
                    udp_tx_pending <= 1'b0;
                    udp_tx_active <= 1'b1;
                    case(udp_tx_byte_idx)
                        2'd1: begin
                            udp_tx_data <= udp_reply_len_hold[7:0];
                            udp_tx_byte_idx <= 2'd2;
                        end
                        2'd2: begin
                            udp_tx_data <= udp_reply_len_hold[15:8];
                            udp_tx_byte_idx <= 2'd3;
                        end
                        default: begin
                            udp_tx_data <= udp_reply_last_data_hold;
                            udp_tx_byte_idx <= 2'd0;
                        end
                    endcase
                end

                if(tx_done) begin
                    udp_tx_start_en <= 1'b0;
                    udp_tx_active <= 1'b0;
                    udp_tx_byte_idx <= 2'd0;
                    eth_tx_done_toggle_tx <= ~eth_tx_done_toggle_tx;
                end
            end
            else begin
                udp_beacon_cnt <= 27'd0;
                udp_tx_byte_num <= 16'd0;
                udp_tx_data <= 8'd0;
                udp_tx_pending <= 1'b0;
                udp_tx_active <= 1'b0;
                udp_tx_byte_idx <= 2'd0;
            end
        end
    end

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            eth_rx_pkt_toggle_sys_d0 <= 1'b0;
            eth_rx_pkt_toggle_sys_d1 <= 1'b0;
            eth_raw_rx_toggle_sys_d0 <= 1'b0;
            eth_raw_rx_toggle_sys_d1 <= 1'b0;
            eth_raw_b0_sys_d0 <= 8'd0;
            eth_raw_b0_sys_d1 <= 8'd0;
            eth_raw_b1_sys_d0 <= 8'd0;
            eth_raw_b1_sys_d1 <= 8'd0;
            eth_raw_b2_sys_d0 <= 8'd0;
            eth_raw_b2_sys_d1 <= 8'd0;
            eth_raw_b3_sys_d0 <= 8'd0;
            eth_raw_b3_sys_d1 <= 8'd0;
            eth_raw_b4_sys_d0 <= 8'd0;
            eth_raw_b4_sys_d1 <= 8'd0;
            eth_raw_b5_sys_d0 <= 8'd0;
            eth_raw_b5_sys_d1 <= 8'd0;
            eth_raw_b6_sys_d0 <= 8'd0;
            eth_raw_b6_sys_d1 <= 8'd0;
            eth_raw_b7_sys_d0 <= 8'd0;
            eth_raw_b7_sys_d1 <= 8'd0;
            eth_raw_b8_sys_d0 <= 8'd0;
            eth_raw_b8_sys_d1 <= 8'd0;
            eth_raw_b9_sys_d0 <= 8'd0;
            eth_raw_b9_sys_d1 <= 8'd0;
            eth_raw_b10_sys_d0 <= 8'd0;
            eth_raw_b10_sys_d1 <= 8'd0;
            eth_raw_b11_sys_d0 <= 8'd0;
            eth_raw_b11_sys_d1 <= 8'd0;
            eth_rx_pkt_seen_sys_d0 <= 1'b0;
            eth_rx_pkt_seen_sys_d1 <= 1'b0;
            eth_rx_last_len_sys_d0 <= 16'd0;
            eth_rx_last_len_sys_d1 <= 16'd0;
            eth_rx_last_data_sys_d0 <= 8'd0;
            eth_rx_last_data_sys_d1 <= 8'd0;
            eth_tx_clk_mon_sys_d0 <= 8'd0;
            eth_tx_clk_mon_sys_d1 <= 8'd0;
            udp_tx_pending_sys_d0 <= 1'b0;
            udp_tx_pending_sys_d1 <= 1'b0;
            udp_tx_active_sys_d0 <= 1'b0;
            udp_tx_active_sys_d1 <= 1'b0;
            eth_tx_launch_toggle_sys_d0 <= 1'b0;
            eth_tx_launch_toggle_sys_d1 <= 1'b0;
            eth_tx_done_toggle_sys_d0 <= 1'b0;
            eth_tx_done_toggle_sys_d1 <= 1'b0;
            eth_beacon_toggle_sys_d0 <= 1'b0;
            eth_beacon_toggle_sys_d1 <= 1'b0;
            eth_last_tx_kind_sys_d0 <= 8'd0;
            eth_last_tx_kind_sys_d1 <= 8'd0;
            eth_last_tx_len_sys_d0 <= 16'd0;
            eth_last_tx_len_sys_d1 <= 16'd0;
            eth_dbg_rx_pkt_cnt <= 8'd0;
            eth_dbg_raw_rx_cnt <= 8'd0;
            eth_dbg_tx_launch_cnt <= 8'd0;
            eth_dbg_tx_done_cnt <= 8'd0;
            eth_dbg_beacon_cnt <= 8'd0;
        end
        else if(BOARD_VIDEO_ONLY) begin
            eth_rx_pkt_toggle_sys_d0 <= 1'b0;
            eth_rx_pkt_toggle_sys_d1 <= 1'b0;
            eth_raw_rx_toggle_sys_d0 <= 1'b0;
            eth_raw_rx_toggle_sys_d1 <= 1'b0;
            eth_raw_b0_sys_d0 <= 8'd0;
            eth_raw_b0_sys_d1 <= 8'd0;
            eth_raw_b1_sys_d0 <= 8'd0;
            eth_raw_b1_sys_d1 <= 8'd0;
            eth_raw_b2_sys_d0 <= 8'd0;
            eth_raw_b2_sys_d1 <= 8'd0;
            eth_raw_b3_sys_d0 <= 8'd0;
            eth_raw_b3_sys_d1 <= 8'd0;
            eth_raw_b4_sys_d0 <= 8'd0;
            eth_raw_b4_sys_d1 <= 8'd0;
            eth_raw_b5_sys_d0 <= 8'd0;
            eth_raw_b5_sys_d1 <= 8'd0;
            eth_raw_b6_sys_d0 <= 8'd0;
            eth_raw_b6_sys_d1 <= 8'd0;
            eth_raw_b7_sys_d0 <= 8'd0;
            eth_raw_b7_sys_d1 <= 8'd0;
            eth_raw_b8_sys_d0 <= 8'd0;
            eth_raw_b8_sys_d1 <= 8'd0;
            eth_raw_b9_sys_d0 <= 8'd0;
            eth_raw_b9_sys_d1 <= 8'd0;
            eth_raw_b10_sys_d0 <= 8'd0;
            eth_raw_b10_sys_d1 <= 8'd0;
            eth_raw_b11_sys_d0 <= 8'd0;
            eth_raw_b11_sys_d1 <= 8'd0;
            eth_rx_pkt_seen_sys_d0 <= 1'b0;
            eth_rx_pkt_seen_sys_d1 <= 1'b0;
            eth_rx_last_len_sys_d0 <= 16'd0;
            eth_rx_last_len_sys_d1 <= 16'd0;
            eth_rx_last_data_sys_d0 <= 8'd0;
            eth_rx_last_data_sys_d1 <= 8'd0;
            eth_tx_clk_mon_sys_d0 <= 8'd0;
            eth_tx_clk_mon_sys_d1 <= 8'd0;
            udp_tx_pending_sys_d0 <= 1'b0;
            udp_tx_pending_sys_d1 <= 1'b0;
            udp_tx_active_sys_d0 <= 1'b0;
            udp_tx_active_sys_d1 <= 1'b0;
            eth_tx_launch_toggle_sys_d0 <= 1'b0;
            eth_tx_launch_toggle_sys_d1 <= 1'b0;
            eth_tx_done_toggle_sys_d0 <= 1'b0;
            eth_tx_done_toggle_sys_d1 <= 1'b0;
            eth_beacon_toggle_sys_d0 <= 1'b0;
            eth_beacon_toggle_sys_d1 <= 1'b0;
            eth_last_tx_kind_sys_d0 <= 8'd0;
            eth_last_tx_kind_sys_d1 <= 8'd0;
            eth_last_tx_len_sys_d0 <= 16'd0;
            eth_last_tx_len_sys_d1 <= 16'd0;
            eth_dbg_rx_pkt_cnt <= 8'd0;
            eth_dbg_raw_rx_cnt <= 8'd0;
            eth_dbg_tx_launch_cnt <= 8'd0;
            eth_dbg_tx_done_cnt <= 8'd0;
            eth_dbg_beacon_cnt <= 8'd0;
        end
        else begin
            eth_rx_pkt_toggle_sys_d0 <= eth_rx_pkt_toggle_rx;
            eth_rx_pkt_toggle_sys_d1 <= eth_rx_pkt_toggle_sys_d0;
            eth_raw_rx_toggle_sys_d0 <= eth_raw_rx_toggle_rx;
            eth_raw_rx_toggle_sys_d1 <= eth_raw_rx_toggle_sys_d0;
            eth_raw_b0_sys_d0 <= eth_raw_b0_rx;
            eth_raw_b0_sys_d1 <= eth_raw_b0_sys_d0;
            eth_raw_b1_sys_d0 <= eth_raw_b1_rx;
            eth_raw_b1_sys_d1 <= eth_raw_b1_sys_d0;
            eth_raw_b2_sys_d0 <= eth_raw_b2_rx;
            eth_raw_b2_sys_d1 <= eth_raw_b2_sys_d0;
            eth_raw_b3_sys_d0 <= eth_raw_b3_rx;
            eth_raw_b3_sys_d1 <= eth_raw_b3_sys_d0;
            eth_raw_b4_sys_d0 <= eth_raw_b4_rx;
            eth_raw_b4_sys_d1 <= eth_raw_b4_sys_d0;
            eth_raw_b5_sys_d0 <= eth_raw_b5_rx;
            eth_raw_b5_sys_d1 <= eth_raw_b5_sys_d0;
            eth_raw_b6_sys_d0 <= eth_raw_b6_rx;
            eth_raw_b6_sys_d1 <= eth_raw_b6_sys_d0;
            eth_raw_b7_sys_d0 <= eth_raw_b7_rx;
            eth_raw_b7_sys_d1 <= eth_raw_b7_sys_d0;
            eth_raw_b8_sys_d0 <= eth_raw_b8_rx;
            eth_raw_b8_sys_d1 <= eth_raw_b8_sys_d0;
            eth_raw_b9_sys_d0 <= eth_raw_b9_rx;
            eth_raw_b9_sys_d1 <= eth_raw_b9_sys_d0;
            eth_raw_b10_sys_d0 <= eth_raw_b10_rx;
            eth_raw_b10_sys_d1 <= eth_raw_b10_sys_d0;
            eth_raw_b11_sys_d0 <= eth_raw_b11_rx;
            eth_raw_b11_sys_d1 <= eth_raw_b11_sys_d0;
            eth_rx_pkt_seen_sys_d0 <= eth_rx_pkt_seen;
            eth_rx_pkt_seen_sys_d1 <= eth_rx_pkt_seen_sys_d0;
            eth_rx_last_len_sys_d0 <= eth_rx_last_len;
            eth_rx_last_len_sys_d1 <= eth_rx_last_len_sys_d0;
            eth_rx_last_data_sys_d0 <= eth_rx_last_data;
            eth_rx_last_data_sys_d1 <= eth_rx_last_data_sys_d0;
            eth_tx_clk_mon_sys_d0 <= eth_tx_clk_mon;
            eth_tx_clk_mon_sys_d1 <= eth_tx_clk_mon_sys_d0;
            udp_tx_pending_sys_d0 <= udp_tx_pending;
            udp_tx_pending_sys_d1 <= udp_tx_pending_sys_d0;
            udp_tx_active_sys_d0 <= udp_tx_active;
            udp_tx_active_sys_d1 <= udp_tx_active_sys_d0;
            eth_tx_launch_toggle_sys_d0 <= eth_tx_launch_toggle_tx;
            eth_tx_launch_toggle_sys_d1 <= eth_tx_launch_toggle_sys_d0;
            eth_tx_done_toggle_sys_d0 <= eth_tx_done_toggle_tx;
            eth_tx_done_toggle_sys_d1 <= eth_tx_done_toggle_sys_d0;
            eth_beacon_toggle_sys_d0 <= eth_beacon_toggle_tx;
            eth_beacon_toggle_sys_d1 <= eth_beacon_toggle_sys_d0;
            eth_last_tx_kind_sys_d0 <= eth_last_tx_kind_tx;
            eth_last_tx_kind_sys_d1 <= eth_last_tx_kind_sys_d0;
            eth_last_tx_len_sys_d0 <= eth_last_tx_len_tx;
            eth_last_tx_len_sys_d1 <= eth_last_tx_len_sys_d0;

            if(eth_rx_pkt_toggle_sys_d1 ^ eth_rx_pkt_toggle_sys_d0)
                eth_dbg_rx_pkt_cnt <= eth_dbg_rx_pkt_cnt + 8'd1;
            if(eth_raw_rx_toggle_sys_d1 ^ eth_raw_rx_toggle_sys_d0)
                eth_dbg_raw_rx_cnt <= eth_dbg_raw_rx_cnt + 8'd1;
            if(eth_tx_launch_toggle_sys_d1 ^ eth_tx_launch_toggle_sys_d0)
                eth_dbg_tx_launch_cnt <= eth_dbg_tx_launch_cnt + 8'd1;
            if(eth_tx_done_toggle_sys_d1 ^ eth_tx_done_toggle_sys_d0)
                eth_dbg_tx_done_cnt <= eth_dbg_tx_done_cnt + 8'd1;
            if(eth_beacon_toggle_sys_d1 ^ eth_beacon_toggle_sys_d0)
                eth_dbg_beacon_cnt <= eth_dbg_beacon_cnt + 8'd1;
        end
    end
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
        .c1(clk_25M),						//output c1
        .c2(clk_125MHz_tx_shift)
    );

    // The board signoff can be done in a video-only mode so the VGA image
    // pipeline is timed independently from the 125 MHz Ethernet path.
    generate
        if (!BOARD_VIDEO_ONLY) begin : g_eth_udp_loop
            eth_udp_loop u_eth_udp_loop(
                .sys_clk      (clk_125MHz),
                .sys_rst_n    (sys_rst_n),
                .eth_rxc      (eth_rxc),
                .eth_rx_ctl   (eth_rx_ctl),
                .eth_rxd      (eth_rxd),
                .eth_txc      (eth_txc),
                .eth_tx_ctl   (eth_tx_ctl_udp),
                .eth_txd      (eth_txd_udp),
                .eth_rst_n    (eth_rst_n_udp),
                .rec_en       (rec_en_udp),
                .rec_data     (rec_data_udp),
                .rec_byte_num (rec_byte_num_udp),
                .tx_req       (tx_req_udp),
                .tx_done      (tx_done_udp),
                .tx_start_en  (udp_tx_start_en),
                .tx_byte_num  (udp_tx_byte_num),
                .tx_data      (udp_tx_data)
            );
        end
    endgenerate
    // Drive the on-board VGA path directly from the stream-demo top so the
    // image-processing chain is present in the board-facing netlist.
    vga_top u_vga_top(
        .clk_25m      ( clk_25M      ),
        .rst_n        ( sys_rst_n    ),
        .key_next     ( touch_key    ),
        .key_prev     ( i_Key_GBCR   ),
        .key_reset    ( i_Key_ANAR   ),
        .algo_mode_dbg( algo_mode_dbg),
        .vga_clk      ( vga_clk      ),
        .vga_hs       ( vga_hsync    ),
        .vga_vs       ( vga_vsync    ),
        .vga_r        ( vga_r        ),
        .vga_g        ( vga_g        ),
        .vga_b        ( vga_b        )
    );

    // MDIO is part of Ethernet bring-up, so keep it out of the video-only
    // signoff netlist to avoid unrelated generated-clock timing warnings.
    generate
        if (!BOARD_VIDEO_ONLY) begin : g_mdio_rw_test
            mdio_rw_test u_mdio_rw_test(
                .sys_clk    (sys_clk),
                .sys_rst_n  (sys_rst_n),
                .eth_mdc    (eth_mdc),
                .eth_mdio   (eth_mdio),
                .i_Key_GBCR (i_Key_GBCR),
                .i_Key_ANAR (i_Key_ANAR),
                .touch_key  (touch_key),
                .led        (EthSpeedLED)
            );
        end
        else begin : g_mdio_static
            // Hold MDC quiet and release the bidirectional MDIO pin while the
            // PHY management interface is outside this signoff boundary.
            assign eth_mdc = 1'b0;
            assign eth_mdio = 1'bz;
            assign EthSpeedLED = 2'b00;
        end
    endgenerate
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
    wire eth_dbg_flag;
    wire eth_raw_dbg_flag;
    assign wr_flag=uart_cmd_strobe&&rec_uart_data=='h31;
    assign rd_flag=uart_cmd_strobe&&rec_uart_data=='h32;
    assign tx_test_flag=uart_cmd_strobe&&rec_uart_data=='h33;
    assign dbg_tx_flag=uart_cmd_strobe&&rec_uart_data=='h34;
    assign eth_dbg_flag=uart_cmd_strobe&&rec_uart_data=='h35;
    assign eth_raw_dbg_flag=uart_cmd_strobe&&rec_uart_data=='h36;

    localparam SDRAM_BURST_WORDS = 10'd8;
    localparam SDRAM_BASE_ADDR = 24'd0;
    localparam SDRAM_END_ADDR = 24'd63;

    wire sdram_init_done;
    wire sdram_init_done_live;
    reg [15:0] sdram_fifo_wr_data;
    reg sdram_fifo_wr_req;
    reg sdram_fifo_wr_load;

    wire [15:0] sdram_fifo_rd_data;
    wire [15:0] sdram_fifo_rd_data_live;
    reg sdram_fifo_rd_req;
    reg sdram_fifo_rd_load;
    wire sdram_rdempty;
    wire sdram_rdempty_live;
    wire [9:0] sdram_rdusedw;
    wire [9:0] sdram_rdusedw_live;
    wire dbg_sdram_wr_req;
    wire dbg_sdram_wr_ack;
    wire dbg_sdram_rd_req;
    wire dbg_sdram_rd_ack;
    wire dbg_sdram_wr_req_live;
    wire dbg_sdram_wr_ack_live;
    wire dbg_sdram_rd_req_live;
    wire dbg_sdram_rd_ack_live;
    wire O_sdram_clk_live;
    wire O_sdram_cke_live;
    wire O_sdram_cs_n_live;
    wire O_sdram_ras_n_live;
    wire O_sdram_cas_n_live;
    wire O_sdram_we_n_live;
    wire [1:0] O_sdram_bank_live;
    wire [12:0] O_sdram_addr_live;
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

    assign sdram_init_done = BOARD_VIDEO_ONLY ? 1'b0 : sdram_init_done_live;
    assign sdram_fifo_rd_data = BOARD_VIDEO_ONLY ? 16'd0 : sdram_fifo_rd_data_live;
    assign sdram_rdempty = BOARD_VIDEO_ONLY ? 1'b1 : sdram_rdempty_live;
    assign sdram_rdusedw = BOARD_VIDEO_ONLY ? 10'd0 : sdram_rdusedw_live;
    assign dbg_sdram_wr_req = BOARD_VIDEO_ONLY ? 1'b0 : dbg_sdram_wr_req_live;
    assign dbg_sdram_wr_ack = BOARD_VIDEO_ONLY ? 1'b0 : dbg_sdram_wr_ack_live;
    assign dbg_sdram_rd_req = BOARD_VIDEO_ONLY ? 1'b0 : dbg_sdram_rd_req_live;
    assign dbg_sdram_rd_ack = BOARD_VIDEO_ONLY ? 1'b0 : dbg_sdram_rd_ack_live;
    assign O_sdram_clk = BOARD_VIDEO_ONLY ? 1'b0 : O_sdram_clk_live;
    assign O_sdram_cke = BOARD_VIDEO_ONLY ? 1'b0 : O_sdram_cke_live;
    assign O_sdram_cs_n = BOARD_VIDEO_ONLY ? 1'b1 : O_sdram_cs_n_live;
    assign O_sdram_ras_n = BOARD_VIDEO_ONLY ? 1'b1 : O_sdram_ras_n_live;
    assign O_sdram_cas_n = BOARD_VIDEO_ONLY ? 1'b1 : O_sdram_cas_n_live;
    assign O_sdram_we_n = BOARD_VIDEO_ONLY ? 1'b1 : O_sdram_we_n_live;
    assign O_sdram_bank = BOARD_VIDEO_ONLY ? 2'b00 : O_sdram_bank_live;
    assign O_sdram_addr = BOARD_VIDEO_ONLY ? 13'd0 : O_sdram_addr_live;

    always @(posedge sys_clk)begin
        if(!sys_rst_n)begin
            sdram_fifo_wr_req<=1'b0;
            sdram_fifo_wr_load<=1'b0;
            sdram_fifo_wr_data<='d0;
            sdram_wr_state<='d0;
            wr_cnt<='d0;
            wr_prep_cnt<='d0;
        end
        else if(BOARD_VIDEO_ONLY) begin
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
        else if(BOARD_VIDEO_ONLY) begin
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
        else if(BOARD_VIDEO_ONLY) begin
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
                    else if(eth_dbg_flag) begin
                        sdram_read_fill_en<=1'b0;
                        test_tx_cnt<='d0;
                        uart_tx_phase<='d0;
                        sdram_rd_state<='d10;
                    end
                    else if(eth_raw_dbg_flag) begin
                        sdram_read_fill_en<=1'b0;
                        test_tx_cnt<='d0;
                        uart_tx_phase<='d0;
                        sdram_rd_state<='d11;
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
                'd10:begin
                    uart_tx_en<=1'b0;
                    if(test_tx_cnt<'d16) begin
                        case (uart_tx_phase)
                            2'd0: begin
                                case (test_tx_cnt)
                                    4'd0  : uart_tx_data <= 8'hEE;
                                    4'd1  : uart_tx_data <= 8'h35;
                                    4'd2  : uart_tx_data <= {5'd0, EthSpeedLED, eth_rx_pkt_seen_sys_d1};
                                    4'd3  : uart_tx_data <= eth_tx_clk_mon_sys_d1;
                                    4'd4  : uart_tx_data <= eth_rx_last_len_sys_d1[7:0];
                                    4'd5  : uart_tx_data <= eth_rx_last_len_sys_d1[15:8];
                                    4'd6  : uart_tx_data <= eth_rx_last_data_sys_d1;
                                    4'd7  : uart_tx_data <= eth_dbg_rx_pkt_cnt;
                                    4'd8  : uart_tx_data <= eth_dbg_tx_launch_cnt;
                                    4'd9  : uart_tx_data <= eth_dbg_tx_done_cnt;
                                    4'd10 : uart_tx_data <= eth_dbg_beacon_cnt;
                                    4'd11 : uart_tx_data <= eth_last_tx_kind_sys_d1;
                                    4'd12 : uart_tx_data <= eth_last_tx_len_sys_d1[7:0];
                                    4'd13 : uart_tx_data <= eth_last_tx_len_sys_d1[15:8];
                                    4'd14 : uart_tx_data <= eth_dbg_raw_rx_cnt;
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
                'd11:begin
                    uart_tx_en<=1'b0;
                    if(test_tx_cnt<'d16) begin
                        case (uart_tx_phase)
                            2'd0: begin
                                case (test_tx_cnt)
                                    4'd0  : uart_tx_data <= 8'hEE;
                                    4'd1  : uart_tx_data <= 8'h36;
                                    4'd2  : uart_tx_data <= eth_dbg_raw_rx_cnt;
                                    4'd3  : uart_tx_data <= eth_raw_b0_sys_d1;
                                    4'd4  : uart_tx_data <= eth_raw_b1_sys_d1;
                                    4'd5  : uart_tx_data <= eth_raw_b2_sys_d1;
                                    4'd6  : uart_tx_data <= eth_raw_b3_sys_d1;
                                    4'd7  : uart_tx_data <= eth_raw_b4_sys_d1;
                                    4'd8  : uart_tx_data <= eth_raw_b5_sys_d1;
                                    4'd9  : uart_tx_data <= eth_raw_b6_sys_d1;
                                    4'd10 : uart_tx_data <= eth_raw_b7_sys_d1;
                                    4'd11 : uart_tx_data <= eth_raw_b8_sys_d1;
                                    4'd12 : uart_tx_data <= eth_raw_b9_sys_d1;
                                    4'd13 : uart_tx_data <= eth_raw_b10_sys_d1;
                                    4'd14 : uart_tx_data <= eth_raw_b11_sys_d1;
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

    generate
        if (!BOARD_VIDEO_ONLY) begin : g_sdram_top
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
        .O_fifo_rd_data      (sdram_fifo_rd_data_live),
        .I_fifo_rd_load      (sdram_fifo_rd_load),

        .I_rd_burst          (SDRAM_BURST_WORDS),
        .I_rd_saddr          (SDRAM_BASE_ADDR),
        .I_rd_eaddr          (SDRAM_END_ADDR),
        // 使能端口
        .I_sdram_rd_valid    (I_sdram_rd_valid),
        .I_sdram_pingpang_en (1'b0),
        .O_sdram_init_done   (sdram_init_done_live),
        // SDRAM 芯片接口
        .O_sdram_clk         (O_sdram_clk_live),
        .O_sdram_cke         (O_sdram_cke_live),
        .O_sdram_cs_n        (O_sdram_cs_n_live),
        .O_sdram_ras_n       (O_sdram_ras_n_live),
        .O_sdram_cas_n       (O_sdram_cas_n_live),
        .O_sdram_we_n        (O_sdram_we_n_live),
        .O_sdram_bank        (O_sdram_bank_live),
        .O_sdram_addr        (O_sdram_addr_live),
        .IO_sdram_dq         (IO_sdram_dq),
        .rdempty             (sdram_rdempty_live),
        .rdusedw             (sdram_rdusedw_live),
        .dbg_sdram_wr_req    (dbg_sdram_wr_req_live),
        .dbg_sdram_wr_ack    (dbg_sdram_wr_ack_live),
        .dbg_sdram_rd_req    (dbg_sdram_rd_req_live),
        .dbg_sdram_rd_ack    (dbg_sdram_rd_ack_live)
    );
        end
    endgenerate



endmodule
