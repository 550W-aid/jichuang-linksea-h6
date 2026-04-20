`include "common/video_regs.vh"

module video_pipeline_top #
(
    parameter integer SYS_CLK_HZ = 50_000_000,
    parameter integer PIX_CLK_HZ = 25_000_000,
    parameter integer UART_BAUD  = 115200
)
(
    input  wire       sys_clk,
    input  wire       pix_clk,
    input  wire       sys_rst_n,
    input  wire       uart_rx_i,
    output wire       uart_tx_o,
    input  wire       cam_pclk_i,
    input  wire       cam_vsync_i,
    input  wire       cam_href_i,
    input  wire [7:0] cam_data_i,
    output wire       cam_xclk_o,
    output wire       cam_sccb_scl_o,
    inout  wire       cam_sccb_sda_io,
    output wire       cam_reset_o,
    output wire       cam_pwdn_o,
    output wire       vga_hsync_o,
    output wire       vga_vsync_o,
    output wire       vid_de_o,
    output wire [15:0] vid_pixel_o,
    output wire [4:0] vga_r_o,
    output wire [5:0] vga_g_o,
    output wire [4:0] vga_b_o,
    output wire       dbg_cam_init_done_o,
    output wire       dbg_cam_data_active_o,
    output wire       dbg_fb_frame_ready_o
);

    wire [15:0] mode;
    wire [15:0] algo_enable;
    wire [15:0] brightness_gain;
    wire [15:0] gamma_sel;
    wire [15:0] scale_sel;
    wire [15:0] rotate_sel;
    wire [15:0] edge_sel;
    wire [15:0] osd_sel;
    wire [15:0] base_rd_data;
    wire [15:0] camera_rd_data;
    wire [15:0] rd_data;

    wire        wr_en;
    wire [7:0]  addr;
    wire [15:0] wr_data;

    wire [15:0] cam_reg_rd_data;
    wire [15:0] cam_status;
    wire [15:0] cam_frame_counter;
    wire [15:0] cam_line_counter;
    wire [15:0] cam_last_pixel;
    wire [15:0] cam_error_count;
    wire        cam_init_done;
    wire        cam_data_active;
    wire        cam_cmd_strobe;
    wire [15:0] cam_cmd;
    wire [15:0] cam_reg_addr;
    wire [15:0] cam_wr_data;
    wire        cam_sccb_sda_oe;
    wire        cam_sccb_sda_i;
    wire [15:0] cam_pixel;
    wire        cam_valid;
    wire        cam_sof;
    wire        cam_eol;

    wire [15:0] fb_pixel;
    wire        fb_valid;
    wire        fb_sof;
    wire        fb_eol;
    wire        fb_frame_ready;

    wire        active_video;
    wire [10:0] x;
    wire [10:0] y;
    wire        sof;
    wire        eol;

    wire [15:0] test_pixel;
    wire        test_valid;
    wire        test_sof;
    wire        test_eol;

    wire [15:0] display_pixel;
    wire        display_valid;

    wire [15:0] fps_counter;
    wire [15:0] heartbeat;
    wire [15:0] status_word;
    wire        use_test_pattern;

    assign cam_xclk_o       = pix_clk;
    assign cam_sccb_sda_io  = cam_sccb_sda_oe ? 1'b0 : 1'bz;
    assign cam_sccb_sda_i   = cam_sccb_sda_io;
    assign cam_init_done    = cam_status[`CAM_STATUS_INIT_DONE_BIT];
    assign cam_data_active  = cam_status[`CAM_STATUS_DATA_ACTIVE_BIT];
    assign status_word      = {11'd0, cam_data_active, fb_frame_ready, 1'b0, cam_init_done, 1'b1};
    assign use_test_pattern = !fb_frame_ready;
    assign rd_data          = (addr >= `REG_CAM_CMD && addr <= `REG_CAM_ERROR_COUNT) ? camera_rd_data : base_rd_data;
    assign vid_de_o         = active_video;
    assign vid_pixel_o      = display_pixel;
    assign dbg_cam_init_done_o   = cam_init_done;
    assign dbg_cam_data_active_o = cam_data_active;
    assign dbg_fb_frame_ready_o  = fb_frame_ready;

    uart_ctrl #(
        .CLK_HZ(SYS_CLK_HZ),
        .BAUD(UART_BAUD)
    ) u_uart_ctrl (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .uart_rx_i(uart_rx_i),
        .uart_tx_o(uart_tx_o),
        .wr_en_o(wr_en),
        .addr_o(addr),
        .wr_data_o(wr_data),
        .rd_data_i(rd_data)
    );

    ctrl_regs u_ctrl_regs (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .wr_en(wr_en),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(base_rd_data),
        .status_in(status_word),
        .fps_counter_in(fps_counter),
        .heartbeat_in(heartbeat),
        .mode(mode),
        .algo_enable(algo_enable),
        .brightness_gain(brightness_gain),
        .gamma_sel(gamma_sel),
        .scale_sel(scale_sel),
        .rotate_sel(rotate_sel),
        .edge_sel(edge_sel),
        .osd_sel(osd_sel)
    );

    camera_ctrl_regs u_camera_ctrl_regs (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .wr_en(wr_en),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(camera_rd_data),
        .cam_cmd_strobe_o(cam_cmd_strobe),
        .cam_cmd_o(cam_cmd),
        .cam_reg_addr_o(cam_reg_addr),
        .cam_wr_data_o(cam_wr_data),
        .cam_rd_data_i(cam_reg_rd_data),
        .cam_status_i(cam_status),
        .cam_frame_counter_i(cam_frame_counter),
        .cam_line_counter_i(cam_line_counter),
        .cam_last_pixel_i(cam_last_pixel),
        .cam_error_count_i(cam_error_count)
    );

    ov5640_reg_if #(
        .CLK_HZ(SYS_CLK_HZ)
    ) u_ov5640_reg_if (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .cmd_strobe_i(cam_cmd_strobe),
        .cmd_i(cam_cmd),
        .reg_addr_i(cam_reg_addr),
        .wr_data_i(cam_wr_data),
        .rd_data_o(cam_reg_rd_data),
        .status_o(cam_status),
        .frame_counter_o(cam_frame_counter),
        .line_counter_o(cam_line_counter),
        .last_pixel_o(cam_last_pixel),
        .error_count_o(cam_error_count),
        .pixel_i(cam_pixel),
        .valid_i(cam_valid),
        .sof_i(cam_sof),
        .eol_i(cam_eol),
        .cam_reset_o(cam_reset_o),
        .cam_pwdn_o(cam_pwdn_o),
        .init_done_o(),
        .sccb_scl_o(cam_sccb_scl_o),
        .sccb_sda_oe_o(cam_sccb_sda_oe),
        .sccb_sda_i(cam_sccb_sda_i)
    );

    dvp_rx u_dvp_rx (
        .pclk(cam_pclk_i),
        .rst_n(sys_rst_n),
        .vsync_i(cam_vsync_i),
        .href_i(cam_href_i),
        .data_i(cam_data_i),
        .pixel_o(cam_pixel),
        .valid_o(cam_valid),
        .sof_o(cam_sof),
        .eol_o(cam_eol)
    );

    frame_buf_stub u_frame_buf_stub (
        .wr_clk(cam_pclk_i),
        .rd_clk(pix_clk),
        .rst_n(sys_rst_n),
        .pixel_in(cam_pixel),
        .valid_in(cam_valid),
        .sof_in(cam_sof),
        .eol_in(cam_eol),
        .rd_active_i(active_video),
        .rd_sof_i(sof),
        .rd_eol_i(eol),
        .pixel_out(fb_pixel),
        .valid_out(fb_valid),
        .sof_out(fb_sof),
        .eol_out(fb_eol),
        .frame_ready_o(fb_frame_ready)
    );

    vga_timing u_vga_timing (
        .clk(pix_clk),
        .rst_n(sys_rst_n),
        .hsync_o(vga_hsync_o),
        .vsync_o(vga_vsync_o),
        .active_o(active_video),
        .x_o(x),
        .y_o(y),
        .sof_o(sof),
        .eol_o(eol)
    );

    test_pattern_source u_test_pattern_source (
        .x_i(x),
        .y_i(y),
        .active_i(active_video),
        .sof_i(sof),
        .eol_i(eol),
        .pixel_o(test_pixel),
        .valid_o(test_valid),
        .sof_o(test_sof),
        .eol_o(test_eol)
    );

    assign display_pixel = use_test_pattern ? test_pixel : fb_pixel;
    assign display_valid = use_test_pattern ? test_valid : fb_valid;

    vga_tx_rgb565 u_vga_tx (
        .clk(pix_clk),
        .rst_n(sys_rst_n),
        .active_i(active_video),
        .pixel_i(display_pixel),
        .valid_i(display_valid),
        .vga_r_o(vga_r_o),
        .vga_g_o(vga_g_o),
        .vga_b_o(vga_b_o)
    );

    perf_counter #(
        .CLK_HZ(PIX_CLK_HZ)
    ) u_perf_counter (
        .clk(pix_clk),
        .rst_n(sys_rst_n),
        .sof_pulse(sof),
        .fps_counter(fps_counter),
        .heartbeat(heartbeat)
    );

endmodule
