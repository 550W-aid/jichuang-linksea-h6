`timescale 1ns / 1ps

module VP_video_tb;

    localparam integer TIMEOUT_NS = 5_000_000;

    reg         sys_clk;
    reg         sys_rst_n;
    reg         eth_rxc;
    reg         eth_rx_ctl;
    reg         eth_txc;
    reg  [7:0]  eth_rxd;
    wire        eth_tx_ctl;
    wire [7:0]  eth_txd;
    wire        GTX_CLK;
    wire        eth_rst_n;
    wire        eth_tx_er;
    reg         touch_key;
    reg         i_Key_GBCR;
    reg         i_Key_ANAR;
    tri         eth_mdio;
    wire        eth_mdc;
    wire [3:0]  LED;
    wire        O_sdram_clk;
    wire        O_sdram_cke;
    wire        O_sdram_cs_n;
    wire        O_sdram_ras_n;
    wire        O_sdram_cas_n;
    wire        O_sdram_we_n;
    wire [1:0]  O_sdram_bank;
    wire [12:0] O_sdram_addr;
    wire [15:0] IO_sdram_dq;
    wire        vga_clk;
    wire        vga_hsync;
    wire        vga_vsync;
    wire [7:0]  vga_r;
    wire [7:0]  vga_g;
    wire [7:0]  vga_b;
    reg         uart_rxd;
    wire        uart_txd;
    wire        CMOS_PCLK;
    wire        CMOS_SCL;

    integer vga_clk_edge_count;
    integer hsync_fall_count;
    integer nonzero_sample_count;
    reg     seen_nonzero;
    reg     gray_mismatch;
    reg     cmos_mismatch;
    time    first_nonzero_time;

    VP_Top dut (
        .sys_clk      (sys_clk),
        .sys_rst_n    (sys_rst_n),
        .LED          (LED),
        .eth_rxc      (eth_rxc),
        .eth_rx_ctl   (eth_rx_ctl),
        .eth_txc      (eth_txc),
        .eth_rxd      (eth_rxd),
        .eth_tx_ctl   (eth_tx_ctl),
        .eth_txd      (eth_txd),
        .GTX_CLK      (GTX_CLK),
        .eth_rst_n    (eth_rst_n),
        .eth_tx_er    (eth_tx_er),
        .touch_key    (touch_key),
        .i_Key_GBCR   (i_Key_GBCR),
        .i_Key_ANAR   (i_Key_ANAR),
        .eth_mdio     (eth_mdio),
        .eth_mdc      (eth_mdc),
        .O_sdram_clk  (O_sdram_clk),
        .O_sdram_cke  (O_sdram_cke),
        .O_sdram_cs_n (O_sdram_cs_n),
        .O_sdram_ras_n(O_sdram_ras_n),
        .O_sdram_cas_n(O_sdram_cas_n),
        .O_sdram_we_n (O_sdram_we_n),
        .O_sdram_bank (O_sdram_bank),
        .O_sdram_addr (O_sdram_addr),
        .IO_sdram_dq  (IO_sdram_dq),
        .vga_clk      (vga_clk),
        .vga_hsync    (vga_hsync),
        .vga_vsync    (vga_vsync),
        .vga_r        (vga_r),
        .vga_g        (vga_g),
        .vga_b        (vga_b),
        .uart_rxd     (uart_rxd),
        .uart_txd     (uart_txd),
        .CMOS_PCLK    (CMOS_PCLK),
        .CMOS_SCL     (CMOS_SCL)
    );

    initial begin
        sys_clk = 1'b0;
        forever #10 sys_clk = ~sys_clk;
    end

    initial begin
        sys_rst_n            = 1'b0;
        eth_rxc              = 1'b0;
        eth_rx_ctl           = 1'b0;
        eth_txc              = 1'b0;
        eth_rxd              = 8'd0;
        touch_key            = 1'b0;
        i_Key_GBCR           = 1'b0;
        i_Key_ANAR           = 1'b0;
        uart_rxd             = 1'b1;
        vga_clk_edge_count   = 0;
        hsync_fall_count     = 0;
        nonzero_sample_count = 0;
        seen_nonzero         = 1'b0;
        gray_mismatch        = 1'b0;
        cmos_mismatch        = 1'b0;
        first_nonzero_time   = 0;

        if ($test$plusargs("dump_vcd")) begin
            $dumpfile("VP_video_tb.vcd");
            $dumpvars(0, VP_video_tb);
        end

        #200;
        sys_rst_n = 1'b1;
    end

    always @(posedge vga_clk) begin
        if (sys_rst_n) begin
            vga_clk_edge_count = vga_clk_edge_count + 1;

            if ((vga_r != vga_g) || (vga_g != vga_b))
                gray_mismatch = 1'b1;

            if ((CMOS_PCLK !== vga_hsync) || (CMOS_SCL !== vga_vsync))
                cmos_mismatch = 1'b1;

            if ((vga_r != 8'd0) || (vga_g != 8'd0) || (vga_b != 8'd0)) begin
                nonzero_sample_count = nonzero_sample_count + 1;
                if (!seen_nonzero) begin
                    seen_nonzero       = 1'b1;
                    first_nonzero_time = $time;
                    $display("TB INFO: first non-zero pixel at %0t ns", first_nonzero_time);
                end
            end
        end
    end

    always @(negedge vga_hsync) begin
        if (sys_rst_n)
            hsync_fall_count = hsync_fall_count + 1;
    end

    initial begin
        #TIMEOUT_NS;

        if (vga_clk_edge_count < 100) begin
            $display("TB FAIL: vga_clk did not toggle enough times (%0d)", vga_clk_edge_count);
            $finish(1);
        end

        if (hsync_fall_count < 8) begin
            $display("TB FAIL: vga_hsync did not toggle enough times (%0d)", hsync_fall_count);
            $finish(1);
        end

        if (!seen_nonzero) begin
            $display("TB FAIL: did not observe any non-zero output pixel");
            $finish(1);
        end

        if (gray_mismatch) begin
            $display("TB FAIL: VGA output channels are not grayscale-aligned");
            $finish(1);
        end

        if (cmos_mismatch) begin
            $display("TB FAIL: CMOS mirror outputs do not match VGA sync");
            $finish(1);
        end

        $display("TB PASS: VP_Top video path active. vga_clk_edges=%0d, hsync_falls=%0d, nonzero_samples=%0d, first_nonzero_time=%0t",
                 vga_clk_edge_count, hsync_fall_count, nonzero_sample_count, first_nonzero_time);
        $finish;
    end

endmodule
