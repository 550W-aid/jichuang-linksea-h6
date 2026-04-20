`include "fpga/rtl/common/video_regs.vh"

module link_sea_h6_bringup_top #
(
    parameter integer CLK_HZ = 25_000_000,
    parameter integer UART_BAUD = 115200
)
(
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    input  wire       uart_rx_i,
    output wire       uart_tx_o,
    input  wire [3:0] key_i,
    output wire [3:0] led_o,
    output wire       vga_hsync_o,
    output wire       vga_vsync_o,
    output wire [4:0] vga_r_o,
    output wire [5:0] vga_g_o,
    output wire [4:0] vga_b_o
);

    wire [15:0] mode;
    wire [15:0] algo_enable;
    wire [15:0] brightness_gain;
    wire [15:0] gamma_sel;
    wire [15:0] scale_sel;
    wire [15:0] rotate_sel;
    wire [15:0] edge_sel;
    wire [15:0] osd_sel;
    wire [15:0] rd_data;

    wire        wr_en;
    wire [7:0]  addr;
    wire [15:0] wr_data;

    wire        active_video;
    wire [10:0] x;
    wire [10:0] y;
    wire        sof;
    wire        eol;

    wire [15:0] src_pixel;
    wire        src_valid;
    wire        src_sof;
    wire        src_eol;

    wire [15:0] proc_pixel;
    wire        proc_valid;
    wire        proc_sof;
    wire        proc_eol;

    wire [15:0] mux_pixel;
    wire        mux_valid;
    wire        mux_sof;
    wire        mux_eol;

    wire [15:0] osd_pixel;
    wire        osd_valid;
    wire        osd_sof;
    wire        osd_eol;

    wire [15:0] fps_counter;
    wire [15:0] heartbeat;
    wire [15:0] status_word;

    assign status_word = {12'd0, src_valid, 1'b0, key_i[0], 1'b1};
    assign led_o       = {heartbeat[0], mode[1:0], status_word[3]};

    uart_ctrl #(
        .CLK_HZ(CLK_HZ),
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
        .rd_data(rd_data),
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

    vga_timing u_vga_timing (
        .clk(sys_clk),
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
        .pixel_o(src_pixel),
        .valid_o(src_valid),
        .sof_o(src_sof),
        .eol_o(src_eol)
    );

    algo_pipe u_algo_pipe (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .mode_i(mode),
        .algo_enable_i(algo_enable),
        .brightness_gain_i(brightness_gain),
        .gamma_sel_i(gamma_sel),
        .scale_sel_i(scale_sel),
        .rotate_sel_i(rotate_sel),
        .edge_sel_i(edge_sel),
        .pixel_in(src_pixel),
        .valid_in(src_valid),
        .sof_in(src_sof),
        .eol_in(src_eol),
        .pixel_out(proc_pixel),
        .valid_out(proc_valid),
        .sof_out(proc_sof),
        .eol_out(proc_eol)
    );

    algo_mux u_algo_mux (
        .mode_i(mode),
        .bypass_pixel_i(src_pixel),
        .bypass_valid_i(src_valid),
        .bypass_sof_i(src_sof),
        .bypass_eol_i(src_eol),
        .proc_pixel_i(proc_pixel),
        .proc_valid_i(proc_valid),
        .proc_sof_i(proc_sof),
        .proc_eol_i(proc_eol),
        .pixel_o(mux_pixel),
        .valid_o(mux_valid),
        .sof_o(mux_sof),
        .eol_o(mux_eol)
    );

    osd_overlay u_osd_overlay (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .mode_i(mode),
        .osd_sel_i(osd_sel),
        .fps_i(fps_counter),
        .x_i(x),
        .y_i(y),
        .pixel_in(mux_pixel),
        .valid_in(mux_valid),
        .sof_in(mux_sof),
        .eol_in(mux_eol),
        .pixel_out(osd_pixel),
        .valid_out(osd_valid),
        .sof_out(osd_sof),
        .eol_out(osd_eol)
    );

    vga_tx_rgb565 u_vga_tx (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .active_i(active_video),
        .pixel_i(osd_pixel),
        .valid_i(osd_valid),
        .vga_r_o(vga_r_o),
        .vga_g_o(vga_g_o),
        .vga_b_o(vga_b_o)
    );

    perf_counter #(
        .CLK_HZ(CLK_HZ)
    ) u_perf_counter (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .sof_pulse(sof),
        .fps_counter(fps_counter),
        .heartbeat(heartbeat)
    );

endmodule
