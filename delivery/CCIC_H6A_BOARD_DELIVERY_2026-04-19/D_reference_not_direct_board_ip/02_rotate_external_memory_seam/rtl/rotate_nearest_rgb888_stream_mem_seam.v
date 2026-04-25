`timescale 1ns / 1ps

module rotate_nearest_rgb888_stream_mem_seam #(
    parameter integer MAX_LANES = 8,
    parameter integer FRAME_W   = 640,
    parameter integer FRAME_H   = 480,
    parameter integer FB_ADDR_W = $clog2(FRAME_W * FRAME_H)
) (
    input  wire                         clk,              // Core clock for RGB888 capture and replay.
    input  wire                         rst_n,            // Active-low reset for the RGB888 wrapper.
    input  wire                         s_valid,          // Input RGB beat valid.
    output wire                         s_ready,          // Upstream backpressure from the generic memory-seam wrapper.
    input  wire [MAX_LANES*24-1:0]      s_data,           // Packed RGB888 input pixels.
    input  wire [MAX_LANES-1:0]         s_keep,           // Contiguous valid-lane mask for the input RGB beat.
    input  wire                         s_sof,            // Start-of-frame marker for the input RGB beat.
    input  wire                         s_eol,            // End-of-line marker for the input RGB beat.
    input  wire                         s_eof,            // End-of-frame marker for the input RGB beat.
    input  wire                         cfg_valid,        // Runtime angle update request.
    output wire                         cfg_ready,        // Runtime angle interface ready.
    input  wire signed [8:0]            cfg_angle_deg,    // Requested nearest-rotation angle in signed degrees.
    output wire signed [8:0]            active_angle_deg, // Currently committed frame-level angle.
    output wire                         m_valid,          // Rotated RGB output beat valid.
    input  wire                         m_ready,          // Downstream ready for the rotated RGB beat.
    output wire [MAX_LANES*24-1:0]      m_data,           // Packed rotated RGB888 output pixels.
    output wire [MAX_LANES-1:0]         m_keep,           // Contiguous valid-lane mask for the rotated RGB beat.
    output wire                         m_sof,            // Start-of-frame marker for the rotated RGB output stream.
    output wire                         m_eol,            // End-of-line marker for the rotated RGB output stream.
    output wire                         m_eof,            // End-of-frame marker for the rotated RGB output stream.
    output wire                         fb_wr_valid,      // External-memory write command valid.
    input  wire                         fb_wr_ready,      // External-memory write command ready.
    output wire [MAX_LANES*FB_ADDR_W-1:0] fb_wr_addr,     // Packed write addresses for the capture beat.
    output wire [MAX_LANES*24-1:0]      fb_wr_data,       // Packed RGB888 write data.
    output wire [MAX_LANES-1:0]         fb_wr_keep,       // Per-lane write-enable mask.
    output wire                         fb_wr_sof,        // Start-of-frame tag aligned to the write beat.
    output wire                         fb_wr_eol,        // End-of-line tag aligned to the write beat.
    output wire                         fb_wr_eof,        // End-of-frame tag aligned to the write beat.
    output wire                         fb_rd_cmd_valid,  // External-memory read command valid.
    input  wire                         fb_rd_cmd_ready,  // External-memory read command ready.
    output wire [MAX_LANES*FB_ADDR_W-1:0] fb_rd_cmd_addr, // Packed read addresses for in-range lanes.
    output wire [MAX_LANES-1:0]         fb_rd_cmd_keep,   // Per-lane read-enable mask for in-range lanes.
    input  wire                         fb_rd_rsp_valid,  // External-memory read response valid.
    output wire                         fb_rd_rsp_ready,  // Wrapper ready to accept the RGB888 response beat.
    input  wire [MAX_LANES*24-1:0]      fb_rd_rsp_data    // Packed RGB888 readback data.
);

    rotate_nearest_stream_mem_seam #(
        .MAX_LANES(MAX_LANES),
        .PIXEL_W  (24),
        .FRAME_W  (FRAME_W),
        .FRAME_H  (FRAME_H),
        .FB_ADDR_W(FB_ADDR_W)
    ) u_rotate_nearest_stream_mem_seam (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_valid        (s_valid),
        .s_ready        (s_ready),
        .s_data         (s_data),
        .s_keep         (s_keep),
        .s_sof          (s_sof),
        .s_eol          (s_eol),
        .s_eof          (s_eof),
        .cfg_valid      (cfg_valid),
        .cfg_ready      (cfg_ready),
        .cfg_angle_deg  (cfg_angle_deg),
        .active_angle_deg(active_angle_deg),
        .m_valid        (m_valid),
        .m_ready        (m_ready),
        .m_data         (m_data),
        .m_keep         (m_keep),
        .m_sof          (m_sof),
        .m_eol          (m_eol),
        .m_eof          (m_eof),
        .fb_wr_valid    (fb_wr_valid),
        .fb_wr_ready    (fb_wr_ready),
        .fb_wr_addr     (fb_wr_addr),
        .fb_wr_data     (fb_wr_data),
        .fb_wr_keep     (fb_wr_keep),
        .fb_wr_sof      (fb_wr_sof),
        .fb_wr_eol      (fb_wr_eol),
        .fb_wr_eof      (fb_wr_eof),
        .fb_rd_cmd_valid(fb_rd_cmd_valid),
        .fb_rd_cmd_ready(fb_rd_cmd_ready),
        .fb_rd_cmd_addr (fb_rd_cmd_addr),
        .fb_rd_cmd_keep (fb_rd_cmd_keep),
        .fb_rd_rsp_valid(fb_rd_rsp_valid),
        .fb_rd_rsp_ready(fb_rd_rsp_ready),
        .fb_rd_rsp_data (fb_rd_rsp_data)
    );

endmodule
