`timescale 1ns/1ps
`include "uart_rx.v"
`include "uart_algo_ctrl.v"
`include "bilinear_rgb888_pipe.v"
`include "bilinear_resize_realtime_stream_std.v"
`include "resize_letterbox_stream.v"
`include "frame_latched_s9.v"
`include "rgb888_to_ycbcr444_stream_std.v"
`include "ycbcr444_luma_gamma_stream_std.v"
`include "ycbcr444_to_rgb888_stream_std.v"
`include "darkness_enhance_rgb888_stream_std.v"

module TOP1
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        key2_n,
    input  wire        key3_n,
    input  wire        key4_n,
    input  wire        ov5640_pclk,
    input  wire        ov5640_vsync,
    input  wire        ov5640_href,
    input  wire [7:0]  ov5640_data,
    output wire        ov5640_rst_n,
    output wire        ov5640_pwdn,
    output wire        sccb_scl,
    inout  wire        sccb_sda,
    output wire        sdram1_clk,
    output wire        sdram1_cke,
    output wire        sdram1_cs_n,
    output wire        sdram1_ras_n,
    output wire        sdram1_cas_n,
    output wire        sdram1_we_n,
    output wire [1:0]  sdram1_ba,
    output wire [12:0] sdram1addr,
    inout  wire [15:0] sdram1_dq,
    output wire        ddc_scl,
    inout  wire        ddc_sda,
    output wire        hdmi_out_clk,
    output wire        hdmi_out_hsync,
    output wire        hdmi_out_vsync,
    output wire [23:0] hdmi_out_rgb,
    output wire        hdmi_out_de,
    output wire        hdmi_reset_n,
    output wire        ov5640_xclk,
    input  wire        uart_rxd,
    output wire        uart_txd
);

parameter H_PIXEL = 24'd1024;
parameter V_PIXEL = 24'd600;

localparam [12:0] CAM_INPUT_H_PIXEL  = 13'd1920;
localparam [11:0] CAM_INPUT_V_PIXEL  = 12'd1080;
localparam [19:0] KEY_DB_CNT_MAX     = 20'd999999;
localparam [23:0] FRAME_WORDS        = H_PIXEL * V_PIXEL;
localparam [23:0] BUF0_B_ADDR        = 24'h000000;
localparam [23:0] BUF1_B_ADDR        = 24'h400000;
localparam [23:0] BUF2_B_ADDR        = 24'h800000;
localparam [23:0] BUF0_E_ADDR        = BUF0_B_ADDR + FRAME_WORDS;
localparam [23:0] BUF1_E_ADDR        = BUF1_B_ADDR + FRAME_WORDS;
localparam [23:0] BUF2_E_ADDR        = BUF2_B_ADDR + FRAME_WORDS;
localparam [12:0] CAM_COMMIT_DELAY   = 13'd1;
localparam signed [8:0] LOW_LIGHT_OFFSET_ON = 9'sd48;
localparam [7:0]  ZOOM_LEVEL_MIN     = 8'd0;
localparam [7:0]  ZOOM_LEVEL_MAX     = 8'd255;
localparam [7:0]  ZOOM_KEY_STEP      = 8'd16;
localparam [12:0] OUTPUT_W_FULL      = H_PIXEL[12:0];
localparam [11:0] OUTPUT_H_FULL      = V_PIXEL[11:0];
localparam [12:0] ZOOM_OUT_W_MIN     = 13'd256;
localparam [11:0] ZOOM_OUT_H_MIN     = 12'd150;
localparam [12:0] ZOOM_IN_W_MIN      = 13'd1024;
localparam [11:0] ZOOM_IN_H_MIN      = 12'd600;
localparam [7:0]  PAN_CENTER         = 8'd128;

function [12:0] zoom_active_width;
    input [7:0] level;
    reg [21:0] shrink_delta_v;
    reg [12:0] width_v;
    begin
        shrink_delta_v = (((OUTPUT_W_FULL - ZOOM_OUT_W_MIN) * level) + 8'd127) >> 8;
        width_v = OUTPUT_W_FULL - shrink_delta_v[12:0];
        if (width_v < ZOOM_OUT_W_MIN) begin
            width_v = ZOOM_OUT_W_MIN;
        end
        if (width_v > OUTPUT_W_FULL) begin
            width_v = OUTPUT_W_FULL;
        end
        if (width_v[0]) begin
            width_v = width_v - 13'd1;
        end
        zoom_active_width = width_v;
    end
endfunction

function [11:0] zoom_active_height;
    input [7:0] level;
    reg [20:0] shrink_delta_v;
    reg [11:0] height_v;
    begin
        shrink_delta_v = (((OUTPUT_H_FULL - ZOOM_OUT_H_MIN) * level) + 8'd127) >> 8;
        height_v = OUTPUT_H_FULL - shrink_delta_v[11:0];
        if (height_v < ZOOM_OUT_H_MIN) begin
            height_v = ZOOM_OUT_H_MIN;
        end
        if (height_v > OUTPUT_H_FULL) begin
            height_v = OUTPUT_H_FULL;
        end
        if (height_v[0]) begin
            height_v = height_v - 12'd1;
        end
        zoom_active_height = height_v;
end
endfunction

function [23:0] zoom_active_words;
    input [7:0] level;
    reg [24:0] words_v;
    begin
        words_v = zoom_active_width(level) * zoom_active_height(level);
        zoom_active_words = words_v[23:0];
    end
endfunction

function [31:0] zoom_scale_x;
    input [7:0] level;
    reg [12:0] active_width_v;
    reg [12:0] width_minus_one_v;
    begin
        active_width_v = zoom_active_width(level);
        width_minus_one_v = (active_width_v > 13'd1) ? (active_width_v - 13'd1) : 13'd1;
        zoom_scale_x = ((CAM_INPUT_H_PIXEL - 13'd1) << 16) / width_minus_one_v;
    end
endfunction

function [31:0] zoom_scale_y;
    input [7:0] level;
    reg [11:0] active_height_v;
    reg [11:0] height_minus_one_v;
    begin
        active_height_v = zoom_active_height(level);
        height_minus_one_v = (active_height_v > 12'd1) ? (active_height_v - 12'd1) : 12'd1;
        zoom_scale_y = ((CAM_INPUT_V_PIXEL - 12'd1) << 16) / height_minus_one_v;
    end
endfunction

function [12:0] zoom_crop_width;
    input [7:0] level;
    reg [21:0] shrink_delta_v;
    reg [12:0] width_v;
    begin
        shrink_delta_v = (((CAM_INPUT_H_PIXEL - ZOOM_IN_W_MIN) * level) + 8'd127) >> 8;
        width_v = CAM_INPUT_H_PIXEL - shrink_delta_v[12:0];
        if (width_v < ZOOM_IN_W_MIN) begin
            width_v = ZOOM_IN_W_MIN;
        end
        if (width_v > CAM_INPUT_H_PIXEL) begin
            width_v = CAM_INPUT_H_PIXEL;
        end
        if (width_v[0]) begin
            width_v = width_v - 13'd1;
        end
        zoom_crop_width = width_v;
    end
endfunction

function [11:0] zoom_crop_height;
    input [7:0] level;
    reg [20:0] shrink_delta_v;
    reg [11:0] height_v;
    begin
        shrink_delta_v = (((CAM_INPUT_V_PIXEL - ZOOM_IN_H_MIN) * level) + 8'd127) >> 8;
        height_v = CAM_INPUT_V_PIXEL - shrink_delta_v[11:0];
        if (height_v < ZOOM_IN_H_MIN) begin
            height_v = ZOOM_IN_H_MIN;
        end
        if (height_v > CAM_INPUT_V_PIXEL) begin
            height_v = CAM_INPUT_V_PIXEL;
        end
        if (height_v[0]) begin
            height_v = height_v - 12'd1;
        end
        zoom_crop_height = height_v;
    end
endfunction

function [31:0] zoom_crop_scale_x;
    input [7:0] level;
    reg [12:0] crop_width_v;
    reg [12:0] out_width_minus_one_v;
    begin
        crop_width_v = zoom_crop_width(level);
        out_width_minus_one_v = (OUTPUT_W_FULL > 13'd1) ? (OUTPUT_W_FULL - 13'd1) : 13'd1;
        zoom_crop_scale_x = ((crop_width_v - 13'd1) << 16) / out_width_minus_one_v;
    end
endfunction

function [31:0] zoom_crop_scale_y;
    input [7:0] level;
    reg [11:0] crop_height_v;
    reg [11:0] out_height_minus_one_v;
    begin
        crop_height_v = zoom_crop_height(level);
        out_height_minus_one_v = (OUTPUT_H_FULL > 12'd1) ? (OUTPUT_H_FULL - 12'd1) : 12'd1;
        zoom_crop_scale_y = ((crop_height_v - 12'd1) << 16) / out_height_minus_one_v;
    end
endfunction

function [12:0] zoom_crop_start_x;
    input [7:0] pan_level;
    input [12:0] crop_width_v;
    reg [12:0] max_offset_v;
    reg [20:0] scaled_v;
    begin
        max_offset_v = CAM_INPUT_H_PIXEL - crop_width_v;
        scaled_v = 21'd0;
        if (pan_level >= 8'd255) begin
            zoom_crop_start_x = max_offset_v;
        end else begin
            scaled_v = ((max_offset_v * pan_level) + 8'd127) >> 8;
            if (scaled_v[12:0] > max_offset_v) begin
                zoom_crop_start_x = max_offset_v;
            end else begin
                zoom_crop_start_x = scaled_v[12:0];
            end
        end
    end
endfunction

function [11:0] zoom_crop_start_y;
    input [7:0] pan_level;
    input [11:0] crop_height_v;
    reg [11:0] max_offset_v;
    reg [19:0] scaled_v;
    begin
        max_offset_v = CAM_INPUT_V_PIXEL - crop_height_v;
        scaled_v = 20'd0;
        if (pan_level >= 8'd255) begin
            zoom_crop_start_y = max_offset_v;
        end else begin
            scaled_v = ((max_offset_v * pan_level) + 8'd127) >> 8;
            if (scaled_v[11:0] > max_offset_v) begin
                zoom_crop_start_y = max_offset_v;
            end else begin
                zoom_crop_start_y = scaled_v[11:0];
            end
        end
    end
endfunction

wire [10:0] pixel_xpos_w;
wire [10:0] pixel_ypos_w;
wire [15:0] video_pixel_data;
wire [15:0] video_rgb_raw_w;
wire        clk_100m;
wire        clk_100m_shift;
wire        clk_25m;
wire        sys_clk2;
wire        hdmi_pix_clk;
wire        pll1_locked;
wire        pll2_locked;
wire        locked;
wire        rst_n;
wire        cfg_done;
wire        wr_en;
wire [15:0] wr_data;
wire        rd_en;
wire [15:0] rd_data;
wire [9:0]  rd_fifo_num;
wire        sdram1_init_done;
wire        sys_init_done;
wire        hdmi_cfg_done;
wire        hdmi_init_error;
wire        hdmi_sda_oe;
wire        hdmi_sda_i;
wire        uart_diag_tx;
wire [7:0]  uart_rx_data_w;
wire        uart_rx_valid_w;
wire        uart_zoom_valid_w;
wire [7:0]  uart_zoom_level_w;
wire        uart_zoom_in_valid_w;
wire [7:0]  uart_zoom_in_level_w;
wire        uart_pan_x_valid_w;
wire [7:0]  uart_pan_x_value_w;
wire        uart_pan_y_valid_w;
wire [7:0]  uart_pan_y_value_w;
wire        uart_lowlight_valid_w;
wire signed [8:0] uart_lowlight_value_w;
wire [15:0] cam_dbg_addr_w;
wire [7:0]  cam_dbg_data_w;
wire        cam_dbg_ack_w;
wire        cam_dbg_busy_w;
wire        cam_dbg_done_w;
wire        cam_dbg_timeout_w;
wire [2:0]  cam_dbg_state_w;
wire [3:0]  cam_dbg_index_w;
wire        wr_en_db;
wire        crop_hit_w;
wire        wr_rst_db;
wire        rd_rst_db;
wire        resize_sof_100;
wire        resize_eof_100;
wire        hdmi_swap_100;
wire [23:0] sdram_wr_b_addr_w;
wire [23:0] sdram_wr_e_addr_w;
wire [23:0] sdram_rd_b_addr_w;
wire [23:0] sdram_rd_e_addr_w;
wire [1:0]  rd_buf_next_w;
wire [15:0] debug_error_w;
wire [12:0] crop_end_x_w;
wire [11:0] crop_end_y_w;
wire        key2_pressed_w;
wire        key3_pressed_w;
wire        key4_pressed_w;
wire        cam_frame_start_pclk_w;
wire        zoom_in_mode_req_w;
wire [12:0] zoom_crop_width_req_w;
wire [11:0] zoom_crop_height_req_w;
wire [12:0] active_width_req_w;
wire [11:0] active_height_req_w;
wire [10:0] active_offset_x_req_w;
wire [10:0] active_offset_y_req_w;
wire [10:0] active_offset_x_cfg_w;
wire [10:0] active_offset_y_cfg_w;
wire        zoom_in_mode_pclk_w;
wire [12:0] zoom_crop_width_pclk_w;
wire [11:0] zoom_crop_height_pclk_w;
wire [12:0] crop_start_x_pclk_w;
wire [11:0] crop_start_y_pclk_w;
wire [12:0] crop_width_pclk_w;
wire [11:0] crop_height_pclk_w;
wire [12:0] active_width_cfg_w;
wire [11:0] active_height_cfg_w;
wire [31:0] resize_cfg_scale_x_w;
wire [31:0] resize_cfg_scale_y_w;
wire        hdmi_window_raw_w;
wire        hdmi_rd_req_w;
wire [12:0] hdmi_active_width_next_w;
wire [11:0] hdmi_active_height_next_w;
wire [10:0] hdmi_offset_x_next_w;
wire [10:0] hdmi_offset_y_next_w;
wire [10:0] hdmi_end_x_next_w;
wire [10:0] hdmi_end_y_next_w;
wire [23:0] cam_rgb888_w;
wire [23:0] resize_m_data_w;
wire [23:0] frame_m_data_w;
wire [15:0] wr_data_sdram_w;
wire        resize_s_valid_w;
wire        resize_s_ready_w;
wire        resize_s_sof_w;
wire        resize_s_eol_w;
wire        resize_s_eof_w;
wire        resize_cfg_ready_w;
wire        resize_cfg_valid_w;
wire        resize_m_valid_w;
wire        resize_m_sof_w;
wire        resize_m_eol_w;
wire        resize_m_eof_w;
wire [0:0]  resize_m_keep_w;
wire        resize_active_valid_w;
wire        letterbox_s_valid_w;
wire        letterbox_m_valid_w;
wire [23:0] letterbox_m_data_w;
wire        letterbox_m_sof_w;
wire        letterbox_m_eol_w;
wire        letterbox_m_eof_w;
wire        frame_m_valid_w;
wire        frame_m_sof_w;
wire        frame_m_eol_w;
wire        frame_m_eof_w;
wire [12:0] scaled_line_pixels_next_w;
wire [11:0] scaled_frame_lines_next_w;
wire [19:0] scaled_frame_pixels_next_w;
wire        video_hs_raw_w;
wire        video_vs_raw_w;
wire        video_de_raw_w;
wire        hdmi_req_window_w;
wire        low_light_sof_w;
wire        low_light_eol_w;
wire        low_light_eof_w;
wire [23:0] video_rgb888_raw_w;
wire        low_light_s_ready_w;
wire        low_light_cfg_ready_w;
wire signed [8:0] low_light_active_offset_w;
wire        low_light_m_valid_w;
wire [23:0] low_light_m_data_w;
wire [0:0]  low_light_m_keep_w;
wire        low_light_m_sof_w;
wire        low_light_m_eol_w;
wire        low_light_m_eof_w;
wire [15:0] low_light_rgb565_w;
wire [15:0] video_rgb_windowed_w;
wire [23:0] low_light_rgb565_expand_w;
wire [23:0] hdmi_rgb_sel_w;

reg         cfg_done_meta_r;
reg         cfg_done_sys_r;
reg         wr_en_meta_r;
reg         wr_en_sys_r;
reg         cam_data_seen_r;
reg         sdram_init_done_meta_r;
reg         sdram_init_done_sys_r;
reg         hdmi_vs_meta_r;
reg         hdmi_vs_sync_r;
reg         hdmi_vs_sync_d_r;
reg         hdmi_vsync_sys_r;
reg [15:0]  uart_frame_counter_r;
reg [15:0]  wr_data_sys_r;
reg [15:0]  rd_data_sys_r;
reg [1:0]   wr_buf_r;
reg [1:0]   rd_buf_r;
reg         pending_valid_r;
reg [1:0]   pending_buf_r;
reg [1:0]   committed_buf_r;
reg [7:0]   pending_zoom_level_r;
reg [7:0]   committed_zoom_level_r;
reg [7:0]   display_zoom_level_100_r;
reg [7:0]   pending_zoom_in_level_r;
reg [7:0]   committed_zoom_in_level_r;
reg [7:0]   display_zoom_in_level_100_r;
reg [1:0]   cam_vs_100_r;
reg [1:0]   hdmi_vs_100_r;
reg         resize_sof_toggle_pclk_r;
reg         resize_eof_toggle_pclk_r;
reg [1:0]   resize_sof_toggle_100_r;
reg [1:0]   resize_eof_toggle_100_r;
reg [7:0]   zoom_cfg_level_meta_100_r;
reg [7:0]   zoom_cfg_level_sync_100_r;
reg [7:0]   zoom_in_cfg_level_meta_100_r;
reg [7:0]   zoom_in_cfg_level_sync_100_r;
reg         wr_rst_pulse_r;
reg         rd_rst_pulse_r;
reg [12:0]  cam_commit_delay_r;
reg         ov5640_vsync_d_pclk_r;
reg         ov5640_href_d_pclk_r;
reg [12:0]  cam_x_pclk_r;
reg [11:0]  cam_y_pclk_r;
reg [12:0]  raw_line_pixels_pclk_r;
reg [12:0]  raw_line_pixels_last_pclk_r;
reg [11:0]  raw_frame_lines_pclk_r;
reg [11:0]  raw_frame_lines_last_pclk_r;
reg [12:0]  crop_line_pixels_pclk_r;
reg [12:0]  crop_line_pixels_last_pclk_r;
reg [11:0]  crop_frame_lines_pclk_r;
reg [11:0]  crop_frame_lines_last_pclk_r;
reg [19:0]  crop_frame_pixels_pclk_r;
reg [19:0]  crop_frame_pixels_last_pclk_r;
reg [15:0]  raw_line_pixels_meta_r;
reg [15:0]  raw_line_pixels_sys_r;
reg [15:0]  raw_frame_lines_meta_r;
reg [15:0]  raw_frame_lines_sys_r;
reg [15:0]  crop_line_pixels_meta_r;
reg [15:0]  crop_line_pixels_sys_r;
reg [15:0]  crop_frame_lines_meta_r;
reg [15:0]  crop_frame_lines_sys_r;
reg [19:0]  crop_frame_pixels_meta_r;
reg [19:0]  crop_frame_pixels_sys_r;
reg [15:0]  cam_dbg_addr_meta_r;
reg [15:0]  cam_dbg_addr_sys_r;
reg [7:0]   cam_dbg_data_meta_r;
reg [7:0]   cam_dbg_data_sys_r;
reg         cam_dbg_ack_meta_r;
reg         cam_dbg_ack_sys_r;
reg         cam_dbg_busy_meta_r;
reg         cam_dbg_busy_sys_r;
reg         cam_dbg_done_meta_r;
reg         cam_dbg_done_sys_r;
reg         cam_dbg_timeout_meta_r;
reg         cam_dbg_timeout_sys_r;
reg [2:0]   cam_dbg_state_meta_r;
reg [2:0]   cam_dbg_state_sys_r;
reg [3:0]   cam_dbg_index_meta_r;
reg [3:0]   cam_dbg_index_sys_r;
reg [1:0]   key2_sync_r;
reg [1:0]   key3_sync_r;
reg [1:0]   key4_sync_r;
reg [19:0]  key2_db_cnt_r;
reg [19:0]  key3_db_cnt_r;
reg [19:0]  key4_db_cnt_r;
reg         key2_state_r;
reg         key3_state_r;
reg         key4_state_r;
reg         key2_state_d_r;
reg         key3_state_d_r;
reg         key4_state_d_r;
reg [7:0]   zoom_level_req_r;
reg [7:0]   zoom_in_level_req_r;
reg [7:0]   pan_x_req_r;
reg [7:0]   pan_y_req_r;
reg [7:0]   zoom_level_meta_hdmi_r;
reg [7:0]   zoom_level_sync_hdmi_r;
reg [7:0]   zoom_in_level_meta_hdmi_r;
reg [7:0]   zoom_in_level_sync_hdmi_r;
reg [12:0]  hdmi_active_width_r;
reg [11:0]  hdmi_active_height_r;
reg [10:0]  hdmi_offset_x_r;
reg [10:0]  hdmi_offset_y_r;
reg [10:0]  hdmi_end_x_r;
reg [10:0]  hdmi_end_y_r;
reg [7:0]   zoom_level_meta_pclk_r;
reg [7:0]   zoom_level_sync_pclk_r;
reg [7:0]   zoom_cfg_level_pclk_r;
reg [7:0]   zoom_in_level_meta_pclk_r;
reg [7:0]   zoom_in_level_sync_pclk_r;
reg [7:0]   zoom_in_cfg_level_pclk_r;
reg [7:0]   pan_x_meta_pclk_r;
reg [7:0]   pan_x_sync_pclk_r;
reg [7:0]   pan_y_meta_pclk_r;
reg [7:0]   pan_y_sync_pclk_r;
reg         resize_cfg_valid_pclk_r;
reg [12:0]  crop_start_x_active_pclk_r;
reg [11:0]  crop_start_y_active_pclk_r;
reg [12:0]  crop_width_active_pclk_r;
reg [11:0]  crop_height_active_pclk_r;
reg         resize_cfg_boot_pending_pclk_r;
reg         resize_cfg_dirty_pclk_r;
reg         hdmi_hsync_d1_r;
reg         hdmi_hsync_d2_r;
reg         hdmi_hsync_d3_r;
reg         hdmi_vsync_d1_r;
reg         hdmi_vsync_d2_r;
reg         hdmi_vsync_d3_r;
reg         hdmi_de_d1_r;
reg         hdmi_de_d2_r;
reg         hdmi_de_d3_r;
reg         hdmi_window_d1_r;
reg         hdmi_window_d2_r;
reg         hdmi_window_d3_r;
reg [23:0]  hdmi_rgb_raw_d1_r;
reg [23:0]  hdmi_rgb_raw_d2_r;
reg [23:0]  hdmi_rgb_raw_d3_r;
reg         low_light_enable_r;
reg         low_light_cfg_valid_r;
reg signed [8:0] low_light_cfg_data_r;

function [1:0] third_buf;
    input [1:0] buf_a;
    input [1:0] buf_b;
    begin
        case ({buf_a, buf_b})
            {2'd0, 2'd1},
            {2'd1, 2'd0}: third_buf = 2'd2;
            {2'd0, 2'd2},
            {2'd2, 2'd0}: third_buf = 2'd1;
            default:      third_buf = 2'd0;
        endcase
end
endfunction

assign hdmi_out_hsync = hdmi_hsync_d3_r;
assign hdmi_out_vsync = hdmi_vsync_d3_r;
assign hdmi_out_de    = hdmi_de_d3_r;
assign video_rgb_windowed_w = video_rgb_raw_w;
assign video_rgb888_raw_w = {
    video_rgb_windowed_w[15:11], video_rgb_windowed_w[15:13],
    video_rgb_windowed_w[10:5],  video_rgb_windowed_w[10:9],
    video_rgb_windowed_w[4:0],   video_rgb_windowed_w[4:2]
};
assign low_light_rgb565_w = {
    low_light_m_data_w[23:19],
    low_light_m_data_w[15:10],
    low_light_m_data_w[7:3]
};
assign low_light_rgb565_expand_w = {
    low_light_rgb565_w[15:11], low_light_rgb565_w[15:13],
    low_light_rgb565_w[10:5],  low_light_rgb565_w[10:9],
    low_light_rgb565_w[4:0],   low_light_rgb565_w[4:2]
};
assign hdmi_rgb_sel_w = (low_light_enable_r && low_light_m_valid_w) ? low_light_rgb565_expand_w : hdmi_rgb_raw_d3_r;
assign hdmi_out_rgb = (hdmi_de_d3_r && hdmi_window_d3_r) ? hdmi_rgb_sel_w : 24'd0;
assign locked = pll1_locked & pll2_locked;
assign rst_n = sys_rst_n & locked;
assign sys_init_done = sdram1_init_done & cfg_done;
assign ov5640_rst_n = 1'b1;
assign ov5640_pwdn = 1'b0;
assign uart_txd = uart_diag_tx;
assign hdmi_pix_clk = sys_clk;
assign hdmi_out_clk = hdmi_pix_clk;
assign hdmi_sda_i = ddc_sda;
assign ddc_sda = hdmi_sda_oe ? 1'b0 : 1'bz;
assign video_pixel_data = rd_data;
assign cam_frame_start_pclk_w = !ov5640_vsync_d_pclk_r && ov5640_vsync;
assign zoom_in_mode_req_w    = (zoom_in_level_req_r != 8'd0);
assign zoom_crop_width_req_w = zoom_crop_width(zoom_in_level_req_r);
assign zoom_crop_height_req_w = zoom_crop_height(zoom_in_level_req_r);
assign zoom_in_mode_pclk_w    = (zoom_in_level_sync_pclk_r != 8'd0);
assign zoom_crop_width_pclk_w = zoom_crop_width(zoom_in_level_sync_pclk_r);
assign zoom_crop_height_pclk_w = zoom_crop_height(zoom_in_level_sync_pclk_r);
assign crop_start_x_pclk_w = zoom_in_mode_pclk_w ? zoom_crop_start_x(pan_x_sync_pclk_r, zoom_crop_width_pclk_w) : 13'd0;
assign crop_start_y_pclk_w = zoom_in_mode_pclk_w ? zoom_crop_start_y(pan_y_sync_pclk_r, zoom_crop_height_pclk_w) : 12'd0;
assign crop_width_pclk_w   = zoom_in_mode_pclk_w ? zoom_crop_width_pclk_w : CAM_INPUT_H_PIXEL;
assign crop_height_pclk_w  = zoom_in_mode_pclk_w ? zoom_crop_height_pclk_w : CAM_INPUT_V_PIXEL;
assign active_width_req_w  = zoom_in_mode_req_w ? OUTPUT_W_FULL : zoom_active_width(zoom_level_req_r);
assign active_height_req_w = zoom_in_mode_req_w ? OUTPUT_H_FULL : zoom_active_height(zoom_level_req_r);
assign active_offset_x_req_w = zoom_in_mode_req_w ? 11'd0 : ((OUTPUT_W_FULL[10:0] - active_width_req_w[10:0]) >> 1);
assign active_offset_y_req_w = zoom_in_mode_req_w ? 11'd0 : ((OUTPUT_H_FULL[10:0] - active_height_req_w[10:0]) >> 1);
assign active_width_cfg_w  = zoom_in_mode_pclk_w ? OUTPUT_W_FULL : zoom_active_width(zoom_level_sync_pclk_r);
assign active_height_cfg_w = zoom_in_mode_pclk_w ? OUTPUT_H_FULL : zoom_active_height(zoom_level_sync_pclk_r);
assign active_offset_x_cfg_w = zoom_in_mode_pclk_w ? 11'd0 : ((OUTPUT_W_FULL[10:0] - active_width_cfg_w[10:0]) >> 1);
assign active_offset_y_cfg_w = zoom_in_mode_pclk_w ? 11'd0 : ((OUTPUT_H_FULL[10:0] - active_height_cfg_w[10:0]) >> 1);
assign hdmi_active_width_next_w  = (zoom_in_level_sync_hdmi_r != 8'd0) ? OUTPUT_W_FULL : zoom_active_width(zoom_level_sync_hdmi_r);
assign hdmi_active_height_next_w = (zoom_in_level_sync_hdmi_r != 8'd0) ? OUTPUT_H_FULL : zoom_active_height(zoom_level_sync_hdmi_r);
assign hdmi_offset_x_next_w = (OUTPUT_W_FULL[10:0] - hdmi_active_width_next_w[10:0]) >> 1;
assign hdmi_offset_y_next_w = (OUTPUT_H_FULL[10:0] - hdmi_active_height_next_w[10:0]) >> 1;
assign hdmi_end_x_next_w    = hdmi_offset_x_next_w + hdmi_active_width_next_w[10:0];
assign hdmi_end_y_next_w    = hdmi_offset_y_next_w + hdmi_active_height_next_w[10:0];
assign hdmi_req_window_w    = rd_en &&
                              (pixel_xpos_w >= hdmi_offset_x_r) &&
                              (pixel_xpos_w <  hdmi_end_x_r) &&
                              (pixel_ypos_w >= hdmi_offset_y_r) &&
                              (pixel_ypos_w <  hdmi_end_y_r);
assign hdmi_window_raw_w    = hdmi_req_window_w;
assign hdmi_rd_req_w        = hdmi_req_window_w;
assign crop_end_x_w       = crop_start_x_active_pclk_r + crop_width_active_pclk_r;
assign crop_end_y_w       = crop_start_y_active_pclk_r + crop_height_active_pclk_r;
assign key2_pressed_w = key2_state_d_r & ~key2_state_r;
assign key3_pressed_w = key3_state_d_r & ~key3_state_r;
assign key4_pressed_w = key4_state_d_r & ~key4_state_r;
assign crop_hit_w = (cam_x_pclk_r >= crop_start_x_active_pclk_r) && (cam_x_pclk_r < crop_end_x_w) &&
                    (cam_y_pclk_r >= crop_start_y_active_pclk_r) && (cam_y_pclk_r < crop_end_y_w);
assign cam_rgb888_w = {
    wr_data[15:11], wr_data[15:13],
    wr_data[10:5],  wr_data[10:9],
    wr_data[4:0],   wr_data[4:2]
};
assign resize_s_valid_w = wr_en & crop_hit_w;
assign resize_s_sof_w   = resize_s_valid_w &&
                          (cam_x_pclk_r == crop_start_x_active_pclk_r) &&
                          (cam_y_pclk_r == crop_start_y_active_pclk_r);
assign resize_s_eol_w   = resize_s_valid_w && (cam_x_pclk_r == (crop_end_x_w - 13'd1));
assign resize_s_eof_w   = resize_s_eol_w && (cam_y_pclk_r == (crop_end_y_w - 12'd1));
assign resize_cfg_scale_x_w = zoom_in_mode_pclk_w ? zoom_crop_scale_x(zoom_in_level_sync_pclk_r) : zoom_scale_x(zoom_level_sync_pclk_r);
assign resize_cfg_scale_y_w = zoom_in_mode_pclk_w ? zoom_crop_scale_y(zoom_in_level_sync_pclk_r) : zoom_scale_y(zoom_level_sync_pclk_r);
assign resize_cfg_valid_w   = resize_cfg_valid_pclk_r;
assign resize_active_valid_w = resize_m_valid_w & resize_m_keep_w[0];
assign letterbox_s_valid_w   = 1'b0;
assign frame_m_data_w        = resize_m_data_w;
assign frame_m_valid_w       = resize_active_valid_w;
assign frame_m_sof_w         = resize_m_sof_w;
assign frame_m_eol_w         = resize_m_eol_w;
assign frame_m_eof_w         = resize_m_eof_w;
assign wr_data_sdram_w = {
    frame_m_data_w[23:19],
    frame_m_data_w[15:10],
    frame_m_data_w[7:3]
};
assign wr_en_db = frame_m_valid_w;
assign low_light_sof_w = video_de_raw_w && (pixel_xpos_w == 11'd0) && (pixel_ypos_w == 11'd0);
assign low_light_eol_w = video_de_raw_w && (pixel_xpos_w == (H_PIXEL[10:0] - 11'd1));
assign low_light_eof_w = video_de_raw_w &&
                         (pixel_xpos_w == (H_PIXEL[10:0] - 11'd1)) &&
                         (pixel_ypos_w == (V_PIXEL[10:0] - 11'd1));
assign scaled_line_pixels_next_w  = crop_line_pixels_pclk_r + 13'd1;
assign scaled_frame_lines_next_w  = crop_frame_lines_pclk_r + 12'd1;
assign scaled_frame_pixels_next_w = crop_frame_pixels_pclk_r + 20'd1;
assign wr_rst_db = wr_rst_pulse_r;
assign rd_rst_db = rd_rst_pulse_r;
assign resize_sof_100 = resize_sof_toggle_100_r[1] ^ resize_sof_toggle_100_r[0];
assign resize_eof_100 = resize_eof_toggle_100_r[1] ^ resize_eof_toggle_100_r[0];
assign hdmi_swap_100 = (hdmi_vs_100_r == 2'b10) && pending_valid_r;
assign rd_buf_next_w = hdmi_swap_100 ? pending_buf_r : rd_buf_r;
assign sdram_wr_b_addr_w = (wr_buf_r == 2'd0) ? BUF0_B_ADDR :
                           (wr_buf_r == 2'd1) ? BUF1_B_ADDR : BUF2_B_ADDR;
assign sdram_wr_e_addr_w = (wr_buf_r == 2'd0) ? BUF0_E_ADDR :
                           (wr_buf_r == 2'd1) ? BUF1_E_ADDR : BUF2_E_ADDR;
assign sdram_rd_b_addr_w = (rd_buf_r == 2'd0) ? BUF0_B_ADDR :
                           (rd_buf_r == 2'd1) ? BUF1_B_ADDR : BUF2_B_ADDR;
assign sdram_rd_e_addr_w = (rd_buf_r == 2'd0) ? BUF0_E_ADDR :
                           (rd_buf_r == 2'd1) ? BUF1_E_ADDR : BUF2_E_ADDR;
assign debug_error_w = {
    13'd0,
    (raw_frame_lines_sys_r != {4'd0, CAM_INPUT_V_PIXEL}),
    (crop_line_pixels_sys_r != {3'd0, active_width_req_w}),
    (crop_frame_lines_sys_r != {4'd0, active_height_req_w})
};

always @(posedge hdmi_pix_clk or negedge rst_n) begin
    if (!rst_n) begin
        zoom_level_meta_hdmi_r <= ZOOM_LEVEL_MIN;
        zoom_level_sync_hdmi_r <= ZOOM_LEVEL_MIN;
        zoom_in_level_meta_hdmi_r <= ZOOM_LEVEL_MIN;
        zoom_in_level_sync_hdmi_r <= ZOOM_LEVEL_MIN;
        hdmi_active_width_r    <= OUTPUT_W_FULL;
        hdmi_active_height_r   <= OUTPUT_H_FULL;
        hdmi_offset_x_r        <= 11'd0;
        hdmi_offset_y_r        <= 11'd0;
        hdmi_end_x_r           <= OUTPUT_W_FULL[10:0];
        hdmi_end_y_r           <= OUTPUT_H_FULL[10:0];
        hdmi_hsync_d1_r  <= 1'b1;
        hdmi_hsync_d2_r  <= 1'b1;
        hdmi_hsync_d3_r  <= 1'b1;
        hdmi_vsync_d1_r  <= 1'b1;
        hdmi_vsync_d2_r  <= 1'b1;
        hdmi_vsync_d3_r  <= 1'b1;
        hdmi_de_d1_r     <= 1'b0;
        hdmi_de_d2_r     <= 1'b0;
        hdmi_de_d3_r     <= 1'b0;
        hdmi_window_d1_r <= 1'b0;
        hdmi_window_d2_r <= 1'b0;
        hdmi_window_d3_r <= 1'b0;
        hdmi_rgb_raw_d1_r <= 24'd0;
        hdmi_rgb_raw_d2_r <= 24'd0;
        hdmi_rgb_raw_d3_r <= 24'd0;
    end else begin
        zoom_level_meta_hdmi_r <= display_zoom_level_100_r;
        zoom_level_sync_hdmi_r <= zoom_level_meta_hdmi_r;
        zoom_in_level_meta_hdmi_r <= display_zoom_in_level_100_r;
        zoom_in_level_sync_hdmi_r <= zoom_in_level_meta_hdmi_r;
        hdmi_active_width_r    <= hdmi_active_width_next_w;
        hdmi_active_height_r   <= hdmi_active_height_next_w;
        hdmi_offset_x_r        <= hdmi_offset_x_next_w;
        hdmi_offset_y_r        <= hdmi_offset_y_next_w;
        hdmi_end_x_r           <= hdmi_end_x_next_w;
        hdmi_end_y_r           <= hdmi_end_y_next_w;
        hdmi_hsync_d1_r   <= video_hs_raw_w;
        hdmi_hsync_d2_r   <= hdmi_hsync_d1_r;
        hdmi_hsync_d3_r   <= hdmi_hsync_d2_r;
        hdmi_vsync_d1_r   <= video_vs_raw_w;
        hdmi_vsync_d2_r   <= hdmi_vsync_d1_r;
        hdmi_vsync_d3_r   <= hdmi_vsync_d2_r;
        hdmi_de_d1_r      <= video_de_raw_w;
        hdmi_de_d2_r      <= hdmi_de_d1_r;
        hdmi_de_d3_r      <= hdmi_de_d2_r;
        hdmi_window_d1_r  <= hdmi_window_raw_w;
        hdmi_window_d2_r  <= hdmi_window_d1_r;
        hdmi_window_d3_r  <= hdmi_window_d2_r;
        hdmi_rgb_raw_d1_r <= video_rgb888_raw_w;
        hdmi_rgb_raw_d2_r <= hdmi_rgb_raw_d1_r;
        hdmi_rgb_raw_d3_r <= hdmi_rgb_raw_d2_r;
    end
end

always @(posedge ov5640_pclk or negedge rst_n) begin
    if (!rst_n) begin
        zoom_level_meta_pclk_r        <= ZOOM_LEVEL_MIN;
        zoom_level_sync_pclk_r        <= ZOOM_LEVEL_MIN;
        zoom_cfg_level_pclk_r         <= ZOOM_LEVEL_MIN;
        zoom_in_level_meta_pclk_r     <= ZOOM_LEVEL_MIN;
        zoom_in_level_sync_pclk_r     <= ZOOM_LEVEL_MIN;
        zoom_in_cfg_level_pclk_r      <= ZOOM_LEVEL_MIN;
        pan_x_meta_pclk_r             <= PAN_CENTER;
        pan_x_sync_pclk_r             <= PAN_CENTER;
        pan_y_meta_pclk_r             <= PAN_CENTER;
        pan_y_sync_pclk_r             <= PAN_CENTER;
        resize_cfg_valid_pclk_r       <= 1'b0;
        resize_cfg_boot_pending_pclk_r<= 1'b1;
        resize_cfg_dirty_pclk_r       <= 1'b0;
        crop_start_x_active_pclk_r    <= 13'd0;
        crop_start_y_active_pclk_r    <= 12'd0;
        crop_width_active_pclk_r      <= CAM_INPUT_H_PIXEL;
        crop_height_active_pclk_r     <= CAM_INPUT_V_PIXEL;
        resize_sof_toggle_pclk_r      <= 1'b0;
        resize_eof_toggle_pclk_r      <= 1'b0;
        ov5640_vsync_d_pclk_r       <= 1'b0;
        ov5640_href_d_pclk_r        <= 1'b0;
        cam_x_pclk_r                <= 13'd0;
        cam_y_pclk_r                <= 12'd0;
        raw_line_pixels_pclk_r      <= 13'd0;
        raw_line_pixels_last_pclk_r <= 13'd0;
        raw_frame_lines_pclk_r      <= 12'd0;
        raw_frame_lines_last_pclk_r <= 12'd0;
        crop_line_pixels_pclk_r     <= 13'd0;
        crop_line_pixels_last_pclk_r<= 13'd0;
        crop_frame_lines_pclk_r     <= 12'd0;
        crop_frame_lines_last_pclk_r<= 12'd0;
        crop_frame_pixels_pclk_r    <= 20'd0;
        crop_frame_pixels_last_pclk_r <= 20'd0;
    end else begin
        zoom_level_meta_pclk_r   <= zoom_level_req_r;
        zoom_level_sync_pclk_r   <= zoom_level_meta_pclk_r;
        zoom_in_level_meta_pclk_r <= zoom_in_level_req_r;
        zoom_in_level_sync_pclk_r <= zoom_in_level_meta_pclk_r;
        pan_x_meta_pclk_r        <= pan_x_req_r;
        pan_x_sync_pclk_r        <= pan_x_meta_pclk_r;
        pan_y_meta_pclk_r        <= pan_y_req_r;
        pan_y_sync_pclk_r        <= pan_y_meta_pclk_r;
        resize_cfg_valid_pclk_r  <= 1'b0;
        if (frame_m_valid_w && frame_m_sof_w) begin
            resize_sof_toggle_pclk_r <= ~resize_sof_toggle_pclk_r;
        end
        if (frame_m_valid_w && frame_m_eof_w) begin
            resize_eof_toggle_pclk_r <= ~resize_eof_toggle_pclk_r;
        end
        ov5640_vsync_d_pclk_r <= ov5640_vsync;
        ov5640_href_d_pclk_r  <= ov5640_href;

        if ((zoom_level_sync_pclk_r != zoom_cfg_level_pclk_r) ||
            (zoom_in_level_sync_pclk_r != zoom_in_cfg_level_pclk_r)) begin
            resize_cfg_dirty_pclk_r <= 1'b1;
        end

        if (!ov5640_vsync_d_pclk_r && ov5640_vsync &&
            (resize_cfg_boot_pending_pclk_r || resize_cfg_dirty_pclk_r)) begin
            zoom_cfg_level_pclk_r          <= zoom_level_sync_pclk_r;
            zoom_in_cfg_level_pclk_r       <= zoom_in_level_sync_pclk_r;
            resize_cfg_valid_pclk_r        <= 1'b1;
            resize_cfg_boot_pending_pclk_r <= 1'b0;
            resize_cfg_dirty_pclk_r        <= 1'b0;
        end

        if (!ov5640_vsync_d_pclk_r && ov5640_vsync) begin
            crop_start_x_active_pclk_r     <= crop_start_x_pclk_w;
            crop_start_y_active_pclk_r     <= crop_start_y_pclk_w;
            crop_width_active_pclk_r       <= crop_width_pclk_w;
            crop_height_active_pclk_r      <= crop_height_pclk_w;
            raw_line_pixels_last_pclk_r   <= raw_line_pixels_pclk_r;
            raw_frame_lines_last_pclk_r   <= raw_frame_lines_pclk_r;
            cam_x_pclk_r                  <= 13'd0;
            cam_y_pclk_r                  <= 12'd0;
            raw_line_pixels_pclk_r        <= 13'd0;
            raw_frame_lines_pclk_r        <= 12'd0;
        end else begin
            if (wr_en) begin
                raw_line_pixels_pclk_r <= raw_line_pixels_pclk_r + 13'd1;
                cam_x_pclk_r           <= cam_x_pclk_r + 13'd1;
            end

            if (ov5640_href_d_pclk_r && !ov5640_href) begin
                raw_line_pixels_last_pclk_r <= raw_line_pixels_pclk_r + (wr_en ? 13'd1 : 13'd0);
                cam_x_pclk_r <= 13'd0;

                if (raw_line_pixels_pclk_r != 13'd0) begin
                    raw_frame_lines_pclk_r <= raw_frame_lines_pclk_r + 12'd1;
                    cam_y_pclk_r <= cam_y_pclk_r + 12'd1;
                end

                raw_line_pixels_pclk_r  <= 13'd0;
            end

            if (resize_active_valid_w) begin
                if (resize_m_eol_w) begin
                    crop_line_pixels_last_pclk_r <= scaled_line_pixels_next_w;
                end

                if (resize_m_eof_w) begin
                    crop_frame_lines_last_pclk_r  <= resize_m_eol_w ? scaled_frame_lines_next_w : crop_frame_lines_pclk_r;
                    crop_frame_pixels_last_pclk_r <= scaled_frame_pixels_next_w;
                    crop_line_pixels_pclk_r       <= 13'd0;
                    crop_frame_lines_pclk_r       <= 12'd0;
                    crop_frame_pixels_pclk_r      <= 20'd0;
                end else begin
                    crop_frame_pixels_pclk_r <= scaled_frame_pixels_next_w;
                    if (resize_m_eol_w) begin
                        crop_line_pixels_pclk_r <= 13'd0;
                        crop_frame_lines_pclk_r <= scaled_frame_lines_next_w;
                    end else begin
                        crop_line_pixels_pclk_r <= scaled_line_pixels_next_w;
                    end
                end
            end
        end
    end
end

always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
        key2_sync_r        <= 2'b11;
        key3_sync_r        <= 2'b11;
        key4_sync_r        <= 2'b11;
        key2_db_cnt_r      <= 20'd0;
        key3_db_cnt_r      <= 20'd0;
        key4_db_cnt_r      <= 20'd0;
        key2_state_r       <= 1'b1;
        key3_state_r       <= 1'b1;
        key4_state_r       <= 1'b1;
        key2_state_d_r     <= 1'b1;
        key3_state_d_r     <= 1'b1;
        key4_state_d_r     <= 1'b1;
        zoom_level_req_r   <= ZOOM_LEVEL_MIN;
        zoom_in_level_req_r <= ZOOM_LEVEL_MIN;
        pan_x_req_r        <= PAN_CENTER;
        pan_y_req_r        <= PAN_CENTER;
        low_light_enable_r <= 1'b0;
        low_light_cfg_valid_r <= 1'b0;
        low_light_cfg_data_r <= 9'sd0;
    end else begin
        key2_sync_r    <= {key2_sync_r[0], key2_n};
        key3_sync_r    <= {key3_sync_r[0], key3_n};
        key4_sync_r    <= {key4_sync_r[0], key4_n};
        key2_state_d_r <= key2_state_r;
        key3_state_d_r <= key3_state_r;
        key4_state_d_r <= key4_state_r;
        low_light_cfg_valid_r <= 1'b0;

        if (key2_sync_r[1] == key2_state_r) begin
            key2_db_cnt_r <= 20'd0;
        end else if (key2_db_cnt_r == KEY_DB_CNT_MAX) begin
            key2_db_cnt_r <= 20'd0;
            key2_state_r  <= key2_sync_r[1];
        end else begin
            key2_db_cnt_r <= key2_db_cnt_r + 20'd1;
        end

        if (key3_sync_r[1] == key3_state_r) begin
            key3_db_cnt_r <= 20'd0;
        end else if (key3_db_cnt_r == KEY_DB_CNT_MAX) begin
            key3_db_cnt_r <= 20'd0;
            key3_state_r  <= key3_sync_r[1];
        end else begin
            key3_db_cnt_r <= key3_db_cnt_r + 20'd1;
        end

        if (key4_sync_r[1] == key4_state_r) begin
            key4_db_cnt_r <= 20'd0;
        end else if (key4_db_cnt_r == KEY_DB_CNT_MAX) begin
            key4_db_cnt_r <= 20'd0;
            key4_state_r  <= key4_sync_r[1];
        end else begin
            key4_db_cnt_r <= key4_db_cnt_r + 20'd1;
        end

        if (uart_lowlight_valid_w) begin
            low_light_enable_r    <= (uart_lowlight_value_w != 9'sd0);
            low_light_cfg_valid_r <= 1'b1;
            low_light_cfg_data_r  <= uart_lowlight_value_w;
        end else if (key4_pressed_w) begin
            low_light_enable_r    <= ~low_light_enable_r;
            low_light_cfg_valid_r <= 1'b1;
            low_light_cfg_data_r  <= low_light_enable_r ? 9'sd0 : LOW_LIGHT_OFFSET_ON;
        end

        if (uart_pan_x_valid_w) begin
            pan_x_req_r <= uart_pan_x_value_w;
        end

        if (uart_pan_y_valid_w) begin
            pan_y_req_r <= uart_pan_y_value_w;
        end

        if (uart_zoom_in_valid_w) begin
            zoom_in_level_req_r <= uart_zoom_in_level_w;
            if (uart_zoom_in_level_w != 8'd0) begin
                zoom_level_req_r <= ZOOM_LEVEL_MIN;
            end
        end

        if (uart_zoom_valid_w) begin
            zoom_level_req_r <= uart_zoom_level_w;
            if (uart_zoom_level_w != 8'd0) begin
                zoom_in_level_req_r <= ZOOM_LEVEL_MIN;
            end
        end else begin
            if (key2_pressed_w) begin
                zoom_in_level_req_r <= ZOOM_LEVEL_MIN;
                if (zoom_level_req_r < ZOOM_LEVEL_MAX) begin
                    if ((ZOOM_LEVEL_MAX - zoom_level_req_r) < ZOOM_KEY_STEP) begin
                        zoom_level_req_r <= ZOOM_LEVEL_MAX;
                    end else begin
                        zoom_level_req_r <= zoom_level_req_r + ZOOM_KEY_STEP;
                    end
                end
            end

            if (key3_pressed_w) begin
                zoom_in_level_req_r <= ZOOM_LEVEL_MIN;
                if (zoom_level_req_r > ZOOM_LEVEL_MIN) begin
                    if (zoom_level_req_r < ZOOM_KEY_STEP) begin
                        zoom_level_req_r <= ZOOM_LEVEL_MIN;
                    end else begin
                        zoom_level_req_r <= zoom_level_req_r - ZOOM_KEY_STEP;
                    end
                end
            end
        end
    end
end

always @(posedge clk_100m or negedge rst_n) begin
    if (!rst_n) begin
        wr_buf_r             <= 2'd1;
        rd_buf_r             <= 2'd0;
        pending_valid_r      <= 1'b0;
        pending_buf_r        <= 2'd0;
        committed_buf_r      <= 2'd0;
        pending_zoom_level_r <= ZOOM_LEVEL_MIN;
        committed_zoom_level_r <= ZOOM_LEVEL_MIN;
        display_zoom_level_100_r <= ZOOM_LEVEL_MIN;
        pending_zoom_in_level_r <= ZOOM_LEVEL_MIN;
        committed_zoom_in_level_r <= ZOOM_LEVEL_MIN;
        display_zoom_in_level_100_r <= ZOOM_LEVEL_MIN;
        cam_vs_100_r         <= 2'b00;
        hdmi_vs_100_r        <= 2'b11;
        resize_sof_toggle_100_r <= 2'b00;
        resize_eof_toggle_100_r <= 2'b00;
        zoom_cfg_level_meta_100_r <= ZOOM_LEVEL_MIN;
        zoom_cfg_level_sync_100_r <= ZOOM_LEVEL_MIN;
        zoom_in_cfg_level_meta_100_r <= ZOOM_LEVEL_MIN;
        zoom_in_cfg_level_sync_100_r <= ZOOM_LEVEL_MIN;
        wr_rst_pulse_r       <= 1'b1;
        rd_rst_pulse_r       <= 1'b1;
        cam_commit_delay_r   <= 13'd0;
    end else begin
        cam_vs_100_r  <= {cam_vs_100_r[0], ov5640_vsync};
        hdmi_vs_100_r <= {hdmi_vs_100_r[0], hdmi_vsync_sys_r};
        resize_sof_toggle_100_r <= {resize_sof_toggle_100_r[0], resize_sof_toggle_pclk_r};
        resize_eof_toggle_100_r <= {resize_eof_toggle_100_r[0], resize_eof_toggle_pclk_r};
        zoom_cfg_level_meta_100_r <= zoom_cfg_level_pclk_r;
        zoom_cfg_level_sync_100_r <= zoom_cfg_level_meta_100_r;
        zoom_in_cfg_level_meta_100_r <= zoom_in_cfg_level_pclk_r;
        zoom_in_cfg_level_sync_100_r <= zoom_in_cfg_level_meta_100_r;
        wr_rst_pulse_r <= 1'b0;
        rd_rst_pulse_r <= 1'b0;

        if (cam_commit_delay_r != 13'd0) begin
            cam_commit_delay_r <= cam_commit_delay_r - 1'b1;
            if (cam_commit_delay_r == 13'd1) begin
                pending_buf_r        <= committed_buf_r;
                pending_zoom_level_r <= committed_zoom_level_r;
                pending_zoom_in_level_r <= committed_zoom_in_level_r;
                pending_valid_r      <= 1'b1;
                wr_buf_r             <= third_buf(rd_buf_next_w, committed_buf_r);
            end
        end

        if (resize_sof_100) begin
            wr_rst_pulse_r <= 1'b1;
        end

        if (hdmi_swap_100) begin
            rd_buf_r             <= pending_buf_r;
            display_zoom_level_100_r <= pending_zoom_level_r;
            display_zoom_in_level_100_r <= pending_zoom_in_level_r;
            pending_valid_r      <= 1'b0;
            rd_rst_pulse_r       <= 1'b1;
        end

        if (resize_eof_100 && (cam_commit_delay_r == 13'd0)) begin
            committed_buf_r        <= wr_buf_r;
            committed_zoom_level_r <= zoom_cfg_level_sync_100_r;
            committed_zoom_in_level_r <= zoom_in_cfg_level_sync_100_r;
            cam_commit_delay_r     <= CAM_COMMIT_DELAY;
        end
    end
end

always @(posedge sys_clk or negedge rst_n) begin
    if (!rst_n) begin
        cfg_done_meta_r        <= 1'b0;
        cfg_done_sys_r         <= 1'b0;
        wr_en_meta_r           <= 1'b0;
        wr_en_sys_r            <= 1'b0;
        cam_data_seen_r        <= 1'b0;
        sdram_init_done_meta_r <= 1'b0;
        sdram_init_done_sys_r  <= 1'b0;
        hdmi_vs_meta_r         <= 1'b1;
        hdmi_vs_sync_r         <= 1'b1;
        hdmi_vs_sync_d_r       <= 1'b1;
        hdmi_vsync_sys_r       <= 1'b1;
        uart_frame_counter_r   <= 16'd0;
        wr_data_sys_r          <= 16'd0;
        rd_data_sys_r          <= 16'd0;
        raw_line_pixels_meta_r <= 16'd0;
        raw_line_pixels_sys_r  <= 16'd0;
        raw_frame_lines_meta_r <= 16'd0;
        raw_frame_lines_sys_r  <= 16'd0;
        crop_line_pixels_meta_r<= 16'd0;
        crop_line_pixels_sys_r <= 16'd0;
        crop_frame_lines_meta_r<= 16'd0;
        crop_frame_lines_sys_r <= 16'd0;
        crop_frame_pixels_meta_r <= 20'd0;
        crop_frame_pixels_sys_r  <= 20'd0;
        cam_dbg_addr_meta_r    <= 16'd0;
        cam_dbg_addr_sys_r     <= 16'd0;
        cam_dbg_data_meta_r    <= 8'd0;
        cam_dbg_data_sys_r     <= 8'd0;
        cam_dbg_ack_meta_r     <= 1'b0;
        cam_dbg_ack_sys_r      <= 1'b0;
        cam_dbg_busy_meta_r    <= 1'b0;
        cam_dbg_busy_sys_r     <= 1'b0;
        cam_dbg_done_meta_r    <= 1'b0;
        cam_dbg_done_sys_r     <= 1'b0;
        cam_dbg_timeout_meta_r <= 1'b0;
        cam_dbg_timeout_sys_r  <= 1'b0;
        cam_dbg_state_meta_r   <= 3'd0;
        cam_dbg_state_sys_r    <= 3'd0;
        cam_dbg_index_meta_r   <= 4'd0;
        cam_dbg_index_sys_r    <= 4'd0;
    end else begin
        cfg_done_meta_r        <= cfg_done;
        cfg_done_sys_r         <= cfg_done_meta_r;
        wr_en_meta_r           <= wr_en;
        wr_en_sys_r            <= wr_en_meta_r;
        if (wr_en_sys_r) begin
            cam_data_seen_r <= 1'b1;
        end
        sdram_init_done_meta_r <= sdram1_init_done;
        sdram_init_done_sys_r  <= sdram_init_done_meta_r;
        hdmi_vs_meta_r         <= hdmi_out_vsync;
        hdmi_vs_sync_r         <= hdmi_vs_meta_r;
        hdmi_vs_sync_d_r       <= hdmi_vs_sync_r;
        hdmi_vsync_sys_r       <= hdmi_out_vsync;
        wr_data_sys_r          <= wr_data;
        rd_data_sys_r          <= rd_data;
        raw_line_pixels_meta_r <= {3'd0, raw_line_pixels_last_pclk_r};
        raw_line_pixels_sys_r  <= raw_line_pixels_meta_r;
        raw_frame_lines_meta_r <= {4'd0, raw_frame_lines_last_pclk_r};
        raw_frame_lines_sys_r  <= raw_frame_lines_meta_r;
        crop_line_pixels_meta_r <= {3'd0, crop_line_pixels_last_pclk_r};
        crop_line_pixels_sys_r  <= crop_line_pixels_meta_r;
        crop_frame_lines_meta_r <= {4'd0, crop_frame_lines_last_pclk_r};
        crop_frame_lines_sys_r  <= crop_frame_lines_meta_r;
        crop_frame_pixels_meta_r <= crop_frame_pixels_last_pclk_r;
        crop_frame_pixels_sys_r  <= crop_frame_pixels_meta_r;
        cam_dbg_addr_meta_r    <= cam_dbg_addr_w;
        cam_dbg_addr_sys_r     <= cam_dbg_addr_meta_r;
        cam_dbg_data_meta_r    <= cam_dbg_data_w;
        cam_dbg_data_sys_r     <= cam_dbg_data_meta_r;
        cam_dbg_ack_meta_r     <= cam_dbg_ack_w;
        cam_dbg_ack_sys_r      <= cam_dbg_ack_meta_r;
        cam_dbg_busy_meta_r    <= cam_dbg_busy_w;
        cam_dbg_busy_sys_r     <= cam_dbg_busy_meta_r;
        cam_dbg_done_meta_r    <= cam_dbg_done_w;
        cam_dbg_done_sys_r     <= cam_dbg_done_meta_r;
        cam_dbg_timeout_meta_r <= cam_dbg_timeout_w;
        cam_dbg_timeout_sys_r  <= cam_dbg_timeout_meta_r;
        cam_dbg_state_meta_r   <= cam_dbg_state_w;
        cam_dbg_state_sys_r    <= cam_dbg_state_meta_r;
        cam_dbg_index_meta_r   <= cam_dbg_index_w;
        cam_dbg_index_sys_r    <= cam_dbg_index_meta_r;

        if (!hdmi_vs_sync_d_r && hdmi_vs_sync_r) begin
            uart_frame_counter_r <= uart_frame_counter_r + 16'd1;
        end
    end
end

clk_gen clk_gen_inst(
    .areset (~sys_rst_n),
    .inclk0 (sys_clk),
    .c0     (clk_100m),
    .c1     (clk_100m_shift),
    .c2     (),
    .c3     (),
    .c4     (sys_clk2),
    .locked (pll1_locked)
);

clk_gen2 clk_gen_inst2(
    .areset (~sys_rst_n),
    .inclk0 (sys_clk2),
    .c0     (clk_25m),
    .c1     (ov5640_xclk),
    .locked (pll2_locked)
);

ov5640_top ov5640_top_inst(
    .sys_clk         (clk_25m),
    .sys_rst_n       (rst_n),
    .sys_init_done   (sys_init_done),
    .ov5640_pclk     (ov5640_pclk),
    .ov5640_href     (ov5640_href),
    .ov5640_vsync    (ov5640_vsync),
    .ov5640_data     (ov5640_data),
    .cfg_done        (cfg_done),
    .sccb_scl        (sccb_scl),
    .sccb_sda        (sccb_sda),
    .ov5640_wr_en    (wr_en),
    .ov5640_data_out (wr_data),
    .dbg_rd_addr_o   (cam_dbg_addr_w),
    .dbg_rd_data_o   (cam_dbg_data_w),
    .dbg_rd_ack_o    (cam_dbg_ack_w),
    .dbg_rd_busy_o   (cam_dbg_busy_w),
    .dbg_rd_done_o   (cam_dbg_done_w),
    .dbg_rd_timeout_o(cam_dbg_timeout_w),
    .dbg_rd_state_o  (cam_dbg_state_w),
    .dbg_rd_index_o  (cam_dbg_index_w)
);

uart_rx #(
    .CLK_HZ (50_000_000),
    .BAUD   (115200)
) uart_rx_inst (
    .clk         (sys_clk),
    .rst_n       (rst_n),
    .rx_i        (uart_rxd),
    .data_o      (uart_rx_data_w),
    .data_valid_o(uart_rx_valid_w)
);

uart_algo_ctrl uart_algo_ctrl_inst (
    .clk             (sys_clk),
    .rst_n           (rst_n),
    .data_i          (uart_rx_data_w),
    .data_valid_i    (uart_rx_valid_w),
    .zoom_valid_o    (uart_zoom_valid_w),
    .zoom_level_o    (uart_zoom_level_w),
    .zoom_in_valid_o (uart_zoom_in_valid_w),
    .zoom_in_level_o (uart_zoom_in_level_w),
    .pan_x_valid_o   (uart_pan_x_valid_w),
    .pan_x_value_o   (uart_pan_x_value_w),
    .pan_y_valid_o   (uart_pan_y_valid_w),
    .pan_y_value_o   (uart_pan_y_value_w),
    .lowlight_valid_o(uart_lowlight_valid_w),
    .lowlight_value_o(uart_lowlight_value_w)
);

bilinear_resize_realtime_stream_std #(
    .MAX_LANES (1),
    .IMG_WIDTH (CAM_INPUT_H_PIXEL),
    .IMG_HEIGHT(CAM_INPUT_V_PIXEL),
    .OUT_WIDTH (H_PIXEL),
    .OUT_HEIGHT(V_PIXEL)
) u_bilinear_resize (
    .clk            (ov5640_pclk),
    .rst_n          (rst_n),
    .s_valid        (resize_s_valid_w),
    .s_ready        (resize_s_ready_w),
    .s_data         (cam_rgb888_w),
    .s_keep         (1'b1),
    .s_sof          (resize_s_sof_w),
    .s_eol          (resize_s_eol_w),
    .s_eof          (resize_s_eof_w),
    .cfg_valid      (resize_cfg_valid_w),
    .cfg_ready      (resize_cfg_ready_w),
    .cfg_in_width   ({3'd0, crop_width_pclk_w}),
    .cfg_in_height  ({4'd0, crop_height_pclk_w}),
    .cfg_out_width  ({3'd0, active_width_cfg_w}),
    .cfg_out_height ({4'd0, active_height_cfg_w}),
    .cfg_scale_x_fp (resize_cfg_scale_x_w),
    .cfg_scale_y_fp (resize_cfg_scale_y_w),
    .m_valid        (resize_m_valid_w),
    .m_ready        (1'b1),
    .m_data         (resize_m_data_w),
    .m_keep         (resize_m_keep_w),
    .m_sof          (resize_m_sof_w),
    .m_eol          (resize_m_eol_w),
    .m_eof          (resize_m_eof_w)
);

sdram_top sdram1_top_inst(
    .sys_clk         (clk_100m),
    .clk_out         (clk_100m_shift),
    .sys_rst_n       (rst_n),
    .wr_fifo_wr_clk  (ov5640_pclk),
    .wr_fifo_wr_req  (wr_en_db),
    .wr_fifo_wr_data (wr_data_sdram_w),
    .sdram_wr_b_addr (sdram_wr_b_addr_w),
    .sdram_wr_e_addr (sdram_wr_e_addr_w),
    .wr_burst_len    (10'd256),
    .wr_rst          (wr_rst_db),
    .rd_fifo_rd_clk  (hdmi_pix_clk),
    .rd_fifo_rd_req  (hdmi_rd_req_w),
    .rd_fifo_rd_data (rd_data),
    .rd_fifo_num     (rd_fifo_num),
    .sdram_rd_b_addr (sdram_rd_b_addr_w),
    .sdram_rd_e_addr (sdram_rd_e_addr_w),
    .rd_burst_len    (10'd256),
    .rd_rst          (rd_rst_db),
    .read_valid      (1'b1),
    .rd_flip_v       (1'b1),
    .pingpang_en     (1'b1),
    .init_end        (sdram1_init_done),
    .sdram_clk       (sdram1_clk),
    .sdram_cke       (sdram1_cke),
    .sdram_cs_n      (sdram1_cs_n),
    .sdram_ras_n     (sdram1_ras_n),
    .sdram_cas_n     (sdram1_cas_n),
    .sdram_we_n      (sdram1_we_n),
    .sdram_ba        (sdram1_ba),
    .sdram_addr      (sdram1addr),
    .sdram_dq        (sdram1_dq)
);

sii9134_ctrl #(
    .CLK_HZ(50_000_000),
    .I2C_HZ(100_000)
) inst_sii9134_ctrl (
    .clk                     (sys_clk),
    .rst_n                   (sys_rst_n),
    .hdmi_reset_n_o          (hdmi_reset_n),
    .i2c_scl_o               (ddc_scl),
    .i2c_sda_oe_o            (hdmi_sda_oe),
    .i2c_sda_i               (hdmi_sda_i),
    .init_done_o             (hdmi_cfg_done),
    .init_error_o            (hdmi_init_error),
    .debug_error_index_o     (),
    .debug_error_use_tpi_o   (),
    .debug_error_timeout_o   ()
);

video_driver video_driver_inst(
    .pixel_clk  (hdmi_pix_clk),
    .sys_rst_n  (rst_n),
    .video_hs   (video_hs_raw_w),
    .video_vs   (video_vs_raw_w),
    .video_de   (video_de_raw_w),
    .video_rgb  (video_rgb_raw_w),
    .data_req   (rd_en),
    .pixel_xpos (pixel_xpos_w),
    .pixel_ypos (pixel_ypos_w),
    .pixel_data (video_pixel_data)
);

darkness_enhance_rgb888_stream_std #(
    .MAX_LANES (1),
    .GAMMA_MODE(2'd1)
) darkness_enhance_inst (
    .clk                     (hdmi_pix_clk),
    .rst_n                   (rst_n),
    .s_valid                 (video_de_raw_w),
    .s_ready                 (low_light_s_ready_w),
    .s_data                  (video_rgb888_raw_w),
    .s_keep                  (video_de_raw_w),
    .s_sof                   (low_light_sof_w),
    .s_eol                   (low_light_eol_w),
    .s_eof                   (low_light_eof_w),
    .cfg_valid               (low_light_cfg_valid_r),
    .cfg_ready               (low_light_cfg_ready_w),
    .cfg_brightness_offset   (low_light_cfg_data_r),
    .active_brightness_offset(low_light_active_offset_w),
    .m_valid                 (low_light_m_valid_w),
    .m_ready                 (1'b1),
    .m_data                  (low_light_m_data_w),
    .m_keep                  (low_light_m_keep_w),
    .m_sof                   (low_light_m_sof_w),
    .m_eol                   (low_light_m_eol_w),
    .m_eof                   (low_light_m_eof_w)
);

uart_diag_mux #(
    .CLK_HZ(50_000_000),
    .BAUD(115200),
    .CHAR_GAP_CYCLES(2000)
) uart_diag_mux_inst (
    .clk                    (sys_clk),
    .rst_n                  (rst_n),
    .hdmi_init_done_i       (hdmi_cfg_done),
    .cam_init_done_i        (cfg_done_sys_r),
    .cam_data_active_i      (cam_data_seen_r),
    .display_camera_i       (1'b1),
    .fb_frame_ready_i       (uart_frame_counter_r != 16'd0),
    .sdram_init_done_i      (sdram_init_done_sys_r),
    .sdram_rd_empty_i       (rd_fifo_num == 10'd0),
    .sdram_rd_usedw_i       (rd_fifo_num),
    .sdram_wr_usedw_i       (10'd0),
    .sdram_underflow_count_i(16'd0),
    .frame_counter_i        (uart_frame_counter_r),
    .line_counter_i         ({4'd0, active_height_req_w}),
    .error_count_i          (debug_error_w),
    .debug_line_pixels_i    (crop_line_pixels_sys_r),
    .debug_frame_lines_i    (crop_frame_lines_sys_r),
    .cam_last_pixel_i       (wr_data_sys_r),
    .cam_dbg_frame_pixels_i (crop_frame_pixels_sys_r),
    .cam_dbg_frame_lines_i  (raw_frame_lines_sys_r),
    .cam_dbg_line_pixels_i  (raw_line_pixels_sys_r),
    .cam_raw_hi_i           (wr_data_sys_r[15:8]),
    .cam_raw_lo_i           (wr_data_sys_r[7:0]),
    .fb_last_pixel_i        (rd_data_sys_r),
    .display_pixel_i        (rd_data_sys_r),
    .cam_dbg_addr_i         (cam_dbg_addr_sys_r),
    .cam_dbg_data_i         (cam_dbg_data_sys_r),
    .cam_dbg_ack_i          (cam_dbg_ack_sys_r),
    .cam_busy_i             (cam_dbg_busy_sys_r),
    .cam_done_i             (cam_dbg_done_sys_r),
    .cam_ack_ok_i           (cam_dbg_ack_sys_r),
    .cam_nack_i             (1'b0),
    .cam_timeout_i          (cam_dbg_timeout_sys_r),
    .cam_dbg_state_i        (cam_dbg_state_sys_r),
    .cam_dbg_index_i        (cam_dbg_index_sys_r),
    .zoom_level_i           ((zoom_in_level_req_r != 8'd0) ? zoom_in_level_req_r : zoom_level_req_r),
    .pan_x_i                (pan_x_req_r),
    .pan_y_i                (pan_y_req_r),
    .low_light_enable_i     (low_light_enable_r),
    .low_light_offset_i     (low_light_cfg_data_r),
    .uart_tx_o              (uart_diag_tx)
);

endmodule
