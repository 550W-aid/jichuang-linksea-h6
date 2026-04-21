`timescale 1ns / 1ps

module fixed_angle_rotate_addr_pipe #(
    parameter integer MAX_LANES  = 8,
    parameter integer IMG_WIDTH  = 640,
    parameter integer IMG_HEIGHT = 480,
    parameter integer FB_ADDR_W  = 32
) (
    // Core processing clock.
    input  wire                           clk,
    // Active-low asynchronous reset for all pipeline stages.
    input  wire                           rst_n,
    // Input beat valid flag for one output request.
    input  wire                           in_valid,
    // Helper accepts a new beat only when the pipeline is empty.
    output wire                           in_ready,
    // Latched fixed-angle selector for the current frame.
    input  wire [1:0]                     in_angle_sel,
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
    // Read-command valid flag after coordinate and address pipelining.
    output reg                            out_valid,
    // Read-command ready flag from the downstream shell.
    input  wire                           out_ready,
    // External frame-buffer addresses for each requested lane.
    output reg  [MAX_LANES*FB_ADDR_W-1:0] out_addr,
    // Per-lane read-enable mask for the external frame buffer.
    output reg  [MAX_LANES-1:0]           out_keep,
    // Start-of-frame marker forwarded with the read command.
    output reg                            out_sof,
    // End-of-line marker forwarded with the read command.
    output reg                            out_eol,
    // End-of-frame marker forwarded with the read command.
    output reg                            out_eof,
    // Next X coordinate returned with the read command metadata.
    output reg  [15:0]                    out_next_out_x,
    // Next Y coordinate returned with the read command metadata.
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
    localparam [15:0]  IMG_WIDTH_U16 = IMG_WIDTH;
    localparam [15:0]  IMG_HEIGHT_U16 = IMG_HEIGHT;

    reg                            stage0_valid_q;
    reg  [MAX_LANES*16-1:0]        stage0_src_x_q;
    reg  [MAX_LANES*16-1:0]        stage0_src_y_q;
    reg  [MAX_LANES-1:0]           stage0_keep_q;
    reg                            stage0_sof_q;
    reg                            stage0_eol_q;
    reg                            stage0_eof_q;
    reg  [15:0]                    stage0_next_out_x_q;
    reg  [15:0]                    stage0_next_out_y_q;

    reg                            stage1_valid_q;
    reg  [MAX_LANES*INT_ADDR_W-1:0] stage1_row_base_q;
    reg  [MAX_LANES*16-1:0]        stage1_src_x_q;
    reg  [MAX_LANES-1:0]           stage1_keep_q;
    reg                            stage1_sof_q;
    reg                            stage1_eol_q;
    reg                            stage1_eof_q;
    reg  [15:0]                    stage1_next_out_x_q;
    reg  [15:0]                    stage1_next_out_y_q;

    wire stage2_ready_w;
    wire stage1_ready_w;
    wire stage0_advance_w;

    integer lane_idx;
    reg  [15:0] lane_x_v;
    reg  [15:0] src_x_v;
    reg  [15:0] src_y_v;
    reg  [INT_ADDR_W:0] row_base_v;
    reg  [INT_ADDR_W:0] addr_v;

    assign stage2_ready_w  = (~out_valid) || out_ready;
    assign stage1_ready_w  = (~stage1_valid_q) || stage2_ready_w;
    assign stage0_advance_w = (~stage0_valid_q) || stage1_ready_w;
    assign in_ready        = (~stage0_valid_q) && (~stage1_valid_q) && (~out_valid);

    // Stage 0 maps output coordinates into source X/Y coordinates.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage0_valid_q      <= 1'b0;
            stage0_src_x_q      <= {MAX_LANES*16{1'b0}};
            stage0_src_y_q      <= {MAX_LANES*16{1'b0}};
            stage0_keep_q       <= {MAX_LANES{1'b0}};
            stage0_sof_q        <= 1'b0;
            stage0_eol_q        <= 1'b0;
            stage0_eof_q        <= 1'b0;
            stage0_next_out_x_q <= 16'd0;
            stage0_next_out_y_q <= 16'd0;
        end else if (stage0_advance_w) begin
            stage0_valid_q <= in_valid && in_ready;
            if (in_valid && in_ready) begin
                stage0_keep_q       <= in_keep;
                stage0_sof_q        <= in_sof;
                stage0_eol_q        <= in_eol;
                stage0_eof_q        <= in_eof;
                stage0_next_out_x_q <= in_next_out_x;
                stage0_next_out_y_q <= in_next_out_y;
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    lane_x_v = in_out_x + lane_idx;
                    case (in_angle_sel)
                        2'd1: begin
                            src_x_v = in_out_y;
                            src_y_v = (IMG_HEIGHT_U16 - 16'd1) - lane_x_v;
                        end
                        2'd2: begin
                            src_x_v = (IMG_WIDTH_U16 - 16'd1) - lane_x_v;
                            src_y_v = (IMG_HEIGHT_U16 - 16'd1) - in_out_y;
                        end
                        2'd3: begin
                            src_x_v = (IMG_WIDTH_U16 - 16'd1) - in_out_y;
                            src_y_v = lane_x_v;
                        end
                        default: begin
                            src_x_v = lane_x_v;
                            src_y_v = in_out_y;
                        end
                    endcase
                    stage0_src_x_q[lane_idx*16 +: 16] <= src_x_v[15:0];
                    stage0_src_y_q[lane_idx*16 +: 16] <= src_y_v[15:0];
                end
            end else begin
                stage0_src_x_q      <= {MAX_LANES*16{1'b0}};
                stage0_src_y_q      <= {MAX_LANES*16{1'b0}};
                stage0_keep_q       <= {MAX_LANES{1'b0}};
                stage0_sof_q        <= 1'b0;
                stage0_eol_q        <= 1'b0;
                stage0_eof_q        <= 1'b0;
                stage0_next_out_x_q <= 16'd0;
                stage0_next_out_y_q <= 16'd0;
            end
        end
    end

    // Stage 1 converts each source row index into a row-base address.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_valid_q      <= 1'b0;
            stage1_row_base_q   <= {MAX_LANES*INT_ADDR_W{1'b0}};
            stage1_src_x_q      <= {MAX_LANES*16{1'b0}};
            stage1_keep_q       <= {MAX_LANES{1'b0}};
            stage1_sof_q        <= 1'b0;
            stage1_eol_q        <= 1'b0;
            stage1_eof_q        <= 1'b0;
            stage1_next_out_x_q <= 16'd0;
            stage1_next_out_y_q <= 16'd0;
        end else if (stage1_ready_w) begin
            stage1_valid_q <= stage0_valid_q;
            if (stage0_valid_q) begin
                stage1_src_x_q      <= stage0_src_x_q;
                stage1_keep_q       <= stage0_keep_q;
                stage1_sof_q        <= stage0_sof_q;
                stage1_eol_q        <= stage0_eol_q;
                stage1_eof_q        <= stage0_eof_q;
                stage1_next_out_x_q <= stage0_next_out_x_q;
                stage1_next_out_y_q <= stage0_next_out_y_q;
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    row_base_v = stage0_src_y_q[lane_idx*16 +: 16] * IMG_WIDTH;
                    stage1_row_base_q[lane_idx*INT_ADDR_W +: INT_ADDR_W] <= row_base_v[INT_ADDR_W-1:0];
                end
            end else begin
                stage1_row_base_q   <= {MAX_LANES*INT_ADDR_W{1'b0}};
                stage1_src_x_q      <= {MAX_LANES*16{1'b0}};
                stage1_keep_q       <= {MAX_LANES{1'b0}};
                stage1_sof_q        <= 1'b0;
                stage1_eol_q        <= 1'b0;
                stage1_eof_q        <= 1'b0;
                stage1_next_out_x_q <= 16'd0;
                stage1_next_out_y_q <= 16'd0;
            end
        end
    end

    // Stage 2 adds the row-base and column offset to form final read addresses.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid      <= 1'b0;
            out_addr       <= {MAX_LANES*FB_ADDR_W{1'b0}};
            out_keep       <= {MAX_LANES{1'b0}};
            out_sof        <= 1'b0;
            out_eol        <= 1'b0;
            out_eof        <= 1'b0;
            out_next_out_x <= 16'd0;
            out_next_out_y <= 16'd0;
        end else if (stage2_ready_w) begin
            out_valid <= stage1_valid_q;
            if (stage1_valid_q) begin
                out_keep       <= stage1_keep_q;
                out_sof        <= stage1_sof_q;
                out_eol        <= stage1_eol_q;
                out_eof        <= stage1_eof_q;
                out_next_out_x <= stage1_next_out_x_q;
                out_next_out_y <= stage1_next_out_y_q;
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    addr_v = stage1_row_base_q[lane_idx*INT_ADDR_W +: INT_ADDR_W] +
                             stage1_src_x_q[lane_idx*16 +: 16];
                    out_addr[lane_idx*FB_ADDR_W +: FB_ADDR_W] <=
                        {{(FB_ADDR_W-INT_ADDR_W){1'b0}}, addr_v[INT_ADDR_W-1:0]};
                end
            end else begin
                out_addr       <= {MAX_LANES*FB_ADDR_W{1'b0}};
                out_keep       <= {MAX_LANES{1'b0}};
                out_sof        <= 1'b0;
                out_eol        <= 1'b0;
                out_eof        <= 1'b0;
                out_next_out_x <= 16'd0;
                out_next_out_y <= 16'd0;
            end
        end
    end

endmodule
