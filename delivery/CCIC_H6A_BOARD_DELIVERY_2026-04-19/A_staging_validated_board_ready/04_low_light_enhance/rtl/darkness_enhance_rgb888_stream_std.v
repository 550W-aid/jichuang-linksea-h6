`timescale 1ns / 1ps

module darkness_enhance_rgb888_stream_std #(
    parameter integer MAX_LANES  = 8,
    parameter [1:0]   GAMMA_MODE = 2'd0
) (
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        s_valid,
    output wire                        s_ready,
    input  wire [MAX_LANES*24-1:0]     s_data,
    input  wire [MAX_LANES-1:0]        s_keep,
    input  wire                        s_sof,
    input  wire                        s_eol,
    input  wire                        s_eof,
    input  wire                        cfg_valid,
    output wire                        cfg_ready,
    input  wire signed [8:0]           cfg_brightness_offset,
    output wire signed [8:0]           active_brightness_offset,
    output wire                        m_valid,
    input  wire                        m_ready,
    output wire [MAX_LANES*24-1:0]     m_data,
    output wire [MAX_LANES-1:0]        m_keep,
    output wire                        m_sof,
    output wire                        m_eol,
    output wire                        m_eof
);

    wire                        c0_valid;
    wire                        c0_ready;
    wire [MAX_LANES*24-1:0]     c0_data;
    wire [MAX_LANES-1:0]        c0_keep;
    wire                        c0_sof;
    wire                        c0_eol;
    wire                        c0_eof;

    wire                        c1_valid;
    wire                        c1_ready;
    wire [MAX_LANES*24-1:0]     c1_data;
    wire [MAX_LANES-1:0]        c1_keep;
    wire                        c1_sof;
    wire                        c1_eol;
    wire                        c1_eof;

    wire signed [8:0]           brightness_offset_active;
    wire signed [8:0]           brightness_offset_frame;
    wire                        frame_start_commit;

    assign frame_start_commit        = s_valid && s_ready && s_sof;
    assign active_brightness_offset  = brightness_offset_active;

    frame_latched_s9 u_brightness_latch (
        .clk              (clk),
        .rst_n            (rst_n),
        .cfg_valid        (cfg_valid),
        .cfg_ready        (cfg_ready),
        .cfg_data         (cfg_brightness_offset),
        .frame_start_pulse(frame_start_commit),
        .active_data      (brightness_offset_active),
        .frame_data       (brightness_offset_frame)
    );

    rgb888_to_ycbcr444_stream_std #(
        .MAX_LANES(MAX_LANES)
    ) u_rgb_to_ycbcr (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data (s_data),
        .s_keep (s_keep),
        .s_sof  (s_sof),
        .s_eol  (s_eol),
        .s_eof  (s_eof),
        .m_valid(c0_valid),
        .m_ready(c0_ready),
        .m_data (c0_data),
        .m_keep (c0_keep),
        .m_sof  (c0_sof),
        .m_eol  (c0_eol),
        .m_eof  (c0_eof)
    );

    ycbcr444_luma_gamma_stream_std #(
        .MAX_LANES (MAX_LANES),
        .GAMMA_MODE(GAMMA_MODE)
    ) u_luma_gamma (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(c0_valid),
        .s_ready(c0_ready),
        .s_data (c0_data),
        .s_keep (c0_keep),
        .s_sof  (c0_sof),
        .s_eol  (c0_eol),
        .s_eof  (c0_eof),
        .brightness_offset(brightness_offset_frame),
        .m_valid(c1_valid),
        .m_ready(c1_ready),
        .m_data (c1_data),
        .m_keep (c1_keep),
        .m_sof  (c1_sof),
        .m_eol  (c1_eol),
        .m_eof  (c1_eof)
    );

    ycbcr444_to_rgb888_stream_std #(
        .MAX_LANES(MAX_LANES)
    ) u_ycbcr_to_rgb (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(c1_valid),
        .s_ready(c1_ready),
        .s_data (c1_data),
        .s_keep (c1_keep),
        .s_sof  (c1_sof),
        .s_eol  (c1_eol),
        .s_eof  (c1_eof),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data (m_data),
        .m_keep (m_keep),
        .m_sof  (m_sof),
        .m_eol  (m_eol),
        .m_eof  (m_eof)
    );

endmodule
