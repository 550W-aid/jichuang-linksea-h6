`timescale 1ns / 1ps

module gray_threshold_dilate_chain_top #(
    parameter integer IMG_WIDTH  = 640,
    parameter integer IMG_HEIGHT = 480
) (
    // Core processing clock.
    input  wire       clk,
    // Active-low asynchronous reset for the whole chain.
    input  wire       rst_n,
    // Input video-stream valid flag.
    input  wire       s_valid,
    // Upstream backpressure flag.
    output wire       s_ready,
    // RGB888 input pixel.
    input  wire [23:0] s_data,
    // Input beat validity mask. This top consumes exactly one lane.
    input  wire       s_keep,
    // Start-of-frame marker for the input beat.
    input  wire       s_sof,
    // End-of-line marker for the input beat.
    input  wire       s_eol,
    // End-of-frame marker for the input beat.
    input  wire       s_eof,
    // Output video-stream valid flag.
    output wire       m_valid,
    // Downstream backpressure flag.
    input  wire       m_ready,
    // Binary dilation output pixel.
    output wire [7:0] m_data,
    // Output beat validity mask.
    output wire       m_keep,
    // Start-of-frame marker for the output beat.
    output wire       m_sof,
    // End-of-line marker for the output beat.
    output wire       m_eol,
    // End-of-frame marker for the output beat.
    output wire       m_eof
);

    wire        gray_valid_w;
    wire        gray_ready_w;
    wire [7:0]  gray_data_w;
    wire        gray_keep_w;
    wire        gray_sof_w;
    wire        gray_eol_w;
    wire        gray_eof_w;

    wire        threshold_valid_w;
    wire        threshold_ready_w;
    wire [7:0]  threshold_data_w;
    wire        threshold_keep_w;
    wire        threshold_sof_w;
    wire        threshold_eol_w;
    wire        threshold_eof_w;

    wire        window_valid_w;
    wire        window_ready_w;
    wire [71:0] window_data_w;
    wire        window_keep_w;
    wire        window_sof_w;
    wire        window_eol_w;
    wire        window_eof_w;

    grayscale_stream_std #(
        .MAX_LANES (1),
        .PIX_W_IN  (24),
        .PIX_W_OUT (8)
    ) u_grayscale (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data (s_data),
        .s_keep (s_keep),
        .s_sof  (s_sof),
        .s_eol  (s_eol),
        .s_eof  (s_eof),
        .m_valid(gray_valid_w),
        .m_ready(gray_ready_w),
        .m_data (gray_data_w),
        .m_keep (gray_keep_w),
        .m_sof  (gray_sof_w),
        .m_eol  (gray_eol_w),
        .m_eof  (gray_eof_w)
    );

    binary_threshold_stream_std #(
        .MAX_LANES (1),
        .DATA_W    (8),
        .THRESHOLD (8'd128)
    ) u_binary_threshold (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(gray_valid_w),
        .s_ready(gray_ready_w),
        .s_data (gray_data_w),
        .s_keep (gray_keep_w),
        .s_sof  (gray_sof_w),
        .s_eol  (gray_eol_w),
        .s_eof  (gray_eof_w),
        .m_valid(threshold_valid_w),
        .m_ready(threshold_ready_w),
        .m_data (threshold_data_w),
        .m_keep (threshold_keep_w),
        .m_sof  (threshold_sof_w),
        .m_eol  (threshold_eol_w),
        .m_eof  (threshold_eof_w)
    );

    // The current delivery window builder is board-safe only at MAX_LANES=1.
    window3x3_stream_std #(
        .MAX_LANES  (1),
        .DATA_W     (8),
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT)
    ) u_window3x3 (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(threshold_valid_w),
        .s_ready(threshold_ready_w),
        .s_data (threshold_data_w),
        .s_keep (threshold_keep_w),
        .s_sof  (threshold_sof_w),
        .s_eol  (threshold_eol_w),
        .s_eof  (threshold_eof_w),
        .m_valid(window_valid_w),
        .m_ready(window_ready_w),
        .m_data (window_data_w),
        .m_keep (window_keep_w),
        .m_sof  (window_sof_w),
        .m_eol  (window_eol_w),
        .m_eof  (window_eof_w)
    );

    dilate3x3_binary_stream_std #(
        .MAX_LANES (1),
        .DATA_W    (8)
    ) u_dilate3x3 (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(window_valid_w),
        .s_ready(window_ready_w),
        .s_data (window_data_w),
        .s_keep (window_keep_w),
        .s_sof  (window_sof_w),
        .s_eol  (window_eol_w),
        .s_eof  (window_eof_w),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data (m_data),
        .m_keep (m_keep),
        .m_sof  (m_sof),
        .m_eol  (m_eol),
        .m_eof  (m_eof)
    );

endmodule
