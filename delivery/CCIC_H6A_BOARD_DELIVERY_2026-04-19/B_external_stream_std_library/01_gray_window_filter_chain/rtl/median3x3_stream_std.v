`timescale 1ns / 1ps

module median3x3_stream_std #(
    parameter integer MAX_LANES = 1,
    parameter integer DATA_W    = 8
) (
    input  wire                            clk,
    input  wire                            rst_n,
    input  wire                            s_valid,
    output wire                            s_ready,
    input  wire [MAX_LANES*DATA_W*9-1:0]   s_data,
    input  wire [MAX_LANES-1:0]            s_keep,
    input  wire                            s_sof,
    input  wire                            s_eol,
    input  wire                            s_eof,
    output reg                             m_valid,
    input  wire                            m_ready,
    output reg  [MAX_LANES*DATA_W-1:0]     m_data,
    output reg  [MAX_LANES-1:0]            m_keep,
    output reg                             m_sof,
    output reg                             m_eol,
    output reg                             m_eof
);

    localparam integer STG2_PACK_W = DATA_W * 5;

    integer lane_idx;

    wire has_active_lane;
    wire out_ready;
    wire stg5_ready;
    wire stg4_ready;
    wire stg3_ready;
    wire stg2_ready;
    wire stg1a_ready;
    wire stg1_ready;
    wire stg0_ready;

    // Stage 0: input latch from upstream window stream.
    reg                             stg0_valid;
    reg  [MAX_LANES*DATA_W*9-1:0]   stg0_data;
    reg  [MAX_LANES-1:0]            stg0_keep;
    reg                             stg0_sof;
    reg                             stg0_eol;
    reg                             stg0_eof;

    // Stage 1a: first compare-swap for each row sort.
    reg                             stg1a_valid;
    reg  [MAX_LANES*DATA_W*9-1:0]   stg1a_rows_step1;
    reg  [MAX_LANES-1:0]            stg1a_keep;
    reg                             stg1a_sof;
    reg                             stg1a_eol;
    reg                             stg1a_eof;

    // Stage 1: finish row sort for each row of the 3x3 window.
    reg                             stg1_valid;
    reg  [MAX_LANES*DATA_W*9-1:0]   stg1_rowsort;
    reg  [MAX_LANES-1:0]            stg1_keep;
    reg                             stg1_sof;
    reg                             stg1_eol;
    reg                             stg1_eof;

    // Stage 2: prepare candidate metadata.
    // Packed per lane: {max(row_min), mid_step1_pack, min(row_max)}.
    reg                             stg2_valid;
    reg  [MAX_LANES*STG2_PACK_W-1:0] stg2_prep;
    reg  [MAX_LANES-1:0]            stg2_keep;
    reg                             stg2_sof;
    reg                             stg2_eol;
    reg                             stg2_eof;

    // Stage 3: complete candidate extraction.
    reg                             stg3_valid;
    reg  [MAX_LANES*DATA_W*3-1:0]   stg3_candidates;
    reg  [MAX_LANES-1:0]            stg3_keep;
    reg                             stg3_sof;
    reg                             stg3_eol;
    reg                             stg3_eof;

    // Stage 4: first compare-swap for final median(candidate0/1/2).
    reg                             stg4_valid;
    reg  [MAX_LANES*DATA_W*3-1:0]   stg4_mid_step1;
    reg  [MAX_LANES-1:0]            stg4_keep;
    reg                             stg4_sof;
    reg                             stg4_eol;
    reg                             stg4_eof;

    // Stage 5: finish final median(candidate0/1/2).
    reg                             stg5_valid;
    reg  [MAX_LANES*DATA_W-1:0]     stg5_median;
    reg  [MAX_LANES-1:0]            stg5_keep;
    reg                             stg5_sof;
    reg                             stg5_eol;
    reg                             stg5_eof;

    reg [MAX_LANES*DATA_W*9-1:0]    stg1a_rows_step1_comb;
    reg [MAX_LANES*DATA_W*9-1:0]    stg1_rowsort_comb;
    reg [MAX_LANES*STG2_PACK_W-1:0] stg2_prep_comb;
    reg [MAX_LANES*DATA_W*3-1:0]    stg3_candidates_comb;
    reg [MAX_LANES*DATA_W*3-1:0]    stg4_mid_step1_comb;
    reg [MAX_LANES*DATA_W-1:0]      stg5_median_comb;

    function [DATA_W-1:0] tap9;
        input [DATA_W*9-1:0] window;
        input integer tap_idx;
        begin
            tap9 = window[(8-tap_idx)*DATA_W +: DATA_W];
        end
    endfunction

    function [DATA_W-1:0] tap3;
        input [DATA_W*3-1:0] values;
        input integer tap_idx;
        begin
            tap3 = values[(2-tap_idx)*DATA_W +: DATA_W];
        end
    endfunction

    function [DATA_W*3-1:0] sort3_pack;
        input [DATA_W-1:0] a;
        input [DATA_W-1:0] b;
        input [DATA_W-1:0] c;
        reg [DATA_W-1:0] x;
        reg [DATA_W-1:0] y;
        reg [DATA_W-1:0] z;
        reg [DATA_W-1:0] swap_tmp;
        begin
            x = a;
            y = b;
            z = c;

            if (x > y) begin
                swap_tmp = x;
                x = y;
                y = swap_tmp;
            end
            if (y > z) begin
                swap_tmp = y;
                y = z;
                z = swap_tmp;
            end
            if (x > y) begin
                swap_tmp = x;
                x = y;
                y = swap_tmp;
            end

            sort3_pack = {x, y, z};
        end
    endfunction

    function [DATA_W-1:0] max3;
        input [DATA_W-1:0] a;
        input [DATA_W-1:0] b;
        input [DATA_W-1:0] c;
        reg [DATA_W-1:0] max_ab;
        begin
            max_ab = (a > b) ? a : b;
            max3 = (max_ab > c) ? max_ab : c;
        end
    endfunction

    function [DATA_W-1:0] min3;
        input [DATA_W-1:0] a;
        input [DATA_W-1:0] b;
        input [DATA_W-1:0] c;
        reg [DATA_W-1:0] min_ab;
        begin
            min_ab = (a < b) ? a : b;
            min3 = (min_ab < c) ? min_ab : c;
        end
    endfunction

    // First compare-swap only for median(mid) path.
    function [DATA_W*3-1:0] mid3_step1_pack;
        input [DATA_W-1:0] a;
        input [DATA_W-1:0] b;
        input [DATA_W-1:0] c;
        reg [DATA_W-1:0] x;
        reg [DATA_W-1:0] y;
        reg [DATA_W-1:0] z;
        reg [DATA_W-1:0] swap_tmp;
        begin
            x = a;
            y = b;
            z = c;
            if (x > y) begin
                swap_tmp = x;
                x = y;
                y = swap_tmp;
            end
            mid3_step1_pack = {x, y, z};
        end
    endfunction

    // Finish remaining two compare-swap steps and return median.
    function [DATA_W-1:0] mid3_finish_from_step1;
        input [DATA_W*3-1:0] step1_pack;
        reg [DATA_W-1:0] x;
        reg [DATA_W-1:0] y;
        reg [DATA_W-1:0] z;
        reg [DATA_W-1:0] swap_tmp;
        begin
            x = tap3(step1_pack, 0);
            y = tap3(step1_pack, 1);
            z = tap3(step1_pack, 2);
            if (y > z) begin
                swap_tmp = y;
                y = z;
                z = swap_tmp;
            end
            if (x > y) begin
                swap_tmp = x;
                x = y;
                y = swap_tmp;
            end
            mid3_finish_from_step1 = y;
        end
    endfunction

    function [DATA_W*9-1:0] sort_window_rows;
        input [DATA_W*9-1:0] window;
        reg [DATA_W*3-1:0] row0_sorted;
        reg [DATA_W*3-1:0] row1_sorted;
        reg [DATA_W*3-1:0] row2_sorted;
        begin
            row0_sorted = sort3_pack(tap9(window, 0), tap9(window, 1), tap9(window, 2));
            row1_sorted = sort3_pack(tap9(window, 3), tap9(window, 4), tap9(window, 5));
            row2_sorted = sort3_pack(tap9(window, 6), tap9(window, 7), tap9(window, 8));
            sort_window_rows = {row0_sorted, row1_sorted, row2_sorted};
        end
    endfunction

    // Complete sort3 after mid3_step1_pack by applying the remaining 2 compare-swaps.
    function [DATA_W*3-1:0] sort3_finish_pack_from_step1;
        input [DATA_W*3-1:0] step1_pack;
        reg [DATA_W-1:0] x;
        reg [DATA_W-1:0] y;
        reg [DATA_W-1:0] z;
        reg [DATA_W-1:0] swap_tmp;
        begin
            x = tap3(step1_pack, 0);
            y = tap3(step1_pack, 1);
            z = tap3(step1_pack, 2);
            if (y > z) begin
                swap_tmp = y;
                y = z;
                z = swap_tmp;
            end
            if (x > y) begin
                swap_tmp = x;
                x = y;
                y = swap_tmp;
            end
            sort3_finish_pack_from_step1 = {x, y, z};
        end
    endfunction

    // Stage-1a combinational transform: each row only does first compare-swap.
    function [DATA_W*9-1:0] sort_window_rows_step1;
        input [DATA_W*9-1:0] window;
        reg [DATA_W*3-1:0] row0_step1;
        reg [DATA_W*3-1:0] row1_step1;
        reg [DATA_W*3-1:0] row2_step1;
        begin
            row0_step1 = mid3_step1_pack(tap9(window, 0), tap9(window, 1), tap9(window, 2));
            row1_step1 = mid3_step1_pack(tap9(window, 3), tap9(window, 4), tap9(window, 5));
            row2_step1 = mid3_step1_pack(tap9(window, 6), tap9(window, 7), tap9(window, 8));
            sort_window_rows_step1 = {row0_step1, row1_step1, row2_step1};
        end
    endfunction

    // Stage-1 combinational transform: finish each row sort from step1 packs.
    function [DATA_W*9-1:0] sort_window_rows_finish;
        input [DATA_W*9-1:0] rows_step1;
        reg [DATA_W*3-1:0] row0_sorted;
        reg [DATA_W*3-1:0] row1_sorted;
        reg [DATA_W*3-1:0] row2_sorted;
        begin
            row0_sorted = sort3_finish_pack_from_step1(rows_step1[DATA_W*9-1 -: DATA_W*3]);
            row1_sorted = sort3_finish_pack_from_step1(rows_step1[DATA_W*6-1 -: DATA_W*3]);
            row2_sorted = sort3_finish_pack_from_step1(rows_step1[DATA_W*3-1:0]);
            sort_window_rows_finish = {row0_sorted, row1_sorted, row2_sorted};
        end
    endfunction

    // Output format: {max(row_min), mid_step1_pack, min(row_max)}.
    function [STG2_PACK_W-1:0] prep_candidates_step1;
        input [DATA_W*9-1:0] rowsort;
        reg [DATA_W-1:0] c0_max_of_min;
        reg [DATA_W*3-1:0] c1_mid_step1;
        reg [DATA_W-1:0] c2_min_of_max;
        begin
            c0_max_of_min = max3(tap9(rowsort, 0), tap9(rowsort, 3), tap9(rowsort, 6));
            c1_mid_step1  = mid3_step1_pack(tap9(rowsort, 1), tap9(rowsort, 4), tap9(rowsort, 7));
            c2_min_of_max = min3(tap9(rowsort, 2), tap9(rowsort, 5), tap9(rowsort, 8));
            prep_candidates_step1 = {c0_max_of_min, c1_mid_step1, c2_min_of_max};
        end
    endfunction

    // Input format: {max(row_min), mid_step1_pack, min(row_max)}.
    // Output format: {max(row_min), median(row_mid), min(row_max)}.
    function [DATA_W*3-1:0] finish_candidates;
        input [STG2_PACK_W-1:0] prep_pack;
        reg [DATA_W-1:0] c0_max_of_min;
        reg [DATA_W*3-1:0] c1_mid_step1;
        reg [DATA_W-1:0] c1_med_of_mid;
        reg [DATA_W-1:0] c2_min_of_max;
        begin
            c0_max_of_min = prep_pack[STG2_PACK_W-1 -: DATA_W];
            c1_mid_step1  = prep_pack[DATA_W*4-1:DATA_W];
            c2_min_of_max = prep_pack[DATA_W-1:0];
            c1_med_of_mid = mid3_finish_from_step1(c1_mid_step1);
            finish_candidates = {c0_max_of_min, c1_med_of_mid, c2_min_of_max};
        end
    endfunction

    function [DATA_W-1:0] median_from_candidates;
        input [DATA_W*3-1:0] candidates;
        reg [DATA_W*3-1:0] candidates_sorted;
        begin
            candidates_sorted = sort3_pack(tap3(candidates, 0), tap3(candidates, 1), tap3(candidates, 2));
            median_from_candidates = tap3(candidates_sorted, 1);
        end
    endfunction

    assign has_active_lane = |s_keep;
    assign out_ready  = (~m_valid) | m_ready;
    assign stg5_ready = (~stg5_valid) | out_ready;
    assign stg4_ready = (~stg4_valid) | stg5_ready;
    assign stg3_ready = (~stg3_valid) | stg4_ready;
    assign stg2_ready = (~stg2_valid) | stg3_ready;
    assign stg1_ready = (~stg1_valid) | stg2_ready;
    assign stg1a_ready = (~stg1a_valid) | stg1_ready;
    assign stg0_ready = (~stg0_valid) | stg1a_ready;
    assign s_ready    = stg0_ready;

    always @* begin
        stg1a_rows_step1_comb = {MAX_LANES*DATA_W*9{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg0_keep[lane_idx]) begin
                stg1a_rows_step1_comb[lane_idx*DATA_W*9 +: DATA_W*9] =
                    sort_window_rows_step1(stg0_data[lane_idx*DATA_W*9 +: DATA_W*9]);
            end
        end
    end

    always @* begin
        stg1_rowsort_comb = {MAX_LANES*DATA_W*9{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg1a_keep[lane_idx]) begin
                stg1_rowsort_comb[lane_idx*DATA_W*9 +: DATA_W*9] =
                    sort_window_rows_finish(stg1a_rows_step1[lane_idx*DATA_W*9 +: DATA_W*9]);
            end
        end
    end

    always @* begin
        stg2_prep_comb = {MAX_LANES*STG2_PACK_W{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg1_keep[lane_idx]) begin
                stg2_prep_comb[lane_idx*STG2_PACK_W +: STG2_PACK_W] =
                    prep_candidates_step1(stg1_rowsort[lane_idx*DATA_W*9 +: DATA_W*9]);
            end
        end
    end

    always @* begin
        stg3_candidates_comb = {MAX_LANES*DATA_W*3{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg2_keep[lane_idx]) begin
                stg3_candidates_comb[lane_idx*DATA_W*3 +: DATA_W*3] =
                    finish_candidates(stg2_prep[lane_idx*STG2_PACK_W +: STG2_PACK_W]);
            end
        end
    end

    always @* begin
        stg4_mid_step1_comb = {MAX_LANES*DATA_W*3{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg3_keep[lane_idx]) begin
                stg4_mid_step1_comb[lane_idx*DATA_W*3 +: DATA_W*3] =
                    mid3_step1_pack(
                        tap3(stg3_candidates[lane_idx*DATA_W*3 +: DATA_W*3], 0),
                        tap3(stg3_candidates[lane_idx*DATA_W*3 +: DATA_W*3], 1),
                        tap3(stg3_candidates[lane_idx*DATA_W*3 +: DATA_W*3], 2)
                    );
            end
        end
    end

    always @* begin
        stg5_median_comb = {MAX_LANES*DATA_W{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg4_keep[lane_idx]) begin
                stg5_median_comb[lane_idx*DATA_W +: DATA_W] =
                    mid3_finish_from_step1(stg4_mid_step1[lane_idx*DATA_W*3 +: DATA_W*3]);
            end
        end
    end

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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg1a_valid      <= 1'b0;
            stg1a_rows_step1 <= {MAX_LANES*DATA_W*9{1'b0}};
            stg1a_keep       <= {MAX_LANES{1'b0}};
            stg1a_sof        <= 1'b0;
            stg1a_eol        <= 1'b0;
            stg1a_eof        <= 1'b0;
        end else if (stg1a_ready) begin
            stg1a_valid <= stg0_valid;
            if (stg0_valid) begin
                stg1a_rows_step1 <= stg1a_rows_step1_comb;
                stg1a_keep       <= stg0_keep;
                stg1a_sof        <= stg0_sof;
                stg1a_eol        <= stg0_eol;
                stg1a_eof        <= stg0_eof;
            end else begin
                stg1a_rows_step1 <= {MAX_LANES*DATA_W*9{1'b0}};
                stg1a_keep       <= {MAX_LANES{1'b0}};
                stg1a_sof        <= 1'b0;
                stg1a_eol        <= 1'b0;
                stg1a_eof        <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg1_valid   <= 1'b0;
            stg1_rowsort <= {MAX_LANES*DATA_W*9{1'b0}};
            stg1_keep    <= {MAX_LANES{1'b0}};
            stg1_sof     <= 1'b0;
            stg1_eol     <= 1'b0;
            stg1_eof     <= 1'b0;
        end else if (stg1_ready) begin
            stg1_valid <= stg1a_valid;
            if (stg1a_valid) begin
                stg1_rowsort <= stg1_rowsort_comb;
                stg1_keep    <= stg1a_keep;
                stg1_sof     <= stg1a_sof;
                stg1_eol     <= stg1a_eol;
                stg1_eof     <= stg1a_eof;
            end else begin
                stg1_rowsort <= {MAX_LANES*DATA_W*9{1'b0}};
                stg1_keep    <= {MAX_LANES{1'b0}};
                stg1_sof     <= 1'b0;
                stg1_eol     <= 1'b0;
                stg1_eof     <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg2_valid <= 1'b0;
            stg2_prep  <= {MAX_LANES*STG2_PACK_W{1'b0}};
            stg2_keep  <= {MAX_LANES{1'b0}};
            stg2_sof   <= 1'b0;
            stg2_eol   <= 1'b0;
            stg2_eof   <= 1'b0;
        end else if (stg2_ready) begin
            stg2_valid <= stg1_valid;
            if (stg1_valid) begin
                stg2_prep <= stg2_prep_comb;
                stg2_keep <= stg1_keep;
                stg2_sof  <= stg1_sof;
                stg2_eol  <= stg1_eol;
                stg2_eof  <= stg1_eof;
            end else begin
                stg2_prep <= {MAX_LANES*STG2_PACK_W{1'b0}};
                stg2_keep <= {MAX_LANES{1'b0}};
                stg2_sof  <= 1'b0;
                stg2_eol  <= 1'b0;
                stg2_eof  <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg3_valid      <= 1'b0;
            stg3_candidates <= {MAX_LANES*DATA_W*3{1'b0}};
            stg3_keep       <= {MAX_LANES{1'b0}};
            stg3_sof        <= 1'b0;
            stg3_eol        <= 1'b0;
            stg3_eof        <= 1'b0;
        end else if (stg3_ready) begin
            stg3_valid <= stg2_valid;
            if (stg2_valid) begin
                stg3_candidates <= stg3_candidates_comb;
                stg3_keep       <= stg2_keep;
                stg3_sof        <= stg2_sof;
                stg3_eol        <= stg2_eol;
                stg3_eof        <= stg2_eof;
            end else begin
                stg3_candidates <= {MAX_LANES*DATA_W*3{1'b0}};
                stg3_keep       <= {MAX_LANES{1'b0}};
                stg3_sof        <= 1'b0;
                stg3_eol        <= 1'b0;
                stg3_eof        <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg4_valid  <= 1'b0;
            stg4_mid_step1 <= {MAX_LANES*DATA_W*3{1'b0}};
            stg4_keep   <= {MAX_LANES{1'b0}};
            stg4_sof    <= 1'b0;
            stg4_eol    <= 1'b0;
            stg4_eof    <= 1'b0;
        end else if (stg4_ready) begin
            stg4_valid <= stg3_valid;
            if (stg3_valid) begin
                stg4_mid_step1 <= stg4_mid_step1_comb;
                stg4_keep   <= stg3_keep;
                stg4_sof    <= stg3_sof;
                stg4_eol    <= stg3_eol;
                stg4_eof    <= stg3_eof;
            end else begin
                stg4_mid_step1 <= {MAX_LANES*DATA_W*3{1'b0}};
                stg4_keep   <= {MAX_LANES{1'b0}};
                stg4_sof    <= 1'b0;
                stg4_eol    <= 1'b0;
                stg4_eof    <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg5_valid  <= 1'b0;
            stg5_median <= {MAX_LANES*DATA_W{1'b0}};
            stg5_keep   <= {MAX_LANES{1'b0}};
            stg5_sof    <= 1'b0;
            stg5_eol    <= 1'b0;
            stg5_eof    <= 1'b0;
        end else if (stg5_ready) begin
            stg5_valid <= stg4_valid;
            if (stg4_valid) begin
                stg5_median <= stg5_median_comb;
                stg5_keep   <= stg4_keep;
                stg5_sof    <= stg4_sof;
                stg5_eol    <= stg4_eol;
                stg5_eof    <= stg4_eof;
            end else begin
                stg5_median <= {MAX_LANES*DATA_W{1'b0}};
                stg5_keep   <= {MAX_LANES{1'b0}};
                stg5_sof    <= 1'b0;
                stg5_eol    <= 1'b0;
                stg5_eof    <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= {MAX_LANES*DATA_W{1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else if (out_ready) begin
            m_valid <= stg5_valid;
            if (stg5_valid) begin
                m_data <= stg5_median;
                m_keep <= stg5_keep;
                m_sof  <= stg5_sof;
                m_eol  <= stg5_eol;
                m_eof  <= stg5_eof;
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
