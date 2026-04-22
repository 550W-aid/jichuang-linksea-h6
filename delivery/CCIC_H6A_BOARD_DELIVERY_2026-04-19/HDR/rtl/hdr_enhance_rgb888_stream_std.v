`timescale 1ns / 1ps

module hdr_enhance_rgb888_stream_std #(
    parameter integer MAX_LANES = 8
) (
    input  wire                        clk,                    // Processing clock.
    input  wire                        rst_n,                  // Active-low reset.
    input  wire                        s_valid,                // Input beat valid.
    output wire                        s_ready,                // Input beat ready.
    input  wire [MAX_LANES*24-1:0]     s_data,                 // Input RGB888 stream data.
    input  wire [MAX_LANES-1:0]        s_keep,                 // Input lane keep mask.
    input  wire                        s_sof,                  // Input start-of-frame marker.
    input  wire                        s_eol,                  // Input end-of-line marker.
    input  wire                        s_eof,                  // Input end-of-frame marker.
    input  wire                        cfg_valid,              // Config update valid strobe.
    output wire                        cfg_ready,              // Config update ready strobe.
    input  wire [1:0]                  cfg_shadow_level,       // Pending shadow lift level.
    input  wire [1:0]                  cfg_highlight_level,    // Pending highlight compression level.
    output wire [1:0]                  active_shadow_level,    // Active frame shadow lift level.
    output wire [1:0]                  active_highlight_level, // Active frame highlight compression level.
    output wire                        m_valid,                // Output beat valid.
    input  wire                        m_ready,                // Output beat ready.
    output wire [MAX_LANES*24-1:0]     m_data,                 // Output RGB888 stream data.
    output wire [MAX_LANES-1:0]        m_keep,                 // Output lane keep mask.
    output wire                        m_sof,                  // Output start-of-frame marker.
    output wire                        m_eol,                  // Output end-of-line marker.
    output wire                        m_eof                   // Output end-of-frame marker.
);

    wire                        c0_valid;                      // RGB->YCbCr stage valid.
    wire                        c0_ready;                      // RGB->YCbCr stage ready.
    wire [MAX_LANES*24-1:0]     c0_data;                       // RGB->YCbCr stage data.
    wire [MAX_LANES-1:0]        c0_keep;                       // RGB->YCbCr stage keep.
    wire                        c0_sof;                        // RGB->YCbCr stage SOF.
    wire                        c0_eol;                        // RGB->YCbCr stage EOL.
    wire                        c0_eof;                        // RGB->YCbCr stage EOF.

    wire                        c1_valid;                      // Tone-map stage valid.
    wire                        c1_ready;                      // Tone-map stage ready.
    wire [MAX_LANES*24-1:0]     c1_data;                       // Tone-map stage data.
    wire [MAX_LANES-1:0]        c1_keep;                       // Tone-map stage keep.
    wire                        c1_sof;                        // Tone-map stage SOF.
    wire                        c1_eol;                        // Tone-map stage EOL.
    wire                        c1_eof;                        // Tone-map stage EOF.

    wire                        frame_start_commit;            // Commit point for frame-latched controls.
    wire [1:0]                  shadow_level_frame;            // Effective shadow level for current frame-start beat.
    wire [1:0]                  highlight_level_frame;         // Effective highlight level for current frame-start beat.
    wire                        cfg_shadow_ready;              // Shadow level config ready.
    wire                        cfg_highlight_ready;           // Highlight level config ready.

    assign frame_start_commit      = s_valid && s_ready && s_sof;
    assign cfg_ready               = cfg_shadow_ready & cfg_highlight_ready;
    assign active_shadow_level     = shadow_level_frame;
    assign active_highlight_level  = highlight_level_frame;

    frame_latched_u2 u_shadow_level_latch (
        .clk              (clk),
        .rst_n            (rst_n),
        .cfg_valid        (cfg_valid),
        .cfg_ready        (cfg_shadow_ready),
        .cfg_data         (cfg_shadow_level),
        .frame_start_pulse(frame_start_commit),
        .active_data      (),
        .frame_data       (shadow_level_frame)
    );

    frame_latched_u2 u_highlight_level_latch (
        .clk              (clk),
        .rst_n            (rst_n),
        .cfg_valid        (cfg_valid),
        .cfg_ready        (cfg_highlight_ready),
        .cfg_data         (cfg_highlight_level),
        .frame_start_pulse(frame_start_commit),
        .active_data      (),
        .frame_data       (highlight_level_frame)
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

    hdr_luma_tonemap_stream_std #(
        .MAX_LANES(MAX_LANES)
    ) u_hdr_luma_tonemap (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_valid        (c0_valid),
        .s_ready        (c0_ready),
        .s_data         (c0_data),
        .s_keep         (c0_keep),
        .s_sof          (c0_sof),
        .s_eol          (c0_eol),
        .s_eof          (c0_eof),
        .shadow_level   (shadow_level_frame),
        .highlight_level(highlight_level_frame),
        .m_valid        (c1_valid),
        .m_ready        (c1_ready),
        .m_data         (c1_data),
        .m_keep         (c1_keep),
        .m_sof          (c1_sof),
        .m_eol          (c1_eol),
        .m_eof          (c1_eof)
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

