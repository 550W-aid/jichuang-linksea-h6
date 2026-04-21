`timescale 1ns / 1ps

module window3x3_stream_std #(
    parameter integer MAX_LANES  = 1,
    parameter integer DATA_W     = 8,
    parameter integer IMG_WIDTH  = 1440,
    parameter integer IMG_HEIGHT = 1920
) (
    // Core processing clock.
    input  wire                          clk,
    // Active-low asynchronous reset for the stream pipeline state.
    input  wire                          rst_n,
    // Input beat valid flag.
    input  wire                          s_valid,
    // Upstream backpressure flag.
    output wire                          s_ready,
    // Input pixel data. Only lane0 is consumed in this delivery module.
    input  wire [MAX_LANES*DATA_W-1:0]   s_data,
    // Input lane-valid mask. Only lane0 is consumed in this delivery module.
    input  wire [MAX_LANES-1:0]          s_keep,
    // Start-of-frame marker for the input beat.
    input  wire                          s_sof,
    // End-of-line marker for the input beat.
    input  wire                          s_eol,
    // End-of-frame marker for the input beat.
    input  wire                          s_eof,
    // Output beat valid flag.
    output reg                           m_valid,
    // Downstream backpressure flag.
    input  wire                          m_ready,
    // Output 3x3 window data. Only lane0 carries a valid window.
    output reg  [MAX_LANES*DATA_W*9-1:0] m_data,
    // Output lane-valid mask.
    output reg  [MAX_LANES-1:0]          m_keep,
    // Start-of-frame marker for the output beat.
    output reg                           m_sof,
    // End-of-line marker for the output beat.
    output reg                           m_eol,
    // End-of-frame marker for the output beat.
    output reg                           m_eof
);

    localparam [1:0] ST_REAL       = 2'd0;
    localparam [1:0] ST_EOL_FLUSH  = 2'd1;
    localparam [1:0] ST_BOTTOM_ROW = 2'd2;
    localparam [1:0] ST_BOTTOM_EOL = 2'd3;

    localparam [1:0] OP_REAL       = 2'd0;
    localparam [1:0] OP_EOL_FLUSH  = 2'd1;
    localparam [1:0] OP_BOTTOM_ROW = 2'd2;
    localparam [1:0] OP_BOTTOM_EOL = 2'd3;

    localparam [15:0] IMG_WIDTH_U16       = IMG_WIDTH[15:0];
    localparam [15:0] IMG_HEIGHT_U16      = IMG_HEIGHT[15:0];
    localparam [15:0] IMG_WIDTH_LAST_U16  = IMG_WIDTH_U16 - 16'd1;
    localparam [15:0] IMG_HEIGHT_LAST_U16 = IMG_HEIGHT_U16 - 16'd1;

    // Two line stores hold the previous two rows. Removing the bulk reset lets
    // Vivado infer real memory instead of a wide register/mux fabric.
    (* ram_style = "block" *) reg [DATA_W-1:0] line_mem0 [0:IMG_WIDTH-1];
    (* ram_style = "block" *) reg [DATA_W-1:0] line_mem1 [0:IMG_WIDTH-1];

    // Scheduler state decides which request the block issues next.
    reg [1:0]  state_q;
    reg        last_row_was_eof_q;
    reg [15:0] real_row_idx_q;
    reg [15:0] real_col_idx_q;
    reg [15:0] flush_row_idx_q;
    reg [15:0] bottom_col_idx_q;

    // Request stage keeps one issued beat while the response stage is blocked.
    reg        req_valid_q;
    reg [1:0]  req_op_q;
    reg [15:0] req_row_idx_q;
    reg [15:0] req_col_idx_q;
    reg [DATA_W-1:0] req_pixel_q;

    // Synchronous memory readbacks aligned with the request stage.
    reg [DATA_W-1:0] mem0_rd_q;
    reg [DATA_W-1:0] mem1_rd_q;

    // Internal response stage decouples the memory pipeline from m_ready.
    reg                           pipe_valid_q;
    reg  [MAX_LANES*DATA_W*9-1:0] pipe_data_q;
    reg  [MAX_LANES-1:0]          pipe_keep_q;
    reg                           pipe_sof_q;
    reg                           pipe_eol_q;
    reg                           pipe_eof_q;

    // Window history for the three active rows.
    reg [DATA_W-1:0] row0_c1_q;
    reg [DATA_W-1:0] row0_c2_q;
    reg [DATA_W-1:0] row1_c1_q;
    reg [DATA_W-1:0] row1_c2_q;
    reg [DATA_W-1:0] row2_c1_q;
    reg [DATA_W-1:0] row2_c2_q;

    // End-of-row replication uses the most recent pixel from each row.
    reg [DATA_W-1:0] last_row0_pix_q;
    reg [DATA_W-1:0] last_row1_pix_q;
    reg [DATA_W-1:0] last_row2_pix_q;

    // Emit counters track the center pixel order on the output stream.
    reg [15:0] emit_row_idx_q;
    reg [15:0] emit_col_idx_q;

    reg                           resp_valid_w;
    reg  [MAX_LANES*DATA_W*9-1:0] resp_data_w;
    reg  [MAX_LANES-1:0]          resp_keep_w;
    reg                           resp_sof_w;
    reg                           resp_eol_w;
    reg                           resp_eof_w;

    reg [DATA_W-1:0] resp_row0_v;
    reg [DATA_W-1:0] resp_row1_v;
    reg [DATA_W-1:0] resp_row2_v;
    reg [DATA_W*9-1:0] resp_window_v;
    reg [15:0]       resp_feed_col_v;
    reg              resp_has_output_v;

    reg [DATA_W-1:0] next_row0_c1_v;
    reg [DATA_W-1:0] next_row0_c2_v;
    reg [DATA_W-1:0] next_row1_c1_v;
    reg [DATA_W-1:0] next_row1_c2_v;
    reg [DATA_W-1:0] next_row2_c1_v;
    reg [DATA_W-1:0] next_row2_c2_v;
    reg [DATA_W-1:0] next_last_row0_pix_v;
    reg [DATA_W-1:0] next_last_row1_pix_v;
    reg [DATA_W-1:0] next_last_row2_pix_v;
    reg [15:0]       next_emit_row_idx_v;
    reg [15:0]       next_emit_col_idx_v;

    wire m_advance_w;
    wire pipe_ready_w;
    wire req_ready_w;
    wire issue_real_fire_w;
    wire issue_internal_fire_w;
    wire issue_fire_w;
    wire [1:0]  issue_op_w;
    wire [15:0] issue_row_idx_w;
    wire [15:0] issue_col_idx_w;
    wire [DATA_W-1:0] issue_pixel_w;
    wire issue_use_mem_w;

    // Assemble the current 3x3 window with left/right border replication.
    function [DATA_W*9-1:0] assemble_window;
        input [15:0]       col_idx;
        input [DATA_W-1:0] in_row0_c1;
        input [DATA_W-1:0] in_row0_c2;
        input [DATA_W-1:0] in_row1_c1;
        input [DATA_W-1:0] in_row1_c2;
        input [DATA_W-1:0] in_row2_c1;
        input [DATA_W-1:0] in_row2_c2;
        input [DATA_W-1:0] in_row0_cur;
        input [DATA_W-1:0] in_row1_cur;
        input [DATA_W-1:0] in_row2_cur;
        begin
            if (col_idx == 16'd0) begin
                assemble_window = {
                    in_row0_cur, in_row0_cur, in_row0_cur,
                    in_row1_cur, in_row1_cur, in_row1_cur,
                    in_row2_cur, in_row2_cur, in_row2_cur
                };
            end else if (col_idx == 16'd1) begin
                assemble_window = {
                    in_row0_c1, in_row0_c1, in_row0_cur,
                    in_row1_c1, in_row1_c1, in_row1_cur,
                    in_row2_c1, in_row2_c1, in_row2_cur
                };
            end else begin
                assemble_window = {
                    in_row0_c2, in_row0_c1, in_row0_cur,
                    in_row1_c2, in_row1_c1, in_row1_cur,
                    in_row2_c2, in_row2_c1, in_row2_cur
                };
            end
        end
    endfunction

    assign m_advance_w       = (~m_valid) | m_ready;
    assign pipe_ready_w      = (~pipe_valid_q) | m_advance_w;
    assign req_ready_w       = (~req_valid_q) | pipe_ready_w;
    assign issue_real_fire_w = (state_q == ST_REAL) && s_valid && s_keep[0] && req_ready_w;
    assign issue_internal_fire_w = (state_q != ST_REAL) && req_ready_w;
    assign issue_fire_w      = issue_real_fire_w | issue_internal_fire_w;
    assign issue_op_w        = (state_q == ST_REAL)      ? OP_REAL :
                               (state_q == ST_EOL_FLUSH) ? OP_EOL_FLUSH :
                               (state_q == ST_BOTTOM_ROW)? OP_BOTTOM_ROW :
                                                            OP_BOTTOM_EOL;
    assign issue_row_idx_w   = (issue_op_w == OP_REAL)      ? real_row_idx_q  :
                               (issue_op_w == OP_EOL_FLUSH) ? flush_row_idx_q :
                                                               16'd0;
    assign issue_col_idx_w   = (issue_op_w == OP_REAL)       ? real_col_idx_q   :
                               (issue_op_w == OP_BOTTOM_ROW) ? bottom_col_idx_q :
                                                                IMG_WIDTH_U16;
    assign issue_pixel_w     = s_data[DATA_W-1:0];
    assign issue_use_mem_w   = (issue_op_w == OP_REAL) || (issue_op_w == OP_BOTTOM_ROW);
    assign s_ready           = req_ready_w && (state_q == ST_REAL);

    // Build the response window and the next horizontal history state for the
    // request that is currently parked in the request stage.
    always @* begin
        resp_valid_w = 1'b0;
        resp_data_w  = {(MAX_LANES*DATA_W*9){1'b0}};
        resp_keep_w  = {MAX_LANES{1'b0}};
        resp_sof_w   = 1'b0;
        resp_eol_w   = 1'b0;
        resp_eof_w   = 1'b0;

        resp_row0_v      = {DATA_W{1'b0}};
        resp_row1_v      = {DATA_W{1'b0}};
        resp_row2_v      = {DATA_W{1'b0}};
        resp_window_v    = {(DATA_W*9){1'b0}};
        resp_feed_col_v  = 16'd0;
        resp_has_output_v = 1'b0;

        next_row0_c1_v = row0_c1_q;
        next_row0_c2_v = row0_c2_q;
        next_row1_c1_v = row1_c1_q;
        next_row1_c2_v = row1_c2_q;
        next_row2_c1_v = row2_c1_q;
        next_row2_c2_v = row2_c2_q;

        next_last_row0_pix_v = last_row0_pix_q;
        next_last_row1_pix_v = last_row1_pix_q;
        next_last_row2_pix_v = last_row2_pix_q;

        next_emit_row_idx_v = emit_row_idx_q;
        next_emit_col_idx_v = emit_col_idx_q;

        if (req_valid_q) begin
            case (req_op_q)
                OP_REAL: begin
                    resp_feed_col_v = req_col_idx_q;
                    resp_row2_v = req_pixel_q;
                    if (req_row_idx_q == 16'd0) begin
                        resp_row0_v = req_pixel_q;
                        resp_row1_v = req_pixel_q;
                    end else begin
                        resp_row0_v = mem1_rd_q;
                        resp_row1_v = mem0_rd_q;
                    end

                    resp_has_output_v = (req_row_idx_q >= 16'd1) &&
                                        (req_col_idx_q >= 16'd1);
                    resp_window_v = assemble_window(
                        resp_feed_col_v,
                        row0_c1_q, row0_c2_q,
                        row1_c1_q, row1_c2_q,
                        row2_c1_q, row2_c2_q,
                        resp_row0_v, resp_row1_v, resp_row2_v
                    );

                    next_last_row0_pix_v = resp_row0_v;
                    next_last_row1_pix_v = resp_row1_v;
                    next_last_row2_pix_v = resp_row2_v;

                    next_row0_c2_v = row0_c1_q;
                    next_row0_c1_v = resp_row0_v;
                    next_row1_c2_v = row1_c1_q;
                    next_row1_c1_v = resp_row1_v;
                    next_row2_c2_v = row2_c1_q;
                    next_row2_c1_v = resp_row2_v;

                    if (resp_has_output_v) begin
                        resp_valid_w = 1'b1;
                        resp_data_w[DATA_W*9-1:0] = resp_window_v;
                        resp_keep_w = {{(MAX_LANES-1){1'b0}}, 1'b1};
                        resp_sof_w  = (emit_row_idx_q == 16'd0) &&
                                      (emit_col_idx_q == 16'd0);
                        resp_eol_w  = (emit_col_idx_q == IMG_WIDTH_LAST_U16);
                        resp_eof_w  = (emit_row_idx_q == IMG_HEIGHT_LAST_U16) &&
                                      (emit_col_idx_q == IMG_WIDTH_LAST_U16);

                        if ((emit_row_idx_q == IMG_HEIGHT_LAST_U16) &&
                            (emit_col_idx_q == IMG_WIDTH_LAST_U16)) begin
                            next_emit_row_idx_v = 16'd0;
                            next_emit_col_idx_v = 16'd0;
                        end else if (emit_col_idx_q == IMG_WIDTH_LAST_U16) begin
                            next_emit_row_idx_v = emit_row_idx_q + 16'd1;
                            next_emit_col_idx_v = 16'd0;
                        end else begin
                            next_emit_row_idx_v = emit_row_idx_q;
                            next_emit_col_idx_v = emit_col_idx_q + 16'd1;
                        end
                    end
                end

                OP_EOL_FLUSH: begin
                    resp_feed_col_v = IMG_WIDTH_U16;
                    resp_row0_v = last_row0_pix_q;
                    resp_row1_v = last_row1_pix_q;
                    resp_row2_v = last_row2_pix_q;
                    resp_has_output_v = (req_row_idx_q >= 16'd1);
                    resp_window_v = assemble_window(
                        resp_feed_col_v,
                        row0_c1_q, row0_c2_q,
                        row1_c1_q, row1_c2_q,
                        row2_c1_q, row2_c2_q,
                        resp_row0_v, resp_row1_v, resp_row2_v
                    );

                    next_last_row0_pix_v = resp_row0_v;
                    next_last_row1_pix_v = resp_row1_v;
                    next_last_row2_pix_v = resp_row2_v;

                    next_row0_c1_v = {DATA_W{1'b0}};
                    next_row0_c2_v = {DATA_W{1'b0}};
                    next_row1_c1_v = {DATA_W{1'b0}};
                    next_row1_c2_v = {DATA_W{1'b0}};
                    next_row2_c1_v = {DATA_W{1'b0}};
                    next_row2_c2_v = {DATA_W{1'b0}};

                    if (resp_has_output_v) begin
                        resp_valid_w = 1'b1;
                        resp_data_w[DATA_W*9-1:0] = resp_window_v;
                        resp_keep_w = {{(MAX_LANES-1){1'b0}}, 1'b1};
                        resp_sof_w  = (emit_row_idx_q == 16'd0) &&
                                      (emit_col_idx_q == 16'd0);
                        resp_eol_w  = (emit_col_idx_q == IMG_WIDTH_LAST_U16);
                        resp_eof_w  = (emit_row_idx_q == IMG_HEIGHT_LAST_U16) &&
                                      (emit_col_idx_q == IMG_WIDTH_LAST_U16);

                        if ((emit_row_idx_q == IMG_HEIGHT_LAST_U16) &&
                            (emit_col_idx_q == IMG_WIDTH_LAST_U16)) begin
                            next_emit_row_idx_v = 16'd0;
                            next_emit_col_idx_v = 16'd0;
                        end else if (emit_col_idx_q == IMG_WIDTH_LAST_U16) begin
                            next_emit_row_idx_v = emit_row_idx_q + 16'd1;
                            next_emit_col_idx_v = 16'd0;
                        end else begin
                            next_emit_row_idx_v = emit_row_idx_q;
                            next_emit_col_idx_v = emit_col_idx_q + 16'd1;
                        end
                    end
                end

                OP_BOTTOM_ROW: begin
                    resp_feed_col_v = req_col_idx_q;
                    resp_row0_v = mem1_rd_q;
                    resp_row1_v = mem0_rd_q;
                    resp_row2_v = mem0_rd_q;
                    resp_has_output_v = (req_col_idx_q >= 16'd1);
                    resp_window_v = assemble_window(
                        resp_feed_col_v,
                        row0_c1_q, row0_c2_q,
                        row1_c1_q, row1_c2_q,
                        row2_c1_q, row2_c2_q,
                        resp_row0_v, resp_row1_v, resp_row2_v
                    );

                    next_last_row0_pix_v = resp_row0_v;
                    next_last_row1_pix_v = resp_row1_v;
                    next_last_row2_pix_v = resp_row2_v;

                    next_row0_c2_v = row0_c1_q;
                    next_row0_c1_v = resp_row0_v;
                    next_row1_c2_v = row1_c1_q;
                    next_row1_c1_v = resp_row1_v;
                    next_row2_c2_v = row2_c1_q;
                    next_row2_c1_v = resp_row2_v;

                    if (resp_has_output_v) begin
                        resp_valid_w = 1'b1;
                        resp_data_w[DATA_W*9-1:0] = resp_window_v;
                        resp_keep_w = {{(MAX_LANES-1){1'b0}}, 1'b1};
                        resp_sof_w  = (emit_row_idx_q == 16'd0) &&
                                      (emit_col_idx_q == 16'd0);
                        resp_eol_w  = (emit_col_idx_q == IMG_WIDTH_LAST_U16);
                        resp_eof_w  = (emit_row_idx_q == IMG_HEIGHT_LAST_U16) &&
                                      (emit_col_idx_q == IMG_WIDTH_LAST_U16);

                        if ((emit_row_idx_q == IMG_HEIGHT_LAST_U16) &&
                            (emit_col_idx_q == IMG_WIDTH_LAST_U16)) begin
                            next_emit_row_idx_v = 16'd0;
                            next_emit_col_idx_v = 16'd0;
                        end else if (emit_col_idx_q == IMG_WIDTH_LAST_U16) begin
                            next_emit_row_idx_v = emit_row_idx_q + 16'd1;
                            next_emit_col_idx_v = 16'd0;
                        end else begin
                            next_emit_row_idx_v = emit_row_idx_q;
                            next_emit_col_idx_v = emit_col_idx_q + 16'd1;
                        end
                    end
                end

                OP_BOTTOM_EOL: begin
                    resp_feed_col_v = IMG_WIDTH_U16;
                    resp_row0_v = last_row0_pix_q;
                    resp_row1_v = last_row1_pix_q;
                    resp_row2_v = last_row2_pix_q;
                    resp_window_v = assemble_window(
                        resp_feed_col_v,
                        row0_c1_q, row0_c2_q,
                        row1_c1_q, row1_c2_q,
                        row2_c1_q, row2_c2_q,
                        resp_row0_v, resp_row1_v, resp_row2_v
                    );

                    next_row0_c1_v = {DATA_W{1'b0}};
                    next_row0_c2_v = {DATA_W{1'b0}};
                    next_row1_c1_v = {DATA_W{1'b0}};
                    next_row1_c2_v = {DATA_W{1'b0}};
                    next_row2_c1_v = {DATA_W{1'b0}};
                    next_row2_c2_v = {DATA_W{1'b0}};

                    resp_valid_w = 1'b1;
                    resp_data_w[DATA_W*9-1:0] = resp_window_v;
                    resp_keep_w = {{(MAX_LANES-1){1'b0}}, 1'b1};
                    resp_sof_w  = (emit_row_idx_q == 16'd0) &&
                                  (emit_col_idx_q == 16'd0);
                    resp_eol_w  = (emit_col_idx_q == IMG_WIDTH_LAST_U16);
                    resp_eof_w  = (emit_row_idx_q == IMG_HEIGHT_LAST_U16) &&
                                  (emit_col_idx_q == IMG_WIDTH_LAST_U16);

                    next_emit_row_idx_v = 16'd0;
                    next_emit_col_idx_v = 16'd0;
                end

                default: begin
                    resp_valid_w = 1'b0;
                end
            endcase
        end
    end

    // Read the line memories and perform the row handoff for the just-issued
    // request. Keeping the arrays out of reset lets the tool infer RAM.
    always @(posedge clk) begin
        if (issue_fire_w && issue_use_mem_w) begin
            mem0_rd_q <= line_mem0[issue_col_idx_w];
            mem1_rd_q <= line_mem1[issue_col_idx_w];

            if (issue_op_w == OP_REAL) begin
                if (issue_row_idx_w == 16'd0) begin
                    line_mem0[issue_col_idx_w] <= issue_pixel_w;
                    line_mem1[issue_col_idx_w] <= issue_pixel_w;
                end else begin
                    line_mem1[issue_col_idx_w] <= line_mem0[issue_col_idx_w];
                    line_mem0[issue_col_idx_w] <= issue_pixel_w;
                end
            end
        end
    end

    // Advance the request, response, and visible output stages while keeping
    // the scheduler and window-history state aligned with the accepted beat.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q <= ST_REAL;
            last_row_was_eof_q <= 1'b0;
            real_row_idx_q <= 16'd0;
            real_col_idx_q <= 16'd0;
            flush_row_idx_q <= 16'd0;
            bottom_col_idx_q <= 16'd0;

            req_valid_q <= 1'b0;
            req_op_q <= OP_REAL;
            req_row_idx_q <= 16'd0;
            req_col_idx_q <= 16'd0;
            req_pixel_q <= {DATA_W{1'b0}};

            pipe_valid_q <= 1'b0;
            pipe_data_q  <= {(MAX_LANES*DATA_W*9){1'b0}};
            pipe_keep_q  <= {MAX_LANES{1'b0}};
            pipe_sof_q   <= 1'b0;
            pipe_eol_q   <= 1'b0;
            pipe_eof_q   <= 1'b0;

            row0_c1_q <= {DATA_W{1'b0}};
            row0_c2_q <= {DATA_W{1'b0}};
            row1_c1_q <= {DATA_W{1'b0}};
            row1_c2_q <= {DATA_W{1'b0}};
            row2_c1_q <= {DATA_W{1'b0}};
            row2_c2_q <= {DATA_W{1'b0}};

            last_row0_pix_q <= {DATA_W{1'b0}};
            last_row1_pix_q <= {DATA_W{1'b0}};
            last_row2_pix_q <= {DATA_W{1'b0}};

            emit_row_idx_q <= 16'd0;
            emit_col_idx_q <= 16'd0;

            m_valid <= 1'b0;
            m_data  <= {(MAX_LANES*DATA_W*9){1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else begin
            if (m_advance_w) begin
                m_valid <= pipe_valid_q;
                if (pipe_valid_q) begin
                    m_data <= pipe_data_q;
                    m_keep <= pipe_keep_q;
                    m_sof  <= pipe_sof_q;
                    m_eol  <= pipe_eol_q;
                    m_eof  <= pipe_eof_q;
                end else begin
                    m_data <= {(MAX_LANES*DATA_W*9){1'b0}};
                    m_keep <= {MAX_LANES{1'b0}};
                    m_sof  <= 1'b0;
                    m_eol  <= 1'b0;
                    m_eof  <= 1'b0;
                end
            end

            if (pipe_ready_w) begin
                pipe_valid_q <= resp_valid_w;
                if (resp_valid_w) begin
                    pipe_data_q <= resp_data_w;
                    pipe_keep_q <= resp_keep_w;
                    pipe_sof_q  <= resp_sof_w;
                    pipe_eol_q  <= resp_eol_w;
                    pipe_eof_q  <= resp_eof_w;
                end else begin
                    pipe_data_q <= {(MAX_LANES*DATA_W*9){1'b0}};
                    pipe_keep_q <= {MAX_LANES{1'b0}};
                    pipe_sof_q  <= 1'b0;
                    pipe_eol_q  <= 1'b0;
                    pipe_eof_q  <= 1'b0;
                end

                if (req_valid_q) begin
                    row0_c1_q <= next_row0_c1_v;
                    row0_c2_q <= next_row0_c2_v;
                    row1_c1_q <= next_row1_c1_v;
                    row1_c2_q <= next_row1_c2_v;
                    row2_c1_q <= next_row2_c1_v;
                    row2_c2_q <= next_row2_c2_v;

                    last_row0_pix_q <= next_last_row0_pix_v;
                    last_row1_pix_q <= next_last_row1_pix_v;
                    last_row2_pix_q <= next_last_row2_pix_v;

                    emit_row_idx_q <= next_emit_row_idx_v;
                    emit_col_idx_q <= next_emit_col_idx_v;
                end
            end

            if (req_ready_w) begin
                req_valid_q <= issue_fire_w;
                if (issue_fire_w) begin
                    req_op_q <= issue_op_w;
                    req_row_idx_q <= issue_row_idx_w;
                    req_col_idx_q <= issue_col_idx_w;
                    req_pixel_q <= issue_pixel_w;

                    case (issue_op_w)
                        OP_REAL: begin
                            if (s_eol) begin
                                state_q <= ST_EOL_FLUSH;
                                flush_row_idx_q <= real_row_idx_q;
                                last_row_was_eof_q <= s_eof;
                                real_row_idx_q <= real_row_idx_q + 16'd1;
                                real_col_idx_q <= 16'd0;
                            end else begin
                                real_col_idx_q <= real_col_idx_q + 16'd1;
                            end
                        end

                        OP_EOL_FLUSH: begin
                            if (last_row_was_eof_q) begin
                                state_q <= ST_BOTTOM_ROW;
                                bottom_col_idx_q <= 16'd0;
                            end else begin
                                state_q <= ST_REAL;
                            end
                        end

                        OP_BOTTOM_ROW: begin
                            if (bottom_col_idx_q == IMG_WIDTH_LAST_U16) begin
                                state_q <= ST_BOTTOM_EOL;
                            end else begin
                                bottom_col_idx_q <= bottom_col_idx_q + 16'd1;
                            end
                        end

                        OP_BOTTOM_EOL: begin
                            state_q <= ST_REAL;
                            last_row_was_eof_q <= 1'b0;
                            real_row_idx_q <= 16'd0;
                            real_col_idx_q <= 16'd0;
                            flush_row_idx_q <= 16'd0;
                            bottom_col_idx_q <= 16'd0;
                        end

                        default: begin
                            state_q <= ST_REAL;
                        end
                    endcase
                end
            end
        end
    end

endmodule
