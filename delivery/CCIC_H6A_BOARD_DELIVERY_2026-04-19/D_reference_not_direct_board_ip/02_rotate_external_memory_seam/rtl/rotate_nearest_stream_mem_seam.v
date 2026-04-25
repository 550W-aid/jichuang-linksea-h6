`timescale 1ns / 1ps

module rotate_nearest_stream_mem_seam #(
    parameter integer MAX_LANES = 8,
    parameter integer PIXEL_W   = 8,
    parameter integer FRAME_W   = 640,
    parameter integer FRAME_H   = 480,
    parameter integer FB_ADDR_W = $clog2(FRAME_W * FRAME_H)
) (
    input  wire                         clk,              // Core clock for capture, replay planning, and stream handshakes.
    input  wire                         rst_n,            // Active-low reset for the external-memory seam wrapper.
    input  wire                         s_valid,          // Input stream valid for the current capture beat.
    output wire                         s_ready,          // Upstream backpressure tied to capture availability and write-port ready.
    input  wire [MAX_LANES*PIXEL_W-1:0] s_data,           // Packed input pixels for the capture beat.
    input  wire [MAX_LANES-1:0]         s_keep,           // Contiguous valid-lane mask for the capture beat.
    input  wire                         s_sof,            // Start-of-frame marker aligned to the accepted capture beat.
    input  wire                         s_eol,            // End-of-line marker aligned to the accepted capture beat.
    input  wire                         s_eof,            // End-of-frame marker aligned to the accepted capture beat.
    input  wire                         cfg_valid,        // Runtime angle update request.
    output wire                         cfg_ready,        // Runtime angle update interface ready.
    input  wire signed [8:0]            cfg_angle_deg,    // Requested nearest-rotation angle in signed degrees.
    output wire signed [8:0]            active_angle_deg, // Currently committed frame-level angle.
    output wire                         m_valid,          // Rotated output beat valid.
    input  wire                         m_ready,          // Downstream ready for the rotated output beat.
    output wire [MAX_LANES*PIXEL_W-1:0] m_data,           // Packed rotated output pixels.
    output wire [MAX_LANES-1:0]         m_keep,           // Contiguous valid-lane mask for the rotated output beat.
    output wire                         m_sof,            // Start-of-frame marker for the rotated output stream.
    output wire                         m_eol,            // End-of-line marker for the rotated output stream.
    output wire                         m_eof,            // End-of-frame marker for the rotated output stream.
    output wire                         fb_wr_valid,      // External-memory write command valid for the accepted capture beat.
    input  wire                         fb_wr_ready,      // External-memory write command ready.
    output wire [MAX_LANES*FB_ADDR_W-1:0] fb_wr_addr,     // Packed write addresses for every active capture lane.
    output wire [MAX_LANES*PIXEL_W-1:0] fb_wr_data,       // Packed write data for the external frame store.
    output wire [MAX_LANES-1:0]         fb_wr_keep,       // Per-lane write-enable mask for the capture beat.
    output wire                         fb_wr_sof,        // Start-of-frame tag aligned to the external write beat.
    output wire                         fb_wr_eol,        // End-of-line tag aligned to the external write beat.
    output wire                         fb_wr_eof,        // End-of-frame tag aligned to the external write beat.
    output wire                         fb_rd_cmd_valid,  // External-memory read command valid for one rotated output beat.
    input  wire                         fb_rd_cmd_ready,  // External-memory read command ready.
    output wire [MAX_LANES*FB_ADDR_W-1:0] fb_rd_cmd_addr, // Packed read addresses for in-range lanes of the rotated beat.
    output wire [MAX_LANES-1:0]         fb_rd_cmd_keep,   // Per-lane read-enable mask for in-range lanes only.
    input  wire                         fb_rd_rsp_valid,  // External-memory read response valid.
    output wire                         fb_rd_rsp_ready,  // Wrapper ready to accept the packed read response.
    input  wire [MAX_LANES*PIXEL_W-1:0] fb_rd_rsp_data    // Packed readback data from the external memory seam.
);

    localparam integer PIXELS  = FRAME_W * FRAME_H;
    localparam integer COUNT_W = (PIXELS <= 1) ? 1 : $clog2(PIXELS + 1);

    integer lane_idx;

    reg [COUNT_W-1:0]          capture_count_q;
    reg                        capture_open_q;
    reg                        drain_busy_q;

    wire [COUNT_W-1:0]         capture_base_w;
    wire [COUNT_W-1:0]         capture_count_next_w;
    wire [COUNT_W-1:0]         keep_count_w;
    wire                       capture_allow_w;
    wire                       capture_fire_w;
    wire                       frame_start_commit_w;
    wire                       frame_done_fire_w;
    wire signed [8:0]          frame_angle_deg_w;
    wire signed [8:0]          angle_active_w;

    wire                       replay_m_valid_w;
    wire [MAX_LANES*PIXEL_W-1:0] replay_m_data_w;
    wire [MAX_LANES-1:0]       replay_m_keep_w;
    wire                       replay_m_sof_w;
    wire                       replay_m_eol_w;
    wire                       replay_m_eof_w;

    reg  [MAX_LANES*FB_ADDR_W-1:0] fb_wr_addr_r;

    // Count the number of valid lanes in one stream beat.
    function integer popcount_keep;
        input [MAX_LANES-1:0] keep_mask;
        integer keep_idx;
        begin
            popcount_keep = 0;
            for (keep_idx = 0; keep_idx < MAX_LANES; keep_idx = keep_idx + 1) begin
                if (keep_mask[keep_idx]) begin
                    popcount_keep = popcount_keep + 1;
                end
            end
        end
    endfunction

    assign keep_count_w         = popcount_keep(s_keep);
    assign capture_base_w       = s_sof ? {COUNT_W{1'b0}} : capture_count_q;
    assign capture_count_next_w = capture_base_w + keep_count_w;
    assign capture_allow_w      = capture_open_q || !drain_busy_q;
    assign s_ready              = capture_allow_w && fb_wr_ready;
    assign capture_fire_w       = s_valid && s_ready && (|s_keep);
    assign frame_start_commit_w = capture_fire_w && s_sof;
    assign frame_done_fire_w    = replay_m_valid_w && m_ready && replay_m_eof_w;

    assign fb_wr_valid = capture_allow_w && s_valid && (|s_keep);
    assign fb_wr_addr  = fb_wr_addr_r;
    assign fb_wr_data  = s_data;
    assign fb_wr_keep  = s_keep;
    assign fb_wr_sof   = s_sof;
    assign fb_wr_eol   = s_eol;
    assign fb_wr_eof   = s_eof;

    assign active_angle_deg = angle_active_w;
    assign m_valid          = replay_m_valid_w;
    assign m_data           = replay_m_data_w;
    assign m_keep           = replay_m_keep_w;
    assign m_sof            = replay_m_sof_w;
    assign m_eol            = replay_m_eol_w;
    assign m_eof            = replay_m_eof_w;

    // Generate one sequential write address per active capture lane.
    always @* begin
        fb_wr_addr_r = {MAX_LANES*FB_ADDR_W{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (s_keep[lane_idx]) begin
                fb_wr_addr_r[lane_idx*FB_ADDR_W +: FB_ADDR_W] = capture_base_w + lane_idx;
            end
        end
    end

    frame_latched_s9 u_input_angle_latch (
        .clk              (clk),
        .rst_n            (rst_n),
        .cfg_valid        (cfg_valid),
        .cfg_ready        (cfg_ready),
        .cfg_data         (cfg_angle_deg),
        .frame_start_pulse(frame_start_commit_w),
        .active_data      (angle_active_w),
        .frame_data       (frame_angle_deg_w)
    );

    rotate_nearest_multilane_readback_path #(
        .MAX_LANES(MAX_LANES),
        .PIXEL_W  (PIXEL_W),
        .IMAGE_W  (FRAME_W),
        .IMAGE_H  (FRAME_H)
    ) u_readback_path (
        .clk            (clk),
        .rst_n          (rst_n),
        .start_valid    (capture_fire_w && s_eof),
        .frame_pixels   (capture_count_next_w),
        .frame_angle_deg(frame_angle_deg_w),
        .rd_req_valid   (fb_rd_cmd_valid),
        .rd_req_ready   (fb_rd_cmd_ready),
        .rd_req_keep    (fb_rd_cmd_keep),
        .rd_req_zero    (),
        .rd_req_addr    (fb_rd_cmd_addr),
        .rd_rsp_valid   (fb_rd_rsp_valid),
        .rd_rsp_ready   (fb_rd_rsp_ready),
        .rd_rsp_data    (fb_rd_rsp_data),
        .m_valid        (replay_m_valid_w),
        .m_ready        (m_ready),
        .m_data         (replay_m_data_w),
        .m_keep         (replay_m_keep_w),
        .m_sof          (replay_m_sof_w),
        .m_eol          (replay_m_eol_w),
        .m_eof          (replay_m_eof_w)
    );

    // Track capture-side admission and ensure the next frame waits until the previous replay finishes.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            capture_open_q <= 1'b0;
            drain_busy_q   <= 1'b0;
        end else begin
            if (capture_fire_w && s_sof) begin
                capture_open_q <= 1'b1;
            end

            if (capture_fire_w && s_eof) begin
                capture_open_q <= 1'b0;
                drain_busy_q   <= 1'b1;
            end

            if (frame_done_fire_w) begin
                drain_busy_q <= 1'b0;
            end
        end
    end

    // Count how many valid pixels have been captured for the frame that is currently being written.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            capture_count_q <= {COUNT_W{1'b0}};
        end else if (capture_fire_w) begin
            if (s_eof) begin
                capture_count_q <= {COUNT_W{1'b0}};
            end else begin
                capture_count_q <= capture_count_next_w;
            end
        end
    end

endmodule
