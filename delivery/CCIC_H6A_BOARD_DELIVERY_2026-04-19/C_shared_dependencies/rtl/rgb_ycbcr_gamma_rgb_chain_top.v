`timescale 1ns / 1ps

module rgb_ycbcr_gamma_rgb_chain_top (
    // Core processing clock.
    input  wire        clk,
    // Active-low asynchronous reset for the whole chain.
    input  wire        rst_n,
    // Input video-stream valid flag.
    input  wire        s_valid,
    // Upstream backpressure flag.
    output wire        s_ready,
    // RGB888 input pixel.
    input  wire [23:0] s_data,
    // Input beat validity mask. This top consumes exactly one lane.
    input  wire        s_keep,
    // Start-of-frame marker for the input beat.
    input  wire        s_sof,
    // End-of-line marker for the input beat.
    input  wire        s_eol,
    // End-of-frame marker for the input beat.
    input  wire        s_eof,
    // Brightness configuration valid strobe.
    input  wire        cfg_valid,
    // Brightness configuration ready flag.
    output wire        cfg_ready,
    // Brightness offset to be committed on the next frame boundary.
    input  wire signed [8:0] cfg_brightness_offset,
    // Active brightness offset for the frame currently being processed.
    output wire signed [8:0] active_brightness_offset,
    // Output video-stream valid flag.
    output wire        m_valid,
    // Downstream backpressure flag.
    input  wire        m_ready,
    // RGB888 output pixel after YCbCr and gamma processing.
    output wire [23:0] m_data,
    // Output beat validity mask.
    output wire        m_keep,
    // Start-of-frame marker for the output beat.
    output wire        m_sof,
    // End-of-line marker for the output beat.
    output wire        m_eol,
    // End-of-frame marker for the output beat.
    output wire        m_eof
);

    wire        frame_start_commit_w;
    wire [23:0] ycbcr_data_w;
    wire        ycbcr_valid_w;
    wire        ycbcr_ready_w;
    wire        ycbcr_keep_w;
    wire        ycbcr_sof_w;
    wire        ycbcr_eol_w;
    wire        ycbcr_eof_w;

    wire [23:0] gamma_data_w;
    wire        gamma_valid_w;
    wire        gamma_ready_w;
    wire        gamma_keep_w;
    wire        gamma_sof_w;
    wire        gamma_eol_w;
    wire        gamma_eof_w;
    wire signed [8:0] brightness_offset_frame_w;

    assign frame_start_commit_w = s_valid && s_ready && s_sof;

    frame_latched_s9 u_brightness_latch (
        .clk               (clk),
        .rst_n             (rst_n),
        .cfg_valid         (cfg_valid),
        .cfg_ready         (cfg_ready),
        .cfg_data          (cfg_brightness_offset),
        .frame_start_pulse (frame_start_commit_w),
        .active_data       (active_brightness_offset),
        .frame_data        (brightness_offset_frame_w)
    );

    rgb888_to_ycbcr444_stream_std #(
        .MAX_LANES (1)
    ) u_rgb888_to_ycbcr444 (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data (s_data),
        .s_keep (s_keep),
        .s_sof  (s_sof),
        .s_eol  (s_eol),
        .s_eof  (s_eof),
        .m_valid(ycbcr_valid_w),
        .m_ready(ycbcr_ready_w),
        .m_data (ycbcr_data_w),
        .m_keep (ycbcr_keep_w),
        .m_sof  (ycbcr_sof_w),
        .m_eol  (ycbcr_eol_w),
        .m_eof  (ycbcr_eof_w)
    );

    ycbcr444_luma_gamma_stream_std #(
        .MAX_LANES  (1),
        .GAMMA_MODE (2'd0)
    ) u_ycbcr444_luma_gamma (
        .clk              (clk),
        .rst_n            (rst_n),
        .s_valid          (ycbcr_valid_w),
        .s_ready          (ycbcr_ready_w),
        .s_data           (ycbcr_data_w),
        .s_keep           (ycbcr_keep_w),
        .s_sof            (ycbcr_sof_w),
        .s_eol            (ycbcr_eol_w),
        .s_eof            (ycbcr_eof_w),
        .brightness_offset(brightness_offset_frame_w),
        .m_valid          (gamma_valid_w),
        .m_ready          (gamma_ready_w),
        .m_data           (gamma_data_w),
        .m_keep           (gamma_keep_w),
        .m_sof            (gamma_sof_w),
        .m_eol            (gamma_eol_w),
        .m_eof            (gamma_eof_w)
    );

    ycbcr444_to_rgb888_stream_std #(
        .MAX_LANES (1)
    ) u_ycbcr444_to_rgb888 (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(gamma_valid_w),
        .s_ready(gamma_ready_w),
        .s_data (gamma_data_w),
        .s_keep (gamma_keep_w),
        .s_sof  (gamma_sof_w),
        .s_eol  (gamma_eol_w),
        .s_eof  (gamma_eof_w),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data (m_data),
        .m_keep (m_keep),
        .m_sof  (m_sof),
        .m_eol  (m_eol),
        .m_eof  (m_eof)
    );

endmodule
