`timescale 1 ps / 1 ps

module VP_Top(
    input               sys_clk,
    input               sys_rst_n,

    output      [3:0]   LED,

    input               eth_rxc,
    input               eth_rx_ctl,
    input               eth_txc,
    input       [7:0]   eth_rxd,
    output              eth_tx_ctl,
    output      [7:0]   eth_txd,
    output              GTX_CLK,
    output              eth_rst_n,
    output              eth_tx_er,

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
    output      [7:0]   vga_r,
    output      [7:0]   vga_g,
    output      [7:0]   vga_b,

    input               uart_rxd,
    output              uart_txd,

    output              CMOS_PCLK,
    output              CMOS_SCL
);

    wire clk_25M;
    wire clk_125MHz;
    reg  [25:0] heartbeat_cnt;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            heartbeat_cnt <= 26'd0;
        else
            heartbeat_cnt <= heartbeat_cnt + 26'd1;
    end

    pll_1 u_pll_1 (
        .inclk0(sys_clk),
        .c0    (clk_125MHz),
        .c1    (clk_25M)
    );

    vga_top u_vga_top(
        .clk_25m (clk_25M),
        .rst_n   (sys_rst_n),
        .vga_clk (vga_clk),
        .vga_hs  (vga_hsync),
        .vga_vs  (vga_vsync),
        .vga_r   (vga_r),
        .vga_g   (vga_g),
        .vga_b   (vga_b)
    );

    assign LED[3] = heartbeat_cnt[25];
    assign LED[2] = heartbeat_cnt[24];
    assign LED[1] = heartbeat_cnt[23];
    assign LED[0] = sys_rst_n;

    assign CMOS_PCLK = vga_hsync;
    assign CMOS_SCL  = vga_vsync;

    // Ethernet is intentionally disabled for the image-processing timing build.
    assign GTX_CLK    = 1'b0;
    assign eth_tx_ctl = 1'b0;
    assign eth_txd    = 8'd0;
    assign eth_rst_n  = 1'b0;
    assign eth_tx_er  = 1'b0;
    assign eth_mdc    = 1'b0;
    assign eth_mdio   = 1'bz;

    // SDRAM is intentionally disabled for the image-processing timing build.
    assign O_sdram_clk   = 1'b0;
    assign O_sdram_cke   = 1'b0;
    assign O_sdram_cs_n  = 1'b1;
    assign O_sdram_ras_n = 1'b1;
    assign O_sdram_cas_n = 1'b1;
    assign O_sdram_we_n  = 1'b1;
    assign O_sdram_bank  = 2'b00;
    assign O_sdram_addr  = 13'd0;
    assign IO_sdram_dq   = 16'hzzzz;

    assign uart_txd = 1'b1;

    wire unused_ok;
    assign unused_ok = &{
        1'b0,
        eth_rxc,
        eth_rx_ctl,
        eth_txc,
        eth_rxd[0],
        touch_key,
        i_Key_GBCR,
        i_Key_ANAR,
        uart_rxd,
        clk_125MHz
    };

endmodule
