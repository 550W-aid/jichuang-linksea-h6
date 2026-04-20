module video_pipeline_elinx_top
(
    input  wire        SYS_50M,
    input  wire        FPGA_UART_RX,
    output wire        FPGA_UART_TX,
    input  wire        CMOS_PCLK,
    input  wire        CMOS_VSYNC,
    input  wire        CMOS_HREF,
    input  wire [7:0]  CMOS_D,
    output wire        CMOS_XCLK,
    output wire        CMOS_SCL,
    inout  wire        CMOS_SDA,
    output wire        CMOS_RESET,
    output wire        CMOS_PWDN,
    output wire        HDMI_CLK,
    output wire [23:0] HDMI_D,
    output wire        HDMI_HS,
    output wire        HDMI_VS,
    output wire        HDMI_DE,
    output wire        HDMI_SCL,
    inout  wire        HDMI_SDA,
    output wire        HDMI_RESETN,
    output wire [3:0]  LED,
    output wire [15:0] VGA_D,
    output wire        VGA_HSYNC,
    output wire        VGA_VSYNC
);

    reg [15:0] por_count;
    reg        pix_clk_div2;
    reg [25:0] led_blink_div;
    reg        prev_cmos_scl;
    reg [23:0] cam_i2c_activity_hold;
    wire       sys_rst_n;
    wire [4:0] vga_r;
    wire [5:0] vga_g;
    wire [4:0] vga_b;
    wire       vid_de;
    wire [15:0] vid_pixel;
    wire       hdmi_sda_oe;
    wire       hdmi_sda_i;
    wire [7:0] hdmi_r;
    wire [7:0] hdmi_g;
    wire [7:0] hdmi_b;
    wire       uart_tx_raw;
    wire       dbg_cam_init_done;
    wire       dbg_cam_data_active;
    wire       dbg_fb_frame_ready;

    initial begin
        por_count    = 16'd0;
        pix_clk_div2 = 1'b0;
        led_blink_div = 26'd0;
        prev_cmos_scl = 1'b1;
        cam_i2c_activity_hold = 24'd0;
    end

    always @(posedge SYS_50M) begin
        pix_clk_div2 <= ~pix_clk_div2;
        led_blink_div <= led_blink_div + 26'd1;
        prev_cmos_scl <= CMOS_SCL;
        if (!sys_rst_n) begin
            cam_i2c_activity_hold <= 24'd0;
        end else if (CMOS_SCL != prev_cmos_scl) begin
            cam_i2c_activity_hold <= {24{1'b1}};
        end else if (cam_i2c_activity_hold != 24'd0) begin
            cam_i2c_activity_hold <= cam_i2c_activity_hold - 24'd1;
        end
        if (!por_count[15]) begin
            por_count <= por_count + 16'd1;
        end
    end

    assign sys_rst_n = por_count[15];
    assign VGA_D     = {vga_r, vga_g, vga_b};
    assign hdmi_sda_i = HDMI_SDA;
    assign HDMI_SDA   = hdmi_sda_oe ? 1'b0 : 1'bz;
    assign HDMI_CLK   = pix_clk_div2;
    assign HDMI_HS    = VGA_HSYNC;
    assign HDMI_VS    = VGA_VSYNC;
    assign HDMI_DE    = vid_de;
    // USB3 UART2 on this board ends up with the correct external TTL polarity
    // when we drive the raw core UART level here.
    assign FPGA_UART_TX = uart_tx_raw;
    assign hdmi_r     = {vid_pixel[15:11], vid_pixel[15:13]};
    assign hdmi_g     = {vid_pixel[10:5],  vid_pixel[10:9]};
    assign hdmi_b     = {vid_pixel[4:0],   vid_pixel[4:2]};
    assign HDMI_D     = vid_de ? {hdmi_r, hdmi_g, hdmi_b} : 24'd0;
    // Board LEDs are active-low.
    // LED1: heartbeat
    // LED2: camera reset released
    // LED3: camera powered up (PWDN deasserted)
    // LED4: SCCB/I2C clock activity seen recently
    assign LED        = ~{(cam_i2c_activity_hold != 24'd0), ~CMOS_PWDN, CMOS_RESET, led_blink_div[25]};

    video_pipeline_top #(
        .SYS_CLK_HZ(50_000_000),
        .PIX_CLK_HZ(25_000_000),
        .UART_BAUD(115200)
    ) u_video_pipeline_top (
        .sys_clk(SYS_50M),
        .pix_clk(pix_clk_div2),
        .sys_rst_n(sys_rst_n),
        .uart_rx_i(FPGA_UART_RX),
        .uart_tx_o(uart_tx_raw),
        .cam_pclk_i(CMOS_PCLK),
        .cam_vsync_i(CMOS_VSYNC),
        .cam_href_i(CMOS_HREF),
        .cam_data_i(CMOS_D),
        .cam_xclk_o(CMOS_XCLK),
        .cam_sccb_scl_o(CMOS_SCL),
        .cam_sccb_sda_io(CMOS_SDA),
        .cam_reset_o(CMOS_RESET),
        .cam_pwdn_o(CMOS_PWDN),
        .vga_hsync_o(VGA_HSYNC),
        .vga_vsync_o(VGA_VSYNC),
        .vid_de_o(vid_de),
        .vid_pixel_o(vid_pixel),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b),
        .dbg_cam_init_done_o(dbg_cam_init_done),
        .dbg_cam_data_active_o(dbg_cam_data_active),
        .dbg_fb_frame_ready_o(dbg_fb_frame_ready)
    );

    sii9134_ctrl #(
        .CLK_HZ(50_000_000),
        .I2C_HZ(100_000)
    ) u_sii9134_ctrl (
        .clk(SYS_50M),
        .rst_n(sys_rst_n),
        .hdmi_reset_n_o(HDMI_RESETN),
        .i2c_scl_o(HDMI_SCL),
        .i2c_sda_oe_o(hdmi_sda_oe),
        .i2c_sda_i(hdmi_sda_i),
        .init_done_o(),
        .init_error_o()
    );

endmodule
