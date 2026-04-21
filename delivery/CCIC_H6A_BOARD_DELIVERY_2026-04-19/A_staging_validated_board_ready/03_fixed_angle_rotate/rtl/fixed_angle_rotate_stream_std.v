`timescale 1ns / 1ps

module fixed_angle_rotate_stream_std #(
    parameter integer MAX_LANES  = 8,
    parameter integer IMG_WIDTH  = 640,
    parameter integer IMG_HEIGHT = 480,
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
    // Fixed-angle selector to be committed on the next frame boundary.
    input  wire [1:0]                     cfg_angle_sel,
    // Active fixed-angle selector for the frame currently being processed.
    output wire [1:0]                     active_angle_sel,

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
    // External read addresses for the rotated output beat.
    output wire [MAX_LANES*FB_ADDR_W-1:0] fb_rd_cmd_addr,
    // Per-lane read-enable mask for the rotated output beat.
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

    // Report the output frame width for the selected rotation.
    function [15:0] output_width_for_angle;
        input [1:0] angle_sel;
        begin
            if ((angle_sel == 2'd1) || (angle_sel == 2'd3)) begin
                output_width_for_angle = IMG_HEIGHT;
            end else begin
                output_width_for_angle = IMG_WIDTH;
            end
        end
    endfunction

    // Report the output frame height for the selected rotation.
    function [15:0] output_height_for_angle;
        input [1:0] angle_sel;
        begin
            if ((angle_sel == 2'd1) || (angle_sel == 2'd3)) begin
                output_height_for_angle = IMG_WIDTH;
            end else begin
                output_height_for_angle = IMG_HEIGHT;
            end
        end
    endfunction

    localparam integer PIXELS      = IMG_WIDTH * IMG_HEIGHT;
    localparam integer INT_ADDR_W  = (PIXELS <= 1) ? 1 : clog2(PIXELS);
    localparam integer BEAT_COUNT_W = (MAX_LANES <= 1) ? 1 : clog2(MAX_LANES + 1);
    localparam [0:0]   ST_CAPTURE  = 1'b0;
    localparam [0:0]   ST_OUTPUT   = 1'b1;
    localparam [15:0]  MAX_LANES_U16 = MAX_LANES;
    localparam [BEAT_COUNT_W-1:0] MAX_LANES_COUNT_W = MAX_LANES;

    reg  [0:0]                       state_q;
    reg  [INT_ADDR_W-1:0]            capture_count_q;
    reg  [15:0]                      out_x_q;
    reg  [15:0]                      out_y_q;
    reg  [15:0]                      issue_out_x_q;
    reg  [15:0]                      issue_out_y_q;
    reg                              cmd_pending_q;
    reg  [MAX_LANES-1:0]             pending_keep_q;
    reg                              pending_sof_q;
    reg                              pending_eol_q;
    reg                              pending_eof_q;
    reg  [15:0]                      pending_next_out_x_q;
    reg  [15:0]                      pending_next_out_y_q;

    reg  [MAX_LANES*FB_ADDR_W-1:0]   wr_addr_q;
    reg  [INT_ADDR_W-1:0]            capture_count_next_q;
    reg  [MAX_LANES-1:0]             issue_keep_q;
    reg                              issue_valid_q;
    reg                              issue_sof_q;
    reg                              issue_eol_q;
    reg                              issue_eof_q;
    reg  [15:0]                      issue_next_out_x_q;
    reg  [15:0]                      issue_next_out_y_q;

    wire [1:0]                       angle_active_w;
    wire                             frame_start_commit_w;
    wire                             output_slot_ready_w;
    wire                             s_fire_w;

    wire                             addr_pipe_in_ready_w;
    wire                             addr_pipe_out_valid_w;
    wire [MAX_LANES*FB_ADDR_W-1:0]   addr_pipe_out_addr_w;
    wire [MAX_LANES-1:0]             addr_pipe_out_keep_w;
    wire                             addr_pipe_out_sof_w;
    wire                             addr_pipe_out_eol_w;
    wire                             addr_pipe_out_eof_w;
    wire [15:0]                      addr_pipe_out_next_out_x_w;
    wire [15:0]                      addr_pipe_out_next_out_y_w;

    wire                             cmd_fire_w;
    wire                             rsp_fire_w;
    wire                             issue_to_pipe_fire_w;
    wire                             issue_slot_open_w;

    integer lane_idx;
    reg  [INT_ADDR_W:0]               capture_base_v;
    reg  [INT_ADDR_W:0]               addr_cursor_v;
    reg  [INT_ADDR_W:0]               capture_next_cursor_v;
    reg  [BEAT_COUNT_W-1:0]           capture_lane_count_v;
    reg  [15:0]                       output_width_v;
    reg  [15:0]                       output_height_v;
    reg  [15:0]                       remaining_width_v;
    reg  [BEAT_COUNT_W-1:0]           beat_lane_count_v;
    reg  [MAX_LANES-1:0]              plan_keep_v;
    reg                               plan_valid_v;
    reg                               plan_sof_v;
    reg                               plan_eol_v;
    reg                               plan_eof_v;
    reg  [15:0]                       next_out_x_v;
    reg  [15:0]                       next_out_y_v;

    assign frame_start_commit_w = s_valid && s_ready && s_sof;
    assign output_slot_ready_w  = (~m_valid) || m_ready;
    assign s_fire_w             = s_valid && s_ready && (|s_keep);
    assign active_angle_sel     = angle_active_w;

    assign fb_wr_valid = (state_q == ST_CAPTURE) && s_valid && (|s_keep);
    assign fb_wr_addr  = wr_addr_q;
    assign fb_wr_data  = s_data;
    assign fb_wr_keep  = s_keep;
    assign fb_wr_sof   = s_sof;
    assign fb_wr_eol   = s_eol;
    assign fb_wr_eof   = s_eof;

    assign s_ready         = (state_q == ST_CAPTURE) && fb_wr_ready;
    assign fb_rd_cmd_valid = addr_pipe_out_valid_w;
    assign fb_rd_cmd_addr  = addr_pipe_out_addr_w;
    assign fb_rd_cmd_keep  = addr_pipe_out_keep_w;
    assign cmd_fire_w      = fb_rd_cmd_valid && fb_rd_cmd_ready;
    assign fb_rd_rsp_ready = cmd_pending_q && output_slot_ready_w;
    assign rsp_fire_w      = cmd_pending_q && fb_rd_rsp_valid && fb_rd_rsp_ready;
    assign issue_to_pipe_fire_w = issue_valid_q && (~cmd_pending_q) && addr_pipe_in_ready_w;
    assign issue_slot_open_w = (~issue_valid_q) || issue_to_pipe_fire_w;

    frame_latched_u2 u_angle_latch (
        .clk               (clk),
        .rst_n             (rst_n),
        .cfg_valid         (cfg_valid),
        .cfg_ready         (cfg_ready),
        .cfg_data          (cfg_angle_sel),
        .frame_start_pulse (frame_start_commit_w),
        .active_data       (angle_active_w),
        .frame_data        ()
    );

    fixed_angle_rotate_addr_pipe #(
        .MAX_LANES  (MAX_LANES),
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .FB_ADDR_W  (FB_ADDR_W)
    ) u_addr_pipe (
        .clk            (clk),
        .rst_n          (rst_n),
        .in_valid       (issue_valid_q && (~cmd_pending_q)),
        .in_ready       (addr_pipe_in_ready_w),
        .in_angle_sel   (angle_active_w),
        .in_out_x       (issue_out_x_q),
        .in_out_y       (issue_out_y_q),
        .in_keep        (issue_keep_q),
        .in_sof         (issue_sof_q),
        .in_eol         (issue_eol_q),
        .in_eof         (issue_eof_q),
        .in_next_out_x  (issue_next_out_x_q),
        .in_next_out_y  (issue_next_out_y_q),
        .out_valid      (addr_pipe_out_valid_w),
        .out_ready      (fb_rd_cmd_ready),
        .out_addr       (addr_pipe_out_addr_w),
        .out_keep       (addr_pipe_out_keep_w),
        .out_sof        (addr_pipe_out_sof_w),
        .out_eol        (addr_pipe_out_eol_w),
        .out_eof        (addr_pipe_out_eof_w),
        .out_next_out_x (addr_pipe_out_next_out_x_w),
        .out_next_out_y (addr_pipe_out_next_out_y_w)
    );

    // Prepare external write addresses and output-beat planning metadata.
    always @* begin
        capture_base_v       = s_sof ? {(INT_ADDR_W+1){1'b0}} : {1'b0, capture_count_q};
        addr_cursor_v        = capture_base_v;
        capture_next_cursor_v = capture_base_v;
        capture_lane_count_v = {BEAT_COUNT_W{1'b0}};
        wr_addr_q            = {MAX_LANES*FB_ADDR_W{1'b0}};
        capture_count_next_q = capture_count_q;

        output_width_v     = output_width_for_angle(angle_active_w);
        output_height_v    = output_height_for_angle(angle_active_w);
        remaining_width_v  = 16'd0;
        beat_lane_count_v  = {BEAT_COUNT_W{1'b0}};
        plan_keep_v        = {MAX_LANES{1'b0}};
        plan_valid_v       = 1'b0;
        plan_sof_v         = 1'b0;
        plan_eol_v         = 1'b0;
        plan_eof_v         = 1'b0;
        next_out_x_v       = out_x_q;
        next_out_y_v       = out_y_q;

        if (out_x_q < output_width_v) begin
            remaining_width_v = output_width_v - out_x_q;
            if (remaining_width_v >= MAX_LANES_U16) begin
                beat_lane_count_v = MAX_LANES_COUNT_W;
            end else begin
                beat_lane_count_v = remaining_width_v[BEAT_COUNT_W-1:0];
            end
        end

        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (s_keep[lane_idx]) begin
                wr_addr_q[lane_idx*FB_ADDR_W +: FB_ADDR_W] =
                    {{(FB_ADDR_W-INT_ADDR_W){1'b0}}, addr_cursor_v[INT_ADDR_W-1:0]};
                addr_cursor_v = addr_cursor_v + {{INT_ADDR_W{1'b0}}, 1'b1};
                capture_lane_count_v = capture_lane_count_v + {{(BEAT_COUNT_W-1){1'b0}}, 1'b1};
            end
        end
        capture_next_cursor_v = capture_base_v + {{(INT_ADDR_W+1-BEAT_COUNT_W){1'b0}}, capture_lane_count_v};
        capture_count_next_q = capture_next_cursor_v[INT_ADDR_W-1:0];

        if ((state_q == ST_OUTPUT) && (out_y_q < output_height_v) && (beat_lane_count_v != {BEAT_COUNT_W{1'b0}})) begin
            plan_valid_v = 1'b1;
            for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                if (lane_idx < beat_lane_count_v) begin
                    plan_keep_v[lane_idx] = 1'b1;
                end
            end
            plan_sof_v = (out_x_q == 16'd0) && (out_y_q == 16'd0);
            plan_eol_v = (remaining_width_v <= MAX_LANES_U16);
            plan_eof_v = (out_y_q == (output_height_v - 16'd1)) && plan_eol_v;
            if (plan_eol_v) begin
                next_out_x_v = 16'd0;
                next_out_y_v = out_y_q + 1;
            end else begin
                next_out_x_v = out_x_q + {{(16-BEAT_COUNT_W){1'b0}}, beat_lane_count_v};
                next_out_y_v = out_y_q;
            end
        end
    end

    // Manage frame capture, command tracking, and output beat emission.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q              <= ST_CAPTURE;
            capture_count_q      <= {INT_ADDR_W{1'b0}};
            out_x_q              <= 16'd0;
            out_y_q              <= 16'd0;
            issue_out_x_q        <= 16'd0;
            issue_out_y_q        <= 16'd0;
            issue_keep_q         <= {MAX_LANES{1'b0}};
            issue_valid_q        <= 1'b0;
            issue_sof_q          <= 1'b0;
            issue_eol_q          <= 1'b0;
            issue_eof_q          <= 1'b0;
            issue_next_out_x_q   <= 16'd0;
            issue_next_out_y_q   <= 16'd0;
            cmd_pending_q        <= 1'b0;
            pending_keep_q       <= {MAX_LANES{1'b0}};
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

            if ((state_q == ST_OUTPUT) && issue_slot_open_w && (~cmd_pending_q) && plan_valid_v) begin
                issue_out_x_q      <= out_x_q;
                issue_out_y_q      <= out_y_q;
                issue_keep_q       <= plan_keep_v;
                issue_valid_q      <= 1'b1;
                issue_sof_q        <= plan_sof_v;
                issue_eol_q        <= plan_eol_v;
                issue_eof_q        <= plan_eof_v;
                issue_next_out_x_q <= next_out_x_v;
                issue_next_out_y_q <= next_out_y_v;
                out_x_q            <= next_out_x_v;
                out_y_q            <= next_out_y_v;
            end else if (issue_to_pipe_fire_w) begin
                issue_valid_q <= 1'b0;
            end

            if (cmd_fire_w) begin
                cmd_pending_q        <= 1'b1;
                pending_keep_q       <= addr_pipe_out_keep_w;
                pending_sof_q        <= addr_pipe_out_sof_w;
                pending_eol_q        <= addr_pipe_out_eol_w;
                pending_eof_q        <= addr_pipe_out_eof_w;
                pending_next_out_x_q <= addr_pipe_out_next_out_x_w;
                pending_next_out_y_q <= addr_pipe_out_next_out_y_w;
            end

            if (output_slot_ready_w) begin
                if (rsp_fire_w) begin
                    m_valid <= 1'b1;
                    m_keep  <= pending_keep_q;
                    m_sof   <= pending_sof_q;
                    m_eol   <= pending_eol_q;
                    m_eof   <= pending_eof_q;
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (pending_keep_q[lane_idx]) begin
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
                        issue_valid_q   <= 1'b0;
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
