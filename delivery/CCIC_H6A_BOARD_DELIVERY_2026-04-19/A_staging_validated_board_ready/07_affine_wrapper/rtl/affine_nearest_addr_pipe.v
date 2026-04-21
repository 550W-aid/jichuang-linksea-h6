`timescale 1ns / 1ps

module affine_nearest_addr_pipe #(
    parameter integer MAX_LANES  = 1,
    parameter integer IMG_WIDTH  = 1024,
    parameter integer IMG_HEIGHT = 768,
    parameter integer FB_ADDR_W  = 32
) (
    // Core processing clock.
    input  wire                           clk,
    // Active-low asynchronous reset for all pipeline stages.
    input  wire                           rst_n,
    // Input beat valid flag for one affine output request.
    input  wire                           in_valid,
    // Helper accepts a new beat only when the pipeline is empty.
    output wire                           in_ready,
    // Affine matrix coefficient m00 for the current frame.
    input  wire signed [15:0]             in_m00,
    // Affine matrix coefficient m01 for the current frame.
    input  wire signed [15:0]             in_m01,
    // Affine matrix coefficient m02 for the current frame.
    input  wire signed [15:0]             in_m02,
    // Affine matrix coefficient m10 for the current frame.
    input  wire signed [15:0]             in_m10,
    // Affine matrix coefficient m11 for the current frame.
    input  wire signed [15:0]             in_m11,
    // Affine matrix coefficient m12 for the current frame.
    input  wire signed [15:0]             in_m12,
    // Output-space X coordinate of lane0 for the requested beat.
    input  wire [15:0]                    in_out_x,
    // Output-space Y coordinate of the requested beat.
    input  wire [15:0]                    in_out_y,
    // Per-lane beat validity mask in output space.
    input  wire [MAX_LANES-1:0]           in_keep,
    // Start-of-frame marker aligned with the requested beat.
    input  wire                           in_sof,
    // End-of-line marker aligned with the requested beat.
    input  wire                           in_eol,
    // End-of-frame marker aligned with the requested beat.
    input  wire                           in_eof,
    // Next X coordinate after the requested beat completes.
    input  wire [15:0]                    in_next_out_x,
    // Next Y coordinate after the requested beat completes.
    input  wire [15:0]                    in_next_out_y,
    // Output metadata valid flag after affine and address pipelining.
    output reg                            out_valid,
    // Ready flag from the downstream shell.
    input  wire                           out_ready,
    // External frame-buffer addresses for each sampled lane.
    output reg  [MAX_LANES*FB_ADDR_W-1:0] out_addr,
    // Per-lane output validity mask in output space.
    output reg  [MAX_LANES-1:0]           out_keep,
    // Per-lane read-enable mask for in-range source samples.
    output reg  [MAX_LANES-1:0]           out_rd_keep,
    // Start-of-frame marker forwarded with the output metadata.
    output reg                            out_sof,
    // End-of-line marker forwarded with the output metadata.
    output reg                            out_eol,
    // End-of-frame marker forwarded with the output metadata.
    output reg                            out_eof,
    // Next X coordinate returned with the output metadata.
    output reg  [15:0]                    out_next_out_x,
    // Next Y coordinate returned with the output metadata.
    output reg  [15:0]                    out_next_out_y
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

    localparam integer PIXELS     = IMG_WIDTH * IMG_HEIGHT;
    localparam integer INT_ADDR_W = (PIXELS <= 1) ? 1 : clog2(PIXELS);

    reg                             stage0_valid_q;
    reg  signed [MAX_LANES*48-1:0]  stage0_mul_m00x_q;
    reg  signed [MAX_LANES*48-1:0]  stage0_mul_m01y_q;
    reg  signed [MAX_LANES*48-1:0]  stage0_mul_m10x_q;
    reg  signed [MAX_LANES*48-1:0]  stage0_mul_m11y_q;
    reg  [MAX_LANES-1:0]            stage0_keep_q;
    reg                             stage0_sof_q;
    reg                             stage0_eol_q;
    reg                             stage0_eof_q;
    reg  [15:0]                     stage0_next_out_x_q;
    reg  [15:0]                     stage0_next_out_y_q;
    reg  signed [15:0]              stage0_m02_q;
    reg  signed [15:0]              stage0_m12_q;

    reg                             stage1_valid_q;
    reg  signed [MAX_LANES*32-1:0]  stage1_src_x_int_q;
    reg  signed [MAX_LANES*32-1:0]  stage1_src_y_int_q;
    reg  [MAX_LANES-1:0]            stage1_keep_q;
    reg                             stage1_sof_q;
    reg                             stage1_eol_q;
    reg                             stage1_eof_q;
    reg  [15:0]                     stage1_next_out_x_q;
    reg  [15:0]                     stage1_next_out_y_q;

    reg                             stage2_valid_q;
    reg  [MAX_LANES*INT_ADDR_W-1:0] stage2_row_base_q;
    reg  [MAX_LANES*16-1:0]         stage2_src_x_q;
    reg  [MAX_LANES-1:0]            stage2_keep_q;
    reg  [MAX_LANES-1:0]            stage2_rd_keep_q;
    reg                             stage2_sof_q;
    reg                             stage2_eol_q;
    reg                             stage2_eof_q;
    reg  [15:0]                     stage2_next_out_x_q;
    reg  [15:0]                     stage2_next_out_y_q;

    wire stage3_ready_w;
    wire stage2_ready_w;
    wire stage1_ready_w;
    wire stage0_advance_w;

    integer lane_idx;
    integer lane_x_v;
    integer out_y_v;
    integer row_base_v;
    integer addr_v;
    integer src_x_int_v;
    integer src_y_int_v;
    reg signed [47:0] src_x_fixed_v;
    reg signed [47:0] src_y_fixed_v;

    assign stage3_ready_w   = (~out_valid) || out_ready;
    assign stage2_ready_w   = (~stage2_valid_q) || stage3_ready_w;
    assign stage1_ready_w   = (~stage1_valid_q) || stage2_ready_w;
    assign stage0_advance_w = (~stage0_valid_q) || stage1_ready_w;
    assign in_ready         = (~stage0_valid_q) && (~stage1_valid_q) && (~stage2_valid_q) && (~out_valid);

    // Stage 0 captures the affine multiply terms for every active lane.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage0_valid_q    <= 1'b0;
            stage0_mul_m00x_q <= {MAX_LANES*48{1'b0}};
            stage0_mul_m01y_q <= {MAX_LANES*48{1'b0}};
            stage0_mul_m10x_q <= {MAX_LANES*48{1'b0}};
            stage0_mul_m11y_q <= {MAX_LANES*48{1'b0}};
            stage0_keep_q     <= {MAX_LANES{1'b0}};
            stage0_sof_q      <= 1'b0;
            stage0_eol_q      <= 1'b0;
            stage0_eof_q      <= 1'b0;
            stage0_next_out_x_q <= 16'd0;
            stage0_next_out_y_q <= 16'd0;
            stage0_m02_q      <= 16'sd0;
            stage0_m12_q      <= 16'sd0;
        end else if (stage0_advance_w) begin
            stage0_valid_q <= in_valid && in_ready;
            if (in_valid && in_ready) begin
                stage0_keep_q       <= in_keep;
                stage0_sof_q        <= in_sof;
                stage0_eol_q        <= in_eol;
                stage0_eof_q        <= in_eof;
                stage0_next_out_x_q <= in_next_out_x;
                stage0_next_out_y_q <= in_next_out_y;
                stage0_m02_q        <= in_m02;
                stage0_m12_q        <= in_m12;
                out_y_v = in_out_y;
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    lane_x_v = in_out_x + lane_idx;
                    stage0_mul_m00x_q[lane_idx*48 +: 48] <= $signed(in_m00) * lane_x_v;
                    stage0_mul_m01y_q[lane_idx*48 +: 48] <= $signed(in_m01) * out_y_v;
                    stage0_mul_m10x_q[lane_idx*48 +: 48] <= $signed(in_m10) * lane_x_v;
                    stage0_mul_m11y_q[lane_idx*48 +: 48] <= $signed(in_m11) * out_y_v;
                end
            end else begin
                stage0_mul_m00x_q   <= {MAX_LANES*48{1'b0}};
                stage0_mul_m01y_q   <= {MAX_LANES*48{1'b0}};
                stage0_mul_m10x_q   <= {MAX_LANES*48{1'b0}};
                stage0_mul_m11y_q   <= {MAX_LANES*48{1'b0}};
                stage0_keep_q       <= {MAX_LANES{1'b0}};
                stage0_sof_q        <= 1'b0;
                stage0_eol_q        <= 1'b0;
                stage0_eof_q        <= 1'b0;
                stage0_next_out_x_q <= 16'd0;
                stage0_next_out_y_q <= 16'd0;
                stage0_m02_q        <= 16'sd0;
                stage0_m12_q        <= 16'sd0;
            end
        end
    end

    // Stage 1 completes the affine multiply-add chain and rounds back to integer coordinates.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_valid_q      <= 1'b0;
            stage1_src_x_int_q  <= {MAX_LANES*32{1'b0}};
            stage1_src_y_int_q  <= {MAX_LANES*32{1'b0}};
            stage1_keep_q       <= {MAX_LANES{1'b0}};
            stage1_sof_q        <= 1'b0;
            stage1_eol_q        <= 1'b0;
            stage1_eof_q        <= 1'b0;
            stage1_next_out_x_q <= 16'd0;
            stage1_next_out_y_q <= 16'd0;
        end else if (stage1_ready_w) begin
            stage1_valid_q <= stage0_valid_q;
            if (stage0_valid_q) begin
                stage1_keep_q       <= stage0_keep_q;
                stage1_sof_q        <= stage0_sof_q;
                stage1_eol_q        <= stage0_eol_q;
                stage1_eof_q        <= stage0_eof_q;
                stage1_next_out_x_q <= stage0_next_out_x_q;
                stage1_next_out_y_q <= stage0_next_out_y_q;
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    src_x_fixed_v =
                        $signed(stage0_mul_m00x_q[lane_idx*48 +: 48]) +
                        $signed(stage0_mul_m01y_q[lane_idx*48 +: 48]) +
                        ($signed(stage0_m02_q) <<< 8);
                    src_y_fixed_v =
                        $signed(stage0_mul_m10x_q[lane_idx*48 +: 48]) +
                        $signed(stage0_mul_m11y_q[lane_idx*48 +: 48]) +
                        ($signed(stage0_m12_q) <<< 8);
                    stage1_src_x_int_q[lane_idx*32 +: 32] <= src_x_fixed_v >>> 8;
                    stage1_src_y_int_q[lane_idx*32 +: 32] <= src_y_fixed_v >>> 8;
                end
            end else begin
                stage1_src_x_int_q  <= {MAX_LANES*32{1'b0}};
                stage1_src_y_int_q  <= {MAX_LANES*32{1'b0}};
                stage1_keep_q       <= {MAX_LANES{1'b0}};
                stage1_sof_q        <= 1'b0;
                stage1_eol_q        <= 1'b0;
                stage1_eof_q        <= 1'b0;
                stage1_next_out_x_q <= 16'd0;
                stage1_next_out_y_q <= 16'd0;
            end
        end
    end

    // Stage 2 checks source range and pipelines the frame-buffer row-base multiply.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage2_valid_q      <= 1'b0;
            stage2_row_base_q   <= {MAX_LANES*INT_ADDR_W{1'b0}};
            stage2_src_x_q      <= {MAX_LANES*16{1'b0}};
            stage2_keep_q       <= {MAX_LANES{1'b0}};
            stage2_rd_keep_q    <= {MAX_LANES{1'b0}};
            stage2_sof_q        <= 1'b0;
            stage2_eol_q        <= 1'b0;
            stage2_eof_q        <= 1'b0;
            stage2_next_out_x_q <= 16'd0;
            stage2_next_out_y_q <= 16'd0;
        end else if (stage2_ready_w) begin
            stage2_valid_q <= stage1_valid_q;
            if (stage1_valid_q) begin
                stage2_keep_q       <= stage1_keep_q;
                stage2_sof_q        <= stage1_sof_q;
                stage2_eol_q        <= stage1_eol_q;
                stage2_eof_q        <= stage1_eof_q;
                stage2_next_out_x_q <= stage1_next_out_x_q;
                stage2_next_out_y_q <= stage1_next_out_y_q;
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    src_x_int_v = $signed(stage1_src_x_int_q[lane_idx*32 +: 32]);
                    src_y_int_v = $signed(stage1_src_y_int_q[lane_idx*32 +: 32]);
                    if (stage1_keep_q[lane_idx] &&
                        (src_x_int_v >= 0) && (src_x_int_v < IMG_WIDTH) &&
                        (src_y_int_v >= 0) && (src_y_int_v < IMG_HEIGHT)) begin
                        row_base_v = src_y_int_v * IMG_WIDTH;
                        stage2_row_base_q[lane_idx*INT_ADDR_W +: INT_ADDR_W] <= row_base_v[INT_ADDR_W-1:0];
                        stage2_src_x_q[lane_idx*16 +: 16] <= src_x_int_v[15:0];
                        stage2_rd_keep_q[lane_idx] <= 1'b1;
                    end else begin
                        stage2_row_base_q[lane_idx*INT_ADDR_W +: INT_ADDR_W] <= {INT_ADDR_W{1'b0}};
                        stage2_src_x_q[lane_idx*16 +: 16] <= 16'd0;
                        stage2_rd_keep_q[lane_idx] <= 1'b0;
                    end
                end
            end else begin
                stage2_row_base_q   <= {MAX_LANES*INT_ADDR_W{1'b0}};
                stage2_src_x_q      <= {MAX_LANES*16{1'b0}};
                stage2_keep_q       <= {MAX_LANES{1'b0}};
                stage2_rd_keep_q    <= {MAX_LANES{1'b0}};
                stage2_sof_q        <= 1'b0;
                stage2_eol_q        <= 1'b0;
                stage2_eof_q        <= 1'b0;
                stage2_next_out_x_q <= 16'd0;
                stage2_next_out_y_q <= 16'd0;
            end
        end
    end

    // Stage 3 adds row-base and column offset to form final source addresses.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid      <= 1'b0;
            out_addr       <= {MAX_LANES*FB_ADDR_W{1'b0}};
            out_keep       <= {MAX_LANES{1'b0}};
            out_rd_keep    <= {MAX_LANES{1'b0}};
            out_sof        <= 1'b0;
            out_eol        <= 1'b0;
            out_eof        <= 1'b0;
            out_next_out_x <= 16'd0;
            out_next_out_y <= 16'd0;
        end else if (stage3_ready_w) begin
            out_valid <= stage2_valid_q;
            if (stage2_valid_q) begin
                out_keep       <= stage2_keep_q;
                out_rd_keep    <= stage2_rd_keep_q;
                out_sof        <= stage2_sof_q;
                out_eol        <= stage2_eol_q;
                out_eof        <= stage2_eof_q;
                out_next_out_x <= stage2_next_out_x_q;
                out_next_out_y <= stage2_next_out_y_q;
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    if (stage2_rd_keep_q[lane_idx]) begin
                        addr_v = stage2_row_base_q[lane_idx*INT_ADDR_W +: INT_ADDR_W] +
                                 stage2_src_x_q[lane_idx*16 +: 16];
                        out_addr[lane_idx*FB_ADDR_W +: FB_ADDR_W] <=
                            {{(FB_ADDR_W-INT_ADDR_W){1'b0}}, addr_v[INT_ADDR_W-1:0]};
                    end else begin
                        out_addr[lane_idx*FB_ADDR_W +: FB_ADDR_W] <= {FB_ADDR_W{1'b0}};
                    end
                end
            end else begin
                out_addr       <= {MAX_LANES*FB_ADDR_W{1'b0}};
                out_keep       <= {MAX_LANES{1'b0}};
                out_rd_keep    <= {MAX_LANES{1'b0}};
                out_sof        <= 1'b0;
                out_eol        <= 1'b0;
                out_eof        <= 1'b0;
                out_next_out_x <= 16'd0;
                out_next_out_y <= 16'd0;
            end
        end
    end

endmodule
