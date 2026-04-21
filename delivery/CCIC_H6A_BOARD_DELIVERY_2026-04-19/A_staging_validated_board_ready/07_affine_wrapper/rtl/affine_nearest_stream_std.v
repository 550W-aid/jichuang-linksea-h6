`timescale 1ns / 1ps

module affine_nearest_stream_std #(
    parameter integer MAX_LANES  = 1,
    parameter integer IMG_WIDTH  = 1024,
    parameter integer IMG_HEIGHT = 768,
    parameter integer FB_ADDR_W  = 32
) (
    // Core processing clock.
    input  wire                           clk,
    // Active-low asynchronous reset for capture and output control.
    input  wire                           rst_n,

    // Input video-stream valid flag.
    input  wire                           s_valid,
    // Upstream backpressure flag.
    output wire                           s_ready,
    // Packed RGB888 input pixels.
    input  wire [MAX_LANES*24-1:0]        s_data,
    // Per-lane input beat validity mask.
    input  wire [MAX_LANES-1:0]           s_keep,
    // Start-of-frame marker for the input beat.
    input  wire                           s_sof,
    // End-of-line marker for the input beat.
    input  wire                           s_eol,
    // End-of-frame marker for the input beat.
    input  wire                           s_eof,

    // Configuration valid strobe.
    input  wire                           cfg_valid,
    // Configuration ready flag.
    output wire                           cfg_ready,
    // Affine coefficient m00 for the next frame.
    input  wire signed [15:0]             cfg_m00,
    // Affine coefficient m01 for the next frame.
    input  wire signed [15:0]             cfg_m01,
    // Affine coefficient m02 for the next frame.
    input  wire signed [15:0]             cfg_m02,
    // Affine coefficient m10 for the next frame.
    input  wire signed [15:0]             cfg_m10,
    // Affine coefficient m11 for the next frame.
    input  wire signed [15:0]             cfg_m11,
    // Affine coefficient m12 for the next frame.
    input  wire signed [15:0]             cfg_m12,
    // Active affine coefficient m00 for the current frame.
    output wire signed [15:0]             active_m00,
    // Active affine coefficient m01 for the current frame.
    output wire signed [15:0]             active_m01,
    // Active affine coefficient m02 for the current frame.
    output wire signed [15:0]             active_m02,
    // Active affine coefficient m10 for the current frame.
    output wire signed [15:0]             active_m10,
    // Active affine coefficient m11 for the current frame.
    output wire signed [15:0]             active_m11,
    // Active affine coefficient m12 for the current frame.
    output wire signed [15:0]             active_m12,

    // Output video-stream valid flag.
    output reg                            m_valid,
    // Downstream backpressure flag.
    input  wire                           m_ready,
    // Packed RGB888 output pixels.
    output reg  [MAX_LANES*24-1:0]        m_data,
    // Per-lane output beat validity mask.
    output reg  [MAX_LANES-1:0]           m_keep,
    // Start-of-frame marker for the output beat.
    output reg                            m_sof,
    // End-of-line marker for the output beat.
    output reg                            m_eol,
    // End-of-frame marker for the output beat.
    output reg                            m_eof,

    // Frame-buffer write command valid flag.
    output wire                           fb_wr_valid,
    // Frame-buffer write command ready flag.
    input  wire                           fb_wr_ready,
    // External write addresses for the captured input beat.
    output wire [MAX_LANES*FB_ADDR_W-1:0] fb_wr_addr,
    // Input beat data written into the external frame store.
    output wire [MAX_LANES*24-1:0]        fb_wr_data,
    // Per-lane write-enable mask for the external frame store.
    output wire [MAX_LANES-1:0]           fb_wr_keep,
    // Start-of-frame tag aligned with the write beat.
    output wire                           fb_wr_sof,
    // End-of-line tag aligned with the write beat.
    output wire                           fb_wr_eol,
    // End-of-frame tag aligned with the write beat.
    output wire                           fb_wr_eof,

    // Frame-buffer read command valid flag.
    output wire                           fb_rd_cmd_valid,
    // Frame-buffer read command ready flag.
    input  wire                           fb_rd_cmd_ready,
    // External read addresses for the affine output beat.
    output wire [MAX_LANES*FB_ADDR_W-1:0] fb_rd_cmd_addr,
    // Per-lane read-enable mask for in-range affine source samples.
    output wire [MAX_LANES-1:0]           fb_rd_cmd_keep,

    // Frame-buffer read response valid flag.
    input  wire                           fb_rd_rsp_valid,
    // Shell ready flag for the read response channel.
    output wire                           fb_rd_rsp_ready,
    // Read response data returned from the external frame store.
    input  wire [MAX_LANES*24-1:0]        fb_rd_rsp_data
);

    // Return the number of bits required to address a value range.
    function integer clog2;
        input integer value;
        integer tmp_value;
        integer bit_idx;
        begin
            tmp_value = value - 1;
            clog2 = 0;
            for (bit_idx = 0; bit_idx < 32; bit_idx = bit_idx + 1) begin
                if (tmp_value > 0) begin
                    tmp_value = tmp_value >> 1;
                    clog2 = clog2 + 1;
                end
            end
        end
    endfunction

    // Count the number of active lanes in one beat.
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

    localparam integer PIXELS     = IMG_WIDTH * IMG_HEIGHT;
    localparam integer INT_ADDR_W = (PIXELS <= 1) ? 1 : clog2(PIXELS);
    localparam [0:0]   ST_CAPTURE = 1'b0;
    localparam [0:0]   ST_OUTPUT  = 1'b1;

    reg  [0:0]                     state_q;
    reg  [INT_ADDR_W-1:0]          capture_count_q;
    reg  [15:0]                    out_x_q;
    reg  [15:0]                    out_y_q;
    reg                            cmd_pending_q;
    reg  [MAX_LANES-1:0]           pending_keep_q;
    reg  [MAX_LANES-1:0]           pending_rd_keep_q;
    reg                            pending_sof_q;
    reg                            pending_eol_q;
    reg                            pending_eof_q;
    reg  [15:0]                    pending_next_out_x_q;
    reg  [15:0]                    pending_next_out_y_q;

    reg  [MAX_LANES*FB_ADDR_W-1:0] wr_addr_q;
    reg  [INT_ADDR_W-1:0]          capture_count_next_q;
    reg  [MAX_LANES-1:0]           issue_keep_q;
    reg                            issue_valid_q;
    reg                            issue_sof_q;
    reg                            issue_eol_q;
    reg                            issue_eof_q;
    reg  [15:0]                    issue_next_out_x_q;
    reg  [15:0]                    issue_next_out_y_q;

    wire                           frame_start_commit_w;
    wire                           output_slot_ready_w;
    wire                           s_fire_w;
    wire                           rd_cmd_needed_w;
    wire                           addr_pipe_out_ready_w;
    wire                           rd_cmd_fire_w;
    wire                           black_beat_fire_w;
    wire                           rsp_fire_w;

    wire                           addr_pipe_in_ready_w;
    wire                           addr_pipe_out_valid_w;
    wire [MAX_LANES*FB_ADDR_W-1:0] addr_pipe_out_addr_w;
    wire [MAX_LANES-1:0]           addr_pipe_out_keep_w;
    wire [MAX_LANES-1:0]           addr_pipe_out_rd_keep_w;
    wire                           addr_pipe_out_sof_w;
    wire                           addr_pipe_out_eol_w;
    wire                           addr_pipe_out_eof_w;
    wire [15:0]                    addr_pipe_out_next_out_x_w;
    wire [15:0]                    addr_pipe_out_next_out_y_w;

    integer beat_lane_count_v;
    integer lane_idx;
    integer addr_cursor_v;
    integer next_out_x_v;
    integer next_out_y_v;

    assign frame_start_commit_w = s_valid && s_ready && s_sof;
    assign output_slot_ready_w  = (~m_valid) || m_ready;
    assign s_fire_w             = s_valid && s_ready && (|s_keep);

    assign fb_wr_valid = (state_q == ST_CAPTURE) && s_valid && (|s_keep);
    assign fb_wr_addr  = wr_addr_q;
    assign fb_wr_data  = s_data;
    assign fb_wr_keep  = s_keep;
    assign fb_wr_sof   = s_sof;
    assign fb_wr_eol   = s_eol;
    assign fb_wr_eof   = s_eof;

    assign s_ready            = (state_q == ST_CAPTURE) && fb_wr_ready;
    assign rd_cmd_needed_w    = |addr_pipe_out_rd_keep_w;
    assign addr_pipe_out_ready_w = rd_cmd_needed_w ? fb_rd_cmd_ready : output_slot_ready_w;
    assign fb_rd_cmd_valid    = addr_pipe_out_valid_w && rd_cmd_needed_w;
    assign fb_rd_cmd_addr     = addr_pipe_out_addr_w;
    assign fb_rd_cmd_keep     = addr_pipe_out_rd_keep_w;
    assign rd_cmd_fire_w      = addr_pipe_out_valid_w && rd_cmd_needed_w && fb_rd_cmd_ready;
    assign black_beat_fire_w  = addr_pipe_out_valid_w && (~rd_cmd_needed_w) && output_slot_ready_w;
    assign fb_rd_rsp_ready    = cmd_pending_q && output_slot_ready_w;
    assign rsp_fire_w         = cmd_pending_q && fb_rd_rsp_valid && fb_rd_rsp_ready;

    frame_latched_affine6_s16 u_frame_latched_affine6_s16 (
        .clk               (clk),
        .rst_n             (rst_n),
        .cfg_valid         (cfg_valid),
        .cfg_ready         (cfg_ready),
        .cfg_m00           (cfg_m00),
        .cfg_m01           (cfg_m01),
        .cfg_m02           (cfg_m02),
        .cfg_m10           (cfg_m10),
        .cfg_m11           (cfg_m11),
        .cfg_m12           (cfg_m12),
        .frame_start_pulse (frame_start_commit_w),
        .active_m00        (active_m00),
        .active_m01        (active_m01),
        .active_m02        (active_m02),
        .active_m10        (active_m10),
        .active_m11        (active_m11),
        .active_m12        (active_m12),
        .frame_m00         (),
        .frame_m01         (),
        .frame_m02         (),
        .frame_m10         (),
        .frame_m11         (),
        .frame_m12         ()
    );

    affine_nearest_addr_pipe #(
        .MAX_LANES  (MAX_LANES),
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .FB_ADDR_W  (FB_ADDR_W)
    ) u_addr_pipe (
        .clk            (clk),
        .rst_n          (rst_n),
        .in_valid       ((state_q == ST_OUTPUT) && issue_valid_q && (~cmd_pending_q) && addr_pipe_in_ready_w),
        .in_ready       (addr_pipe_in_ready_w),
        .in_m00         (active_m00),
        .in_m01         (active_m01),
        .in_m02         (active_m02),
        .in_m10         (active_m10),
        .in_m11         (active_m11),
        .in_m12         (active_m12),
        .in_out_x       (out_x_q),
        .in_out_y       (out_y_q),
        .in_keep        (issue_keep_q),
        .in_sof         (issue_sof_q),
        .in_eol         (issue_eol_q),
        .in_eof         (issue_eof_q),
        .in_next_out_x  (issue_next_out_x_q),
        .in_next_out_y  (issue_next_out_y_q),
        .out_valid      (addr_pipe_out_valid_w),
        .out_ready      (addr_pipe_out_ready_w),
        .out_addr       (addr_pipe_out_addr_w),
        .out_keep       (addr_pipe_out_keep_w),
        .out_rd_keep    (addr_pipe_out_rd_keep_w),
        .out_sof        (addr_pipe_out_sof_w),
        .out_eol        (addr_pipe_out_eol_w),
        .out_eof        (addr_pipe_out_eof_w),
        .out_next_out_x (addr_pipe_out_next_out_x_w),
        .out_next_out_y (addr_pipe_out_next_out_y_w)
    );

    // Prepare capture write addresses and affine output-beat planning metadata.
    always @* begin
        addr_cursor_v        = s_sof ? 0 : capture_count_q;
        wr_addr_q            = {MAX_LANES*FB_ADDR_W{1'b0}};
        capture_count_next_q = capture_count_q;

        beat_lane_count_v  = IMG_WIDTH - out_x_q;
        issue_keep_q       = {MAX_LANES{1'b0}};
        issue_valid_q      = 1'b0;
        issue_sof_q        = 1'b0;
        issue_eol_q        = 1'b0;
        issue_eof_q        = 1'b0;
        issue_next_out_x_q = out_x_q;
        issue_next_out_y_q = out_y_q;

        if (beat_lane_count_v > MAX_LANES) begin
            beat_lane_count_v = MAX_LANES;
        end
        if (beat_lane_count_v < 0) begin
            beat_lane_count_v = 0;
        end

        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (s_keep[lane_idx]) begin
                wr_addr_q[lane_idx*FB_ADDR_W +: FB_ADDR_W] =
                    {{(FB_ADDR_W-INT_ADDR_W){1'b0}}, addr_cursor_v[INT_ADDR_W-1:0]};
                addr_cursor_v = addr_cursor_v + 1;
            end
        end
        capture_count_next_q = addr_cursor_v[INT_ADDR_W-1:0];

        if ((state_q == ST_OUTPUT) && (beat_lane_count_v > 0)) begin
            issue_valid_q = 1'b1;
            for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                if (lane_idx < beat_lane_count_v) begin
                    issue_keep_q[lane_idx] = 1'b1;
                end
            end
            issue_sof_q = (out_x_q == 16'd0) && (out_y_q == 16'd0);
            issue_eol_q = ((out_x_q + beat_lane_count_v) >= IMG_WIDTH);
            issue_eof_q = (out_y_q == (IMG_HEIGHT - 1)) && issue_eol_q;
            if (issue_eol_q) begin
                next_out_x_v = 0;
                next_out_y_v = out_y_q + 1;
            end else begin
                next_out_x_v = out_x_q + beat_lane_count_v;
                next_out_y_v = out_y_q;
            end
            issue_next_out_x_q = next_out_x_v[15:0];
            issue_next_out_y_q = next_out_y_v[15:0];
        end
    end

    // Manage frame capture, metadata flow, read responses, and black-fill bypass beats.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q              <= ST_CAPTURE;
            capture_count_q      <= {INT_ADDR_W{1'b0}};
            out_x_q              <= 16'd0;
            out_y_q              <= 16'd0;
            cmd_pending_q        <= 1'b0;
            pending_keep_q       <= {MAX_LANES{1'b0}};
            pending_rd_keep_q    <= {MAX_LANES{1'b0}};
            pending_sof_q        <= 1'b0;
            pending_eol_q        <= 1'b0;
            pending_eof_q        <= 1'b0;
            pending_next_out_x_q <= 16'd0;
            pending_next_out_y_q <= 16'd0;
            m_valid              <= 1'b0;
            m_data               <= {MAX_LANES*24{1'b0}};
            m_keep               <= {MAX_LANES{1'b0}};
            m_sof                <= 1'b0;
            m_eol                <= 1'b0;
            m_eof                <= 1'b0;
        end else begin
            if (s_fire_w) begin
                capture_count_q <= capture_count_next_q;
                if (s_eof) begin
                    state_q         <= ST_OUTPUT;
                    capture_count_q <= {INT_ADDR_W{1'b0}};
                    out_x_q         <= 16'd0;
                    out_y_q         <= 16'd0;
                end
            end

            if (rd_cmd_fire_w) begin
                cmd_pending_q        <= 1'b1;
                pending_keep_q       <= addr_pipe_out_keep_w;
                pending_rd_keep_q    <= addr_pipe_out_rd_keep_w;
                pending_sof_q        <= addr_pipe_out_sof_w;
                pending_eol_q        <= addr_pipe_out_eol_w;
                pending_eof_q        <= addr_pipe_out_eof_w;
                pending_next_out_x_q <= addr_pipe_out_next_out_x_w;
                pending_next_out_y_q <= addr_pipe_out_next_out_y_w;
                out_x_q              <= addr_pipe_out_next_out_x_w;
                out_y_q              <= addr_pipe_out_next_out_y_w;
            end

            if (output_slot_ready_w) begin
                if (black_beat_fire_w) begin
                    m_valid <= 1'b1;
                    m_data  <= {MAX_LANES*24{1'b0}};
                    m_keep  <= addr_pipe_out_keep_w;
                    m_sof   <= addr_pipe_out_sof_w;
                    m_eol   <= addr_pipe_out_eol_w;
                    m_eof   <= addr_pipe_out_eof_w;
                    out_x_q <= addr_pipe_out_next_out_x_w;
                    out_y_q <= addr_pipe_out_next_out_y_w;
                    if (addr_pipe_out_eof_w) begin
                        state_q         <= ST_CAPTURE;
                        capture_count_q <= {INT_ADDR_W{1'b0}};
                        out_x_q         <= 16'd0;
                        out_y_q         <= 16'd0;
                    end
                end else if (rsp_fire_w) begin
                    m_valid <= 1'b1;
                    m_keep  <= pending_keep_q;
                    m_sof   <= pending_sof_q;
                    m_eol   <= pending_eol_q;
                    m_eof   <= pending_eof_q;
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (pending_keep_q[lane_idx] && pending_rd_keep_q[lane_idx]) begin
                            m_data[lane_idx*24 +: 24] <= fb_rd_rsp_data[lane_idx*24 +: 24];
                        end else begin
                            m_data[lane_idx*24 +: 24] <= 24'd0;
                        end
                    end
                    cmd_pending_q <= 1'b0;
                    if (pending_eof_q) begin
                        state_q         <= ST_CAPTURE;
                        capture_count_q <= {INT_ADDR_W{1'b0}};
                        out_x_q         <= 16'd0;
                        out_y_q         <= 16'd0;
                    end
                end else begin
                    m_valid <= 1'b0;
                    m_data  <= {MAX_LANES*24{1'b0}};
                    m_keep  <= {MAX_LANES{1'b0}};
                    m_sof   <= 1'b0;
                    m_eol   <= 1'b0;
                    m_eof   <= 1'b0;
                end
            end
        end
    end

endmodule
