`timescale 1ns / 1ps

module window3x3_stream_std #(
    parameter integer MAX_LANES  = 1,
    parameter integer DATA_W     = 8,
    parameter integer IMG_WIDTH  = 1440,
    parameter integer IMG_HEIGHT = 1920
) (
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          s_valid,
    output wire                          s_ready,
    input  wire [MAX_LANES*DATA_W-1:0]   s_data,
    input  wire [MAX_LANES-1:0]          s_keep,
    input  wire                          s_sof,
    input  wire                          s_eol,
    input  wire                          s_eof,
    output reg                           m_valid,
    input  wire                          m_ready,
    output reg  [MAX_LANES*DATA_W*9-1:0] m_data,
    output reg  [MAX_LANES-1:0]          m_keep,
    output reg                           m_sof,
    output reg                           m_eol,
    output reg                           m_eof
);

    localparam [1:0] ST_REAL       = 2'd0;
    localparam [1:0] ST_EOL_FLUSH  = 2'd1;
    localparam [1:0] ST_BOTTOM_ROW = 2'd2;
    localparam [1:0] ST_BOTTOM_EOL = 2'd3;

    reg [DATA_W-1:0] line_mem0 [0:IMG_WIDTH-1];
    reg [DATA_W-1:0] line_mem1 [0:IMG_WIDTH-1];

    reg [1:0]  state;
    reg [1:0]  state_next;
    reg        last_row_was_eof;
    reg [15:0] real_row_idx;
    reg [15:0] real_col_idx;
    reg [15:0] flush_row_idx;
    reg [15:0] bottom_col_idx;
    reg [15:0] emit_row_idx;
    reg [15:0] emit_col_idx;
    integer idx;

    reg [DATA_W-1:0] row0_c1;
    reg [DATA_W-1:0] row0_c2;
    reg [DATA_W-1:0] row1_c1;
    reg [DATA_W-1:0] row1_c2;
    reg [DATA_W-1:0] row2_c1;
    reg [DATA_W-1:0] row2_c2;

    reg [DATA_W-1:0] last_row0_pix;
    reg [DATA_W-1:0] last_row1_pix;
    reg [DATA_W-1:0] last_row2_pix;

    reg [DATA_W-1:0]   cur_row0;
    reg [DATA_W-1:0]   cur_row1;
    reg [DATA_W-1:0]   cur_row2;
    reg [DATA_W*9-1:0] cur_window;
    reg [15:0]         cur_feed_col;
    reg                cur_has_output;
    wire               pipe_advance;

    // Current delivery implementation only processes lane0 data even though the
    // bus shape is parameterized by MAX_LANES. Keep MAX_LANES=1 in board use.

    function [DATA_W*9-1:0] assemble_window;
        input [15:0]        col_idx;
        input [DATA_W-1:0]  in_row0_c1;
        input [DATA_W-1:0]  in_row0_c2;
        input [DATA_W-1:0]  in_row1_c1;
        input [DATA_W-1:0]  in_row1_c2;
        input [DATA_W-1:0]  in_row2_c1;
        input [DATA_W-1:0]  in_row2_c2;
        input [DATA_W-1:0]  in_row0_cur;
        input [DATA_W-1:0]  in_row1_cur;
        input [DATA_W-1:0]  in_row2_cur;
        begin
            if (col_idx == 0) begin
                assemble_window = {
                    in_row0_cur, in_row0_cur, in_row0_cur,
                    in_row1_cur, in_row1_cur, in_row1_cur,
                    in_row2_cur, in_row2_cur, in_row2_cur
                };
            end else if (col_idx == 1) begin
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

    assign pipe_advance = (~m_valid) | m_ready;
    assign s_ready = pipe_advance && (state == ST_REAL);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_REAL;
        end else if (pipe_advance) begin
            state <= state_next;
        end
    end

    always @* begin
        state_next = state;
        case (state)
            ST_REAL: begin
                if (s_valid && s_keep[0] && s_eol) begin
                    state_next = ST_EOL_FLUSH;
                end
            end
            ST_EOL_FLUSH: begin
                if (last_row_was_eof) begin
                    state_next = ST_BOTTOM_ROW;
                end else begin
                    state_next = ST_REAL;
                end
            end
            ST_BOTTOM_ROW: begin
                if (bottom_col_idx == (IMG_WIDTH - 1)) begin
                    state_next = ST_BOTTOM_EOL;
                end
            end
            ST_BOTTOM_EOL: begin
                state_next = ST_REAL;
            end
            default: begin
                state_next = ST_REAL;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            last_row_was_eof <= 1'b0;
            real_row_idx <= 0;
            real_col_idx <= 0;
            flush_row_idx <= 0;
            bottom_col_idx <= 0;
            emit_row_idx <= 0;
            emit_col_idx <= 0;

            row0_c1 <= {DATA_W{1'b0}};
            row0_c2 <= {DATA_W{1'b0}};
            row1_c1 <= {DATA_W{1'b0}};
            row1_c2 <= {DATA_W{1'b0}};
            row2_c1 <= {DATA_W{1'b0}};
            row2_c2 <= {DATA_W{1'b0}};

            last_row0_pix <= {DATA_W{1'b0}};
            last_row1_pix <= {DATA_W{1'b0}};
            last_row2_pix <= {DATA_W{1'b0}};

            cur_row0 <= {DATA_W{1'b0}};
            cur_row1 <= {DATA_W{1'b0}};
            cur_row2 <= {DATA_W{1'b0}};
            cur_window <= {(DATA_W*9){1'b0}};
            cur_feed_col <= 0;
            cur_has_output <= 1'b0;

            m_valid <= 1'b0;
            m_data  <= {(MAX_LANES*DATA_W*9){1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;

            for (idx = 0; idx < IMG_WIDTH; idx = idx + 1) begin
                line_mem0[idx] <= {DATA_W{1'b0}};
                line_mem1[idx] <= {DATA_W{1'b0}};
            end
        end else if (pipe_advance) begin
            cur_row0 = {DATA_W{1'b0}};
            cur_row1 = {DATA_W{1'b0}};
            cur_row2 = {DATA_W{1'b0}};
            cur_window = {(DATA_W*9){1'b0}};
            cur_feed_col = 0;
            cur_has_output = 1'b0;

            case (state)
                ST_REAL: begin
                    if (s_valid && s_keep[0]) begin
                        cur_feed_col = real_col_idx;
                        cur_row2 = s_data[DATA_W-1:0];
                        if (real_row_idx == 0) begin
                            cur_row0 = s_data[DATA_W-1:0];
                            cur_row1 = s_data[DATA_W-1:0];
                        end else if (real_col_idx < IMG_WIDTH) begin
                            cur_row0 = line_mem1[real_col_idx];
                            cur_row1 = line_mem0[real_col_idx];
                        end
                        cur_has_output = ((real_row_idx >= 1) && (real_col_idx >= 1));
                        cur_window = assemble_window(
                            cur_feed_col,
                            row0_c1, row0_c2,
                            row1_c1, row1_c2,
                            row2_c1, row2_c2,
                            cur_row0, cur_row1, cur_row2
                        );

                        last_row0_pix <= cur_row0;
                        last_row1_pix <= cur_row1;
                        last_row2_pix <= cur_row2;

                        row0_c2 <= row0_c1;
                        row0_c1 <= cur_row0;
                        row1_c2 <= row1_c1;
                        row1_c1 <= cur_row1;
                        row2_c2 <= row2_c1;
                        row2_c1 <= cur_row2;

                        if (real_col_idx < IMG_WIDTH) begin
                            if (real_row_idx == 0) begin
                                line_mem1[real_col_idx] <= s_data[DATA_W-1:0];
                                line_mem0[real_col_idx] <= s_data[DATA_W-1:0];
                            end else begin
                                line_mem1[real_col_idx] <= line_mem0[real_col_idx];
                                line_mem0[real_col_idx] <= s_data[DATA_W-1:0];
                            end
                        end

                        if (s_eol) begin
                            flush_row_idx <= real_row_idx;
                            last_row_was_eof <= s_eof;
                            real_row_idx <= real_row_idx + 1;
                            real_col_idx <= 0;
                        end else begin
                            real_col_idx <= real_col_idx + 1;
                        end

                        m_valid <= cur_has_output;
                        if (cur_has_output) begin
                            m_data[DATA_W*9-1:0] <= cur_window;
                            m_keep <= {{(MAX_LANES-1){1'b0}}, 1'b1};
                            m_sof <= ((emit_row_idx == 0) && (emit_col_idx == 0));
                            m_eol <= (emit_col_idx == (IMG_WIDTH - 1));
                            m_eof <= ((emit_row_idx == (IMG_HEIGHT - 1)) &&
                                      (emit_col_idx == (IMG_WIDTH - 1)));

                            if ((emit_row_idx == (IMG_HEIGHT - 1)) &&
                                (emit_col_idx == (IMG_WIDTH - 1))) begin
                                emit_row_idx <= 0;
                                emit_col_idx <= 0;
                            end else if (emit_col_idx == (IMG_WIDTH - 1)) begin
                                emit_row_idx <= emit_row_idx + 1;
                                emit_col_idx <= 0;
                            end else begin
                                emit_col_idx <= emit_col_idx + 1;
                            end
                        end else begin
                            m_data <= {(MAX_LANES*DATA_W*9){1'b0}};
                            m_keep <= {MAX_LANES{1'b0}};
                            m_sof  <= 1'b0;
                            m_eol  <= 1'b0;
                            m_eof  <= 1'b0;
                        end
                    end else begin
                        m_valid <= 1'b0;
                        m_data  <= {(MAX_LANES*DATA_W*9){1'b0}};
                        m_keep  <= {MAX_LANES{1'b0}};
                        m_sof   <= 1'b0;
                        m_eol   <= 1'b0;
                        m_eof   <= 1'b0;
                    end
                end

                ST_EOL_FLUSH: begin
                    cur_feed_col = IMG_WIDTH;
                    cur_row0 = last_row0_pix;
                    cur_row1 = last_row1_pix;
                    cur_row2 = last_row2_pix;
                    cur_has_output = (flush_row_idx >= 1);
                    cur_window = assemble_window(
                        cur_feed_col,
                        row0_c1, row0_c2,
                        row1_c1, row1_c2,
                        row2_c1, row2_c2,
                        cur_row0, cur_row1, cur_row2
                    );

                    last_row0_pix <= cur_row0;
                    last_row1_pix <= cur_row1;
                    last_row2_pix <= cur_row2;

                    row0_c1 <= {DATA_W{1'b0}};
                    row0_c2 <= {DATA_W{1'b0}};
                    row1_c1 <= {DATA_W{1'b0}};
                    row1_c2 <= {DATA_W{1'b0}};
                    row2_c1 <= {DATA_W{1'b0}};
                    row2_c2 <= {DATA_W{1'b0}};

                    if (last_row_was_eof) begin
                        bottom_col_idx <= 0;
                    end

                    m_valid <= cur_has_output;
                    if (cur_has_output) begin
                        m_data[DATA_W*9-1:0] <= cur_window;
                        m_keep <= {{(MAX_LANES-1){1'b0}}, 1'b1};
                        m_sof <= ((emit_row_idx == 0) && (emit_col_idx == 0));
                        m_eol <= (emit_col_idx == (IMG_WIDTH - 1));
                        m_eof <= ((emit_row_idx == (IMG_HEIGHT - 1)) &&
                                  (emit_col_idx == (IMG_WIDTH - 1)));

                        if ((emit_row_idx == (IMG_HEIGHT - 1)) &&
                            (emit_col_idx == (IMG_WIDTH - 1))) begin
                            emit_row_idx <= 0;
                            emit_col_idx <= 0;
                        end else if (emit_col_idx == (IMG_WIDTH - 1)) begin
                            emit_row_idx <= emit_row_idx + 1;
                            emit_col_idx <= 0;
                        end else begin
                            emit_col_idx <= emit_col_idx + 1;
                        end
                    end else begin
                        m_data <= {(MAX_LANES*DATA_W*9){1'b0}};
                        m_keep <= {MAX_LANES{1'b0}};
                        m_sof  <= 1'b0;
                        m_eol  <= 1'b0;
                        m_eof  <= 1'b0;
                    end
                end

                ST_BOTTOM_ROW: begin
                    cur_feed_col = bottom_col_idx;
                    if (bottom_col_idx < IMG_WIDTH) begin
                        cur_row0 = line_mem1[bottom_col_idx];
                        cur_row1 = line_mem0[bottom_col_idx];
                        cur_row2 = line_mem0[bottom_col_idx];
                    end
                    cur_has_output = (bottom_col_idx >= 1);
                    cur_window = assemble_window(
                        cur_feed_col,
                        row0_c1, row0_c2,
                        row1_c1, row1_c2,
                        row2_c1, row2_c2,
                        cur_row0, cur_row1, cur_row2
                    );

                    last_row0_pix <= cur_row0;
                    last_row1_pix <= cur_row1;
                    last_row2_pix <= cur_row2;

                    row0_c2 <= row0_c1;
                    row0_c1 <= cur_row0;
                    row1_c2 <= row1_c1;
                    row1_c1 <= cur_row1;
                    row2_c2 <= row2_c1;
                    row2_c1 <= cur_row2;

                    if (bottom_col_idx != (IMG_WIDTH - 1)) begin
                        bottom_col_idx <= bottom_col_idx + 1;
                    end

                    m_valid <= cur_has_output;
                    if (cur_has_output) begin
                        m_data[DATA_W*9-1:0] <= cur_window;
                        m_keep <= {{(MAX_LANES-1){1'b0}}, 1'b1};
                        m_sof <= ((emit_row_idx == 0) && (emit_col_idx == 0));
                        m_eol <= (emit_col_idx == (IMG_WIDTH - 1));
                        m_eof <= ((emit_row_idx == (IMG_HEIGHT - 1)) &&
                                  (emit_col_idx == (IMG_WIDTH - 1)));

                        if ((emit_row_idx == (IMG_HEIGHT - 1)) &&
                            (emit_col_idx == (IMG_WIDTH - 1))) begin
                            emit_row_idx <= 0;
                            emit_col_idx <= 0;
                        end else if (emit_col_idx == (IMG_WIDTH - 1)) begin
                            emit_row_idx <= emit_row_idx + 1;
                            emit_col_idx <= 0;
                        end else begin
                            emit_col_idx <= emit_col_idx + 1;
                        end
                    end else begin
                        m_data <= {(MAX_LANES*DATA_W*9){1'b0}};
                        m_keep <= {MAX_LANES{1'b0}};
                        m_sof  <= 1'b0;
                        m_eol  <= 1'b0;
                        m_eof  <= 1'b0;
                    end
                end

                ST_BOTTOM_EOL: begin
                    cur_feed_col = IMG_WIDTH;
                    cur_row0 = last_row0_pix;
                    cur_row1 = last_row1_pix;
                    cur_row2 = last_row2_pix;
                    cur_has_output = 1'b1;
                    cur_window = assemble_window(
                        cur_feed_col,
                        row0_c1, row0_c2,
                        row1_c1, row1_c2,
                        row2_c1, row2_c2,
                        cur_row0, cur_row1, cur_row2
                    );

                    row0_c1 <= {DATA_W{1'b0}};
                    row0_c2 <= {DATA_W{1'b0}};
                    row1_c1 <= {DATA_W{1'b0}};
                    row1_c2 <= {DATA_W{1'b0}};
                    row2_c1 <= {DATA_W{1'b0}};
                    row2_c2 <= {DATA_W{1'b0}};

                    last_row_was_eof <= 1'b0;
                    real_row_idx <= 0;
                    real_col_idx <= 0;
                    flush_row_idx <= 0;
                    bottom_col_idx <= 0;

                    m_valid <= 1'b1;
                    m_data[DATA_W*9-1:0] <= cur_window;
                    m_keep <= {{(MAX_LANES-1){1'b0}}, 1'b1};
                    m_sof <= ((emit_row_idx == 0) && (emit_col_idx == 0));
                    m_eol <= (emit_col_idx == (IMG_WIDTH - 1));
                    m_eof <= ((emit_row_idx == (IMG_HEIGHT - 1)) &&
                              (emit_col_idx == (IMG_WIDTH - 1)));

                    emit_row_idx <= 0;
                    emit_col_idx <= 0;
                end

                default: begin
                    m_valid <= 1'b0;
                    m_data  <= {(MAX_LANES*DATA_W*9){1'b0}};
                    m_keep  <= {MAX_LANES{1'b0}};
                    m_sof   <= 1'b0;
                    m_eol   <= 1'b0;
                    m_eof   <= 1'b0;
                end
            endcase
        end
    end

endmodule
