`timescale 1ns / 1ps

module rotate_nearest_multilane_readback_path #(
    parameter integer MAX_LANES = 8,
    parameter integer PIXEL_W   = 8,
    parameter integer IMAGE_W   = 640,
    parameter integer IMAGE_H   = 480
) (
    input  wire                         clk,              // Core clock for rotated-frame readback scheduling.
    input  wire                         rst_n,            // Active-low reset for the readback datapath.
    input  wire                         start_valid,      // Start pulse for a captured frame ready to replay.
    input  wire [$clog2(IMAGE_W*IMAGE_H+1)-1:0] frame_pixels,    // Number of valid pixels captured for the current frame.
    input  wire signed [8:0]            frame_angle_deg,  // Frame-latched rotation angle for the replay pass.
    output wire                         rd_req_valid,     // External-memory read request valid for one output beat.
    input  wire                         rd_req_ready,     // External-memory request acceptance for the current beat.
    output wire [MAX_LANES-1:0]         rd_req_keep,      // Per-lane read mask for in-range lanes only.
    output wire [MAX_LANES-1:0]         rd_req_zero,      // Lanes that should emit zero-fill instead of reading memory.
    output wire [MAX_LANES*$clog2(IMAGE_W*IMAGE_H)-1:0] rd_req_addr, // Packed source-frame addresses for memory-backed lanes.
    input  wire                         rd_rsp_valid,     // External-memory read response valid.
    output wire                         rd_rsp_ready,     // Readback path ready to accept the packed memory response.
    input  wire [MAX_LANES*PIXEL_W-1:0] rd_rsp_data,      // Packed pixels returned from the external memory seam.
    output wire                         m_valid,          // Rotated output beat valid.
    input  wire                         m_ready,          // Downstream ready for the rotated output beat.
    output wire [MAX_LANES*PIXEL_W-1:0] m_data,           // Packed rotated output pixels.
    output wire [MAX_LANES-1:0]         m_keep,           // Contiguous valid-lane mask for the rotated output beat.
    output wire                         m_sof,            // Start-of-frame marker for the rotated output stream.
    output wire                         m_eol,            // End-of-line marker for the rotated output stream.
    output wire                         m_eof             // End-of-frame marker for the rotated output stream.
);

    localparam integer PIXELS  = IMAGE_W * IMAGE_H;
    localparam integer COUNT_W = (PIXELS <= 1) ? 1 : $clog2(PIXELS + 1);
    localparam integer ADDR_W  = (PIXELS <= 1) ? 1 : $clog2(PIXELS);

    integer lane_idx_seq;

    reg [COUNT_W-1:0]           frame_pixels_r;
    reg signed [8:0]            frame_angle_deg_r;
    reg                         pending_start_valid;
    reg [COUNT_W-1:0]           pending_frame_pixels;
    reg signed [8:0]            pending_frame_angle_deg;
    reg                         drain_active;
    reg [COUNT_W-1:0]           drain_index;
    reg                         waiting_rsp;
    reg [COUNT_W-1:0]           hold_beat_count;
    reg [MAX_LANES-1:0]         pending_keep_r;
    reg [MAX_LANES-1:0]         pending_zero_r;
    reg                         hold_valid_r;
    reg [MAX_LANES*PIXEL_W-1:0] hold_data_r;
    reg [MAX_LANES-1:0]         hold_keep_r;
    reg                         hold_sof_r;
    reg                         hold_eol_r;
    reg                         hold_eof_r;

    wire                        planner_load;
    wire                        planner_accept;
    wire                        plan_issue_fire;
    wire                        plan_valid;
    wire                        plan_has_mem;
    wire [COUNT_W-1:0]          plan_beat_count;
    wire [MAX_LANES-1:0]        plan_keep;
    wire [MAX_LANES-1:0]        plan_zero;
    wire [MAX_LANES*ADDR_W-1:0] plan_addr;
    wire                        plan_sof;
    wire                        plan_eol;
    wire                        plan_eof;

    wire signed [15:0]          cos_q8;
    wire signed [15:0]          sin_q8;

    assign planner_load = drain_active && !waiting_rsp && !hold_valid_r && (frame_pixels_r != {COUNT_W{1'b0}});
    assign rd_req_valid = plan_valid && plan_has_mem && !waiting_rsp && !hold_valid_r;
    assign rd_req_keep  = plan_keep & ~plan_zero;
    assign rd_req_zero  = plan_zero;
    assign rd_req_addr  = plan_addr;
    assign rd_rsp_ready = waiting_rsp && !hold_valid_r;
    assign plan_issue_fire = plan_valid && !waiting_rsp && !hold_valid_r &&
                             ((plan_has_mem && rd_req_ready) || !plan_has_mem);
    assign planner_accept = plan_issue_fire;
    assign m_valid      = hold_valid_r;
    assign m_data       = hold_data_r;
    assign m_keep       = hold_keep_r;
    assign m_sof        = hold_sof_r;
    assign m_eol        = hold_eol_r;
    assign m_eof        = hold_eof_r;

    rotate_trig_lut u_frame_trig (
        .angle_deg(frame_angle_deg_r),
        .cos_q8   (cos_q8),
        .sin_q8   (sin_q8)
    );

    rotate_nearest_multilane_request_planner #(
        .MAX_LANES(MAX_LANES),
        .IMAGE_W  (IMAGE_W),
        .IMAGE_H  (IMAGE_H)
    ) u_request_planner (
        .clk            (clk),
        .rst_n          (rst_n),
        .load_valid     (planner_load),
        .drain_index_in (drain_index),
        .frame_pixels_in(frame_pixels_r),
        .cos_q8         (cos_q8),
        .sin_q8         (sin_q8),
        .plan_accept    (planner_accept),
        .plan_valid     (plan_valid),
        .plan_has_mem   (plan_has_mem),
        .plan_beat_count(plan_beat_count),
        .plan_keep      (plan_keep),
        .plan_zero      (plan_zero),
        .plan_addr      (plan_addr),
        .plan_sof       (plan_sof),
        .plan_eol       (plan_eol),
        .plan_eof       (plan_eof)
    );

    // Sequence frame start capture, external-memory request issue, response accept, and output beat emission.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_pixels_r  <= {COUNT_W{1'b0}};
            frame_angle_deg_r <= 9'sd0;
            pending_start_valid <= 1'b0;
            pending_frame_pixels <= {COUNT_W{1'b0}};
            pending_frame_angle_deg <= 9'sd0;
            drain_active    <= 1'b0;
            drain_index     <= {COUNT_W{1'b0}};
            waiting_rsp     <= 1'b0;
            hold_beat_count <= {COUNT_W{1'b0}};
            pending_keep_r  <= {MAX_LANES{1'b0}};
            pending_zero_r  <= {MAX_LANES{1'b0}};
            hold_valid_r    <= 1'b0;
            hold_data_r     <= {MAX_LANES*PIXEL_W{1'b0}};
            hold_keep_r     <= {MAX_LANES{1'b0}};
            hold_sof_r      <= 1'b0;
            hold_eol_r      <= 1'b0;
            hold_eof_r      <= 1'b0;
        end else begin
            if (start_valid) begin
                pending_start_valid     <= 1'b1;
                pending_frame_pixels    <= frame_pixels;
                pending_frame_angle_deg <= frame_angle_deg;
            end

            if (!drain_active && !waiting_rsp && !hold_valid_r && pending_start_valid) begin
                frame_pixels_r          <= pending_frame_pixels;
                frame_angle_deg_r       <= pending_frame_angle_deg;
                pending_start_valid     <= 1'b0;
                drain_active            <= 1'b1;
                drain_index             <= {COUNT_W{1'b0}};
            end

            if (plan_issue_fire) begin
                hold_beat_count <= plan_beat_count;
                hold_keep_r     <= plan_keep;
                hold_sof_r      <= plan_sof;
                hold_eol_r      <= plan_eol;
                hold_eof_r      <= plan_eof;
                if (plan_has_mem) begin
                    pending_keep_r <= plan_keep;
                    pending_zero_r <= plan_zero;
                    waiting_rsp    <= 1'b1;
                end else begin
                    hold_valid_r   <= 1'b1;
                    hold_data_r    <= {MAX_LANES*PIXEL_W{1'b0}};
                end
            end

            if (rd_rsp_ready && rd_rsp_valid) begin
                waiting_rsp <= 1'b0;
                hold_valid_r <= 1'b1;
                hold_data_r <= {MAX_LANES*PIXEL_W{1'b0}};
                for (lane_idx_seq = 0; lane_idx_seq < MAX_LANES; lane_idx_seq = lane_idx_seq + 1) begin
                    if (pending_keep_r[lane_idx_seq] && !pending_zero_r[lane_idx_seq]) begin
                        hold_data_r[lane_idx_seq*PIXEL_W +: PIXEL_W] <= rd_rsp_data[lane_idx_seq*PIXEL_W +: PIXEL_W];
                    end
                end
            end

            if (hold_valid_r && m_ready) begin
                hold_valid_r <= 1'b0;
                if (hold_eof_r) begin
                    drain_active    <= 1'b0;
                    drain_index     <= {COUNT_W{1'b0}};
                    frame_pixels_r  <= {COUNT_W{1'b0}};
                end else begin
                    drain_index <= drain_index + hold_beat_count;
                end
            end
        end
    end

endmodule
