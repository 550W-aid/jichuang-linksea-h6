module link_sea_h6_bringup_elinx_top
(
    input  wire        SYS_50M,
    input  wire        FPGA_UART_RX,
    output wire        FPGA_UART_TX,
    input  wire [3:0]  KEY,
    output wire [3:0]  LED,
    output wire [15:0] VGA_D,
    output wire        VGA_HSYNC,
    output wire        VGA_VSYNC
);

    reg [15:0] por_count;
    wire       sys_rst_n;
    wire [4:0] vga_r;
    wire [5:0] vga_g;
    wire [4:0] vga_b;

    initial begin
        por_count = 16'd0;
    end

    always @(posedge SYS_50M) begin
        if (!por_count[15]) begin
            por_count <= por_count + 16'd1;
        end
    end

    assign sys_rst_n = por_count[15];
    assign VGA_D     = {vga_r, vga_g, vga_b};

    link_sea_h6_bringup_top #(
        .CLK_HZ(50_000_000),
        .UART_BAUD(115200)
    ) u_bringup_top (
        .sys_clk(SYS_50M),
        .sys_rst_n(sys_rst_n),
        .uart_rx_i(FPGA_UART_RX),
        .uart_tx_o(FPGA_UART_TX),
        .key_i(KEY),
        .led_o(LED),
        .vga_hsync_o(VGA_HSYNC),
        .vga_vsync_o(VGA_VSYNC),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b)
    );

endmodule
