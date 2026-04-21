`timescale 1ns / 1ps

// Compute the median of a valid 3x3 grayscale window. A dedicated input stage
// is inserted ahead of the row-sort network so the window fanout and the first
// compare network do not need to share the same cycle.
module median3x3_stream_std #(
    parameter integer MAX_LANES = 1,
    parameter integer DATA_W    = 8
) (
    // Core processing clock.
    input  wire                            clk,
    // Active-low asynchronous reset.
    input  wire                            rst_n,

    // Upstream stream handshake and payload.
    input  wire                            s_valid,
    output wire                            s_ready,
    input  wire [MAX_LANES*DATA_W*9-1:0]   s_data,
    input  wire [MAX_LANES-1:0]            s_keep,
    input  wire                            s_sof,
    input  wire                            s_eol,
    input  wire                            s_eof,

    // Downstream stream handshake and payload.
    output reg                             m_valid,
    input  wire                            m_ready,
    output reg  [MAX_LANES*DATA_W-1:0]     m_data,
    output reg  [MAX_LANES-1:0]            m_keep,
    output reg                             m_sof,
    output reg                             m_eol,
    output reg                             m_eof
);

    integer lane_idx;

    wire has_active_lane;
    wire stg3_ready;
    wire stg2_ready;
    wire stg1_ready;
    wire stg0_ready;

    // Stage 0 buffers the raw 3x3 window and its metadata.
    reg                           stg0_valid;
    reg  [MAX_LANES*DATA_W*9-1:0] stg0_data;
    reg  [MAX_LANES-1:0]          stg0_keep;
    reg                           stg0_sof;
    reg                           stg0_eol;
    reg                           stg0_eof;

    // Stage 1 stores each row sorted as {min, mid, max}.
    reg                           stg1_valid;
    reg  [MAX_LANES*DATA_W*9-1:0] stg1_rowsort;
    reg  [MAX_LANES-1:0]          stg1_keep;
    reg                           stg1_sof;
    reg                           stg1_eol;
    reg                           stg1_eof;

    // Stage 2 stores the three median candidates.
    reg                           stg2_valid;
    reg  [MAX_LANES*DATA_W*3-1:0] stg2_candidates;
    reg  [MAX_LANES-1:0]          stg2_keep;
    reg                           stg2_sof;
    reg                           stg2_eol;
    reg                           stg2_eof;

    // Combinational payload for stage 1.
    reg [MAX_LANES*DATA_W*9-1:0] stg1_rowsort_comb;
    // Combinational payload for stage 2.
    reg [MAX_LANES*DATA_W*3-1:0] stg2_candidates_comb;
    // Combinational output payload.
    reg [MAX_LANES*DATA_W-1:0]   stg3_median_comb;

    // Fetch one tap from a packed 3x3 window.
    function [DATA_W-1:0] tap9;
        input [DATA_W*9-1:0] window;
        input integer        tap_idx;
        begin
            tap9 = window[(8-tap_idx)*DATA_W +: DATA_W];
        end
    endfunction

    // Fetch one value from a packed 3-value vector.
    function [DATA_W-1:0] tap3;
        input [DATA_W*3-1:0] values;
        input integer        tap_idx;
        begin
            tap3 = values[(2-tap_idx)*DATA_W +: DATA_W];
        end
    endfunction

    // Sort three values into {min, mid, max}.
    function [DATA_W*3-1:0] sort3_pack;
        input [DATA_W-1:0] a;
        input [DATA_W-1:0] b;
        input [DATA_W-1:0] c;
        reg   [DATA_W-1:0] sort_a;
        reg   [DATA_W-1:0] sort_b;
        reg   [DATA_W-1:0] sort_c;
        reg   [DATA_W-1:0] swap_tmp;
        begin
            sort_a = a;
            sort_b = b;
            sort_c = c;

            if (sort_a > sort_b) begin
                swap_tmp = sort_a;
                sort_a = sort_b;
                sort_b = swap_tmp;
            end
            if (sort_b > sort_c) begin
                swap_tmp = sort_b;
                sort_b = sort_c;
                sort_c = swap_tmp;
            end
            if (sort_a > sort_b) begin
                swap_tmp = sort_a;
                sort_a = sort_b;
                sort_b = swap_tmp;
            end

            sort3_pack = {sort_a, sort_b, sort_c};
        end
    endfunction

    // Sort the three values in each row independently.
    function [DATA_W*9-1:0] sort_window_rows;
        input [DATA_W*9-1:0] window;
        reg   [DATA_W*3-1:0] row0_sorted;
        reg   [DATA_W*3-1:0] row1_sorted;
        reg   [DATA_W*3-1:0] row2_sorted;
        begin
            row0_sorted = sort3_pack(
                tap9(window, 0),
                tap9(window, 1),
                tap9(window, 2)
            );
            row1_sorted = sort3_pack(
                tap9(window, 3),
                tap9(window, 4),
                tap9(window, 5)
            );
            row2_sorted = sort3_pack(
                tap9(window, 6),
                tap9(window, 7),
                tap9(window, 8)
            );
            sort_window_rows = {row0_sorted, row1_sorted, row2_sorted};
        end
    endfunction

    // Reduce the row-sorted results to the three median candidates.
    function [DATA_W*3-1:0] extract_median_candidates;
        input [DATA_W*9-1:0] rowsort;
        reg   [DATA_W*3-1:0] row_min_sorted;
        reg   [DATA_W*3-1:0] row_mid_sorted;
        reg   [DATA_W*3-1:0] row_max_sorted;
        begin
            row_min_sorted = sort3_pack(
                tap9(rowsort, 0),
                tap9(rowsort, 3),
                tap9(rowsort, 6)
            );
            row_mid_sorted = sort3_pack(
                tap9(rowsort, 1),
                tap9(rowsort, 4),
                tap9(rowsort, 7)
            );
            row_max_sorted = sort3_pack(
                tap9(rowsort, 2),
                tap9(rowsort, 5),
                tap9(rowsort, 8)
            );

            extract_median_candidates = {
                tap3(row_min_sorted, 2),
                tap3(row_mid_sorted, 1),
                tap3(row_max_sorted, 0)
            };
        end
    endfunction

    // Take the median of the three final candidates.
    function [DATA_W-1:0] median_from_candidates;
        input [DATA_W*3-1:0] candidates;
        reg   [DATA_W*3-1:0] candidates_sorted;
        begin
            candidates_sorted = sort3_pack(
                tap3(candidates, 0),
                tap3(candidates, 1),
                tap3(candidates, 2)
            );
            median_from_candidates = tap3(candidates_sorted, 1);
        end
    endfunction

    assign has_active_lane = |s_keep;
    assign stg3_ready = (~m_valid) | m_ready;
    assign stg2_ready = (~stg2_valid) | stg3_ready;
    assign stg1_ready = (~stg1_valid) | stg2_ready;
    assign stg0_ready = (~stg0_valid) | stg1_ready;
    assign s_ready    = stg0_ready;

    // Stage 1 combinational row sorting.
    always @* begin
        stg1_rowsort_comb = {MAX_LANES*DATA_W*9{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg0_keep[lane_idx]) begin
                stg1_rowsort_comb[lane_idx*DATA_W*9 +: DATA_W*9] =
                    sort_window_rows(stg0_data[lane_idx*DATA_W*9 +: DATA_W*9]);
            end
        end
    end

    // Stage 2 combinational candidate extraction.
    always @* begin
        stg2_candidates_comb = {MAX_LANES*DATA_W*3{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg1_keep[lane_idx]) begin
                stg2_candidates_comb[lane_idx*DATA_W*3 +: DATA_W*3] =
                    extract_median_candidates(stg1_rowsort[lane_idx*DATA_W*9 +: DATA_W*9]);
            end
        end
    end

    // Output combinational median selection.
    always @* begin
        stg3_median_comb = {MAX_LANES*DATA_W{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg2_keep[lane_idx]) begin
                stg3_median_comb[lane_idx*DATA_W +: DATA_W] =
                    median_from_candidates(stg2_candidates[lane_idx*DATA_W*3 +: DATA_W*3]);
            end
        end
    end

    // Stage 0 register buffers the window input.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg0_valid <= 1'b0;
            stg0_data  <= {MAX_LANES*DATA_W*9{1'b0}};
            stg0_keep  <= {MAX_LANES{1'b0}};
            stg0_sof   <= 1'b0;
            stg0_eol   <= 1'b0;
            stg0_eof   <= 1'b0;
        end else if (stg0_ready) begin
            stg0_valid <= s_valid && has_active_lane;
            if (s_valid && has_active_lane) begin
                stg0_data <= s_data;
                stg0_keep <= s_keep;
                stg0_sof  <= s_sof;
                stg0_eol  <= s_eol;
                stg0_eof  <= s_eof;
            end else begin
                stg0_data <= {MAX_LANES*DATA_W*9{1'b0}};
                stg0_keep <= {MAX_LANES{1'b0}};
                stg0_sof  <= 1'b0;
                stg0_eol  <= 1'b0;
                stg0_eof  <= 1'b0;
            end
        end
    end

    // Stage 1 register stores the sorted rows.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg1_valid   <= 1'b0;
            stg1_rowsort <= {MAX_LANES*DATA_W*9{1'b0}};
            stg1_keep    <= {MAX_LANES{1'b0}};
            stg1_sof     <= 1'b0;
            stg1_eol     <= 1'b0;
            stg1_eof     <= 1'b0;
        end else if (stg1_ready) begin
            stg1_valid <= stg0_valid;
            if (stg0_valid) begin
                stg1_rowsort <= stg1_rowsort_comb;
                stg1_keep    <= stg0_keep;
                stg1_sof     <= stg0_sof;
                stg1_eol     <= stg0_eol;
                stg1_eof     <= stg0_eof;
            end else begin
                stg1_rowsort <= {MAX_LANES*DATA_W*9{1'b0}};
                stg1_keep    <= {MAX_LANES{1'b0}};
                stg1_sof     <= 1'b0;
                stg1_eol     <= 1'b0;
                stg1_eof     <= 1'b0;
            end
        end
    end

    // Stage 2 register stores the median candidates.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg2_valid      <= 1'b0;
            stg2_candidates <= {MAX_LANES*DATA_W*3{1'b0}};
            stg2_keep       <= {MAX_LANES{1'b0}};
            stg2_sof        <= 1'b0;
            stg2_eol        <= 1'b0;
            stg2_eof        <= 1'b0;
        end else if (stg2_ready) begin
            stg2_valid <= stg1_valid;
            if (stg1_valid) begin
                stg2_candidates <= stg2_candidates_comb;
                stg2_keep       <= stg1_keep;
                stg2_sof        <= stg1_sof;
                stg2_eol        <= stg1_eol;
                stg2_eof        <= stg1_eof;
            end else begin
                stg2_candidates <= {MAX_LANES*DATA_W*3{1'b0}};
                stg2_keep       <= {MAX_LANES{1'b0}};
                stg2_sof        <= 1'b0;
                stg2_eol        <= 1'b0;
                stg2_eof        <= 1'b0;
            end
        end
    end

    // Output register stores the final median value.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= {MAX_LANES*DATA_W{1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else if (stg3_ready) begin
            m_valid <= stg2_valid;
            if (stg2_valid) begin
                m_data <= stg3_median_comb;
                m_keep <= stg2_keep;
                m_sof  <= stg2_sof;
                m_eol  <= stg2_eol;
                m_eof  <= stg2_eof;
            end else begin
                m_data <= {MAX_LANES*DATA_W{1'b0}};
                m_keep <= {MAX_LANES{1'b0}};
                m_sof  <= 1'b0;
                m_eol  <= 1'b0;
                m_eof  <= 1'b0;
            end
        end
    end

endmodule
