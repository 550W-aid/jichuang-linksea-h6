`timescale 1ns / 1ps

module rotate_nearest_multilane_request_planner #(
    parameter integer MAX_LANES = 8,
    parameter integer IMAGE_W   = 640,
    parameter integer IMAGE_H   = 480
) (
    input  wire                               clk,             // Core clock for one-beat request planning.
    input  wire                               rst_n,           // Active-low reset for the request planner stage.
    input  wire                               load_valid,      // Pulse that captures a new output beat into the planner pipeline.
    input  wire [$clog2(IMAGE_W*IMAGE_H+1)-1:0] drain_index_in,  // Linear output-frame index of the first lane in the beat.
    input  wire [$clog2(IMAGE_W*IMAGE_H+1)-1:0] frame_pixels_in, // Total valid pixels in the captured frame.
    input  wire signed [15:0]                 cos_q8,          // Frame-level cosine in signed Q8 format.
    input  wire signed [15:0]                 sin_q8,          // Frame-level sine in signed Q8 format.
    input  wire                               plan_accept,     // Pulse that consumes the currently planned beat.
    output reg                                plan_valid,      // High when the planned beat metadata is available.
    output reg                                plan_has_mem,    // High when at least one lane in the beat needs memory data.
    output reg  [$clog2(IMAGE_W*IMAGE_H+1)-1:0] plan_beat_count, // Number of valid lanes in the planned beat.
    output reg  [MAX_LANES-1:0]               plan_keep,       // Valid-lane mask for the planned beat.
    output reg  [MAX_LANES-1:0]               plan_zero,       // Zero-fill mask for lanes that map outside the frame.
    output reg  [MAX_LANES*$clog2(IMAGE_W*IMAGE_H)-1:0] plan_addr, // Packed source-frame addresses for memory-backed lanes.
    output reg                                plan_sof,        // Start-of-frame marker for the planned beat.
    output reg                                plan_eol,        // End-of-line marker for the planned beat.
    output reg                                plan_eof         // End-of-frame marker for the planned beat.
);

    localparam integer PIXELS  = IMAGE_W * IMAGE_H;
    localparam integer COUNT_W = (PIXELS <= 1) ? 1 : $clog2(PIXELS + 1);
    localparam integer ADDR_W  = (PIXELS <= 1) ? 1 : $clog2(PIXELS);
    localparam integer X_W     = (IMAGE_W <= 1) ? 1 : $clog2(IMAGE_W);
    localparam integer Y_W     = (IMAGE_H <= 1) ? 1 : $clog2(IMAGE_H);

    integer lane_idx_comb;

    reg [COUNT_W-1:0] staged_drain_index_r;
    reg [COUNT_W-1:0] staged_frame_pixels_r;
    reg               staged_pending_r;

    wire [MAX_LANES-1:0]        lane_src_inside;
    wire [MAX_LANES*X_W-1:0]    lane_src_x_unused;
    wire [MAX_LANES*Y_W-1:0]    lane_src_y_unused;
    wire [MAX_LANES*ADDR_W-1:0] lane_src_linear_idx;

    // Return the number of valid pixels that belong to the beat that starts at the given output-frame index.
    function integer beat_valid_pixels;
        input integer linear_index;
        input integer total_pixels;
        integer row_pos;
        integer remaining_row;
        integer remaining_frame;
        begin
            row_pos = linear_index % IMAGE_W;
            remaining_row = IMAGE_W - row_pos;
            remaining_frame = total_pixels - linear_index;
            beat_valid_pixels = MAX_LANES;
            if (beat_valid_pixels > remaining_row) begin
                beat_valid_pixels = remaining_row;
            end
            if (beat_valid_pixels > remaining_frame) begin
                beat_valid_pixels = remaining_frame;
            end
        end
    endfunction

    genvar lane_gen;
    generate
        for (lane_gen = 0; lane_gen < MAX_LANES; lane_gen = lane_gen + 1) begin : gen_lane_mapper
            wire [ADDR_W-1:0] lane_out_linear_idx;   // Current output-frame pixel index for this lane within the staged beat.
            wire              lane_inside_local;     // Helper-local inside flag for this lane.
            wire [X_W-1:0]    lane_src_x_local;      // Helper-local mapped source x for this lane.
            wire [Y_W-1:0]    lane_src_y_local;      // Helper-local mapped source y for this lane.
            wire [ADDR_W-1:0] lane_src_linear_local; // Helper-local mapped source linear index for this lane.

            assign lane_out_linear_idx = staged_drain_index_r[ADDR_W-1:0] + lane_gen;
            assign lane_src_inside[lane_gen] = lane_inside_local;
            assign lane_src_x_unused[lane_gen*X_W +: X_W] = lane_src_x_local;
            assign lane_src_y_unused[lane_gen*Y_W +: Y_W] = lane_src_y_local;
            assign lane_src_linear_idx[lane_gen*ADDR_W +: ADDR_W] = lane_src_linear_local;

            rotate_nearest_linear_index_mapper #(
                .IMAGE_W(IMAGE_W),
                .IMAGE_H(IMAGE_H)
            ) u_linear_index_mapper (
                .out_linear_idx(lane_out_linear_idx),
                .cos_q8        (cos_q8),
                .sin_q8        (sin_q8),
                .src_inside    (lane_inside_local),
                .src_x         (lane_src_x_local),
                .src_y         (lane_src_y_local),
                .src_linear_idx(lane_src_linear_local)
            );
        end
    endgenerate

    // Capture the next beat index into the staging register and expose it one cycle later as a valid plan.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            staged_drain_index_r  <= {COUNT_W{1'b0}};
            staged_frame_pixels_r <= {COUNT_W{1'b0}};
            staged_pending_r      <= 1'b0;
            plan_valid            <= 1'b0;
        end else begin
            if (plan_accept) begin
                plan_valid <= 1'b0;
            end

            if (staged_pending_r) begin
                staged_pending_r <= 1'b0;
                plan_valid       <= 1'b1;
            end

            if (load_valid && !staged_pending_r && !plan_valid) begin
                staged_drain_index_r  <= drain_index_in;
                staged_frame_pixels_r <= frame_pixels_in;
                staged_pending_r      <= 1'b1;
            end
        end
    end

    // Derive one full beat of readback metadata from the staged output-frame index and angle.
    always @* begin
        plan_has_mem    = 1'b0;
        plan_beat_count = beat_valid_pixels(staged_drain_index_r, staged_frame_pixels_r);
        plan_keep       = {MAX_LANES{1'b0}};
        plan_zero       = {MAX_LANES{1'b0}};
        plan_addr       = {MAX_LANES*ADDR_W{1'b0}};
        plan_sof        = (staged_drain_index_r == {COUNT_W{1'b0}});
        plan_eol        = ((staged_drain_index_r % IMAGE_W) + plan_beat_count) == IMAGE_W;
        plan_eof        = (staged_drain_index_r + plan_beat_count) == staged_frame_pixels_r;

        for (lane_idx_comb = 0; lane_idx_comb < MAX_LANES; lane_idx_comb = lane_idx_comb + 1) begin
            if (lane_idx_comb < plan_beat_count) begin
                plan_keep[lane_idx_comb] = 1'b1;
                if (!lane_src_inside[lane_idx_comb]) begin
                    plan_zero[lane_idx_comb] = 1'b1;
                end else begin
                    plan_has_mem = 1'b1;
                    plan_addr[lane_idx_comb*ADDR_W +: ADDR_W]
                        = lane_src_linear_idx[lane_idx_comb*ADDR_W +: ADDR_W];
                end
            end
        end
    end

endmodule
