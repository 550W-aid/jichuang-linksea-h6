`timescale 1ns / 1ps

// Compute a Sobel edge-magnitude approximation from a valid 3x3 grayscale
// window. The datapath is split into three pipeline stages so the block can
// run at the delivery clock instead of forcing the whole gradient chain into
// one cycle.
module sobel3x3_stream_std #(
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

    localparam integer SUM_W = DATA_W + 2;

    integer lane_idx;

    wire has_active_lane;
    wire stg3_ready;
    wire stg2_ready;
    wire stg1_ready;

    // Stage 1 stores the positive and negative weighted sums for each axis.
    reg                         stg1_valid;
    reg  [MAX_LANES*SUM_W-1:0]  stg1_gx_pos;
    reg  [MAX_LANES*SUM_W-1:0]  stg1_gx_neg;
    reg  [MAX_LANES*SUM_W-1:0]  stg1_gy_pos;
    reg  [MAX_LANES*SUM_W-1:0]  stg1_gy_neg;
    reg  [MAX_LANES-1:0]        stg1_keep;
    reg                         stg1_sof;
    reg                         stg1_eol;
    reg                         stg1_eof;

    // Stage 2 stores absolute horizontal and vertical magnitudes.
    reg                         stg2_valid;
    reg  [MAX_LANES*SUM_W-1:0]  stg2_gx_abs;
    reg  [MAX_LANES*SUM_W-1:0]  stg2_gy_abs;
    reg  [MAX_LANES-1:0]        stg2_keep;
    reg                         stg2_sof;
    reg                         stg2_eol;
    reg                         stg2_eof;

    // Combinational next data for stage 1.
    reg [MAX_LANES*SUM_W-1:0] stg1_gx_pos_comb;
    reg [MAX_LANES*SUM_W-1:0] stg1_gx_neg_comb;
    reg [MAX_LANES*SUM_W-1:0] stg1_gy_pos_comb;
    reg [MAX_LANES*SUM_W-1:0] stg1_gy_neg_comb;

    // Combinational next data for stage 2.
    reg [MAX_LANES*SUM_W-1:0] stg2_gx_abs_comb;
    reg [MAX_LANES*SUM_W-1:0] stg2_gy_abs_comb;

    // Combinational final magnitude before the output register.
    reg [MAX_LANES*DATA_W-1:0] stg3_mag_comb;

    // Fetch one pixel from the packed 3x3 window.
    function [DATA_W-1:0] tap9;
        input [DATA_W*9-1:0] window;
        input integer        tap_idx;
        begin
            tap9 = window[(8-tap_idx)*DATA_W +: DATA_W];
        end
    endfunction

    // Compute a weighted three-tap sum with a {1,2,1} style pattern.
    function [SUM_W-1:0] weighted_sum3;
        input [DATA_W-1:0] a;
        input [DATA_W-1:0] b;
        input [DATA_W-1:0] c;
        begin
            weighted_sum3 = a + ({1'b0, b, 1'b0}) + c;
        end
    endfunction

    // Compute the absolute difference between two unsigned sums.
    function [SUM_W-1:0] abs_diff_unsigned;
        input [SUM_W-1:0] a;
        input [SUM_W-1:0] b;
        begin
            if (a >= b) begin
                abs_diff_unsigned = a - b;
            end else begin
                abs_diff_unsigned = b - a;
            end
        end
    endfunction

    // Saturate the Sobel magnitude to the output pixel width.
    function [DATA_W-1:0] saturate_magnitude;
        input [SUM_W:0] magnitude;
        reg   [SUM_W:0] max_value;
        begin
            max_value = (1 << DATA_W) - 1;
            if (magnitude > max_value) begin
                saturate_magnitude = {DATA_W{1'b1}};
            end else begin
                saturate_magnitude = magnitude[DATA_W-1:0];
            end
        end
    endfunction

    assign has_active_lane = |s_keep;
    assign stg3_ready = (~m_valid) | m_ready;
    assign stg2_ready = (~stg2_valid) | stg3_ready;
    assign stg1_ready = (~stg1_valid) | stg2_ready;
    assign s_ready    = stg1_ready;

    // Stage 1 computes the positive and negative Sobel sums separately.
    always @* begin
        stg1_gx_pos_comb = {MAX_LANES*SUM_W{1'b0}};
        stg1_gx_neg_comb = {MAX_LANES*SUM_W{1'b0}};
        stg1_gy_pos_comb = {MAX_LANES*SUM_W{1'b0}};
        stg1_gy_neg_comb = {MAX_LANES*SUM_W{1'b0}};

        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (s_keep[lane_idx]) begin
                stg1_gx_pos_comb[lane_idx*SUM_W +: SUM_W] = weighted_sum3(
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 2),
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 5),
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 8)
                );
                stg1_gx_neg_comb[lane_idx*SUM_W +: SUM_W] = weighted_sum3(
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 0),
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 3),
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 6)
                );
                stg1_gy_pos_comb[lane_idx*SUM_W +: SUM_W] = weighted_sum3(
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 0),
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 1),
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 2)
                );
                stg1_gy_neg_comb[lane_idx*SUM_W +: SUM_W] = weighted_sum3(
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 6),
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 7),
                    tap9(s_data[lane_idx*DATA_W*9 +: DATA_W*9], 8)
                );
            end
        end
    end

    // Stage 2 converts the directional sums into absolute axis magnitudes.
    always @* begin
        stg2_gx_abs_comb = {MAX_LANES*SUM_W{1'b0}};
        stg2_gy_abs_comb = {MAX_LANES*SUM_W{1'b0}};

        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg1_keep[lane_idx]) begin
                stg2_gx_abs_comb[lane_idx*SUM_W +: SUM_W] = abs_diff_unsigned(
                    stg1_gx_pos[lane_idx*SUM_W +: SUM_W],
                    stg1_gx_neg[lane_idx*SUM_W +: SUM_W]
                );
                stg2_gy_abs_comb[lane_idx*SUM_W +: SUM_W] = abs_diff_unsigned(
                    stg1_gy_pos[lane_idx*SUM_W +: SUM_W],
                    stg1_gy_neg[lane_idx*SUM_W +: SUM_W]
                );
            end
        end
    end

    // Stage 3 adds the magnitudes and applies output saturation.
    always @* begin
        stg3_mag_comb = {MAX_LANES*DATA_W{1'b0}};

        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg2_keep[lane_idx]) begin
                stg3_mag_comb[lane_idx*DATA_W +: DATA_W] = saturate_magnitude(
                    stg2_gx_abs[lane_idx*SUM_W +: SUM_W] +
                    stg2_gy_abs[lane_idx*SUM_W +: SUM_W]
                );
            end
        end
    end

    // Stage 1 register.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg1_valid  <= 1'b0;
            stg1_gx_pos <= {MAX_LANES*SUM_W{1'b0}};
            stg1_gx_neg <= {MAX_LANES*SUM_W{1'b0}};
            stg1_gy_pos <= {MAX_LANES*SUM_W{1'b0}};
            stg1_gy_neg <= {MAX_LANES*SUM_W{1'b0}};
            stg1_keep   <= {MAX_LANES{1'b0}};
            stg1_sof    <= 1'b0;
            stg1_eol    <= 1'b0;
            stg1_eof    <= 1'b0;
        end else if (stg1_ready) begin
            stg1_valid <= s_valid && has_active_lane;
            if (s_valid && has_active_lane) begin
                stg1_gx_pos <= stg1_gx_pos_comb;
                stg1_gx_neg <= stg1_gx_neg_comb;
                stg1_gy_pos <= stg1_gy_pos_comb;
                stg1_gy_neg <= stg1_gy_neg_comb;
                stg1_keep   <= s_keep;
                stg1_sof    <= s_sof;
                stg1_eol    <= s_eol;
                stg1_eof    <= s_eof;
            end else begin
                stg1_gx_pos <= {MAX_LANES*SUM_W{1'b0}};
                stg1_gx_neg <= {MAX_LANES*SUM_W{1'b0}};
                stg1_gy_pos <= {MAX_LANES*SUM_W{1'b0}};
                stg1_gy_neg <= {MAX_LANES*SUM_W{1'b0}};
                stg1_keep   <= {MAX_LANES{1'b0}};
                stg1_sof    <= 1'b0;
                stg1_eol    <= 1'b0;
                stg1_eof    <= 1'b0;
            end
        end
    end

    // Stage 2 register.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg2_valid  <= 1'b0;
            stg2_gx_abs <= {MAX_LANES*SUM_W{1'b0}};
            stg2_gy_abs <= {MAX_LANES*SUM_W{1'b0}};
            stg2_keep   <= {MAX_LANES{1'b0}};
            stg2_sof    <= 1'b0;
            stg2_eol    <= 1'b0;
            stg2_eof    <= 1'b0;
        end else if (stg2_ready) begin
            stg2_valid <= stg1_valid;
            if (stg1_valid) begin
                stg2_gx_abs <= stg2_gx_abs_comb;
                stg2_gy_abs <= stg2_gy_abs_comb;
                stg2_keep   <= stg1_keep;
                stg2_sof    <= stg1_sof;
                stg2_eol    <= stg1_eol;
                stg2_eof    <= stg1_eof;
            end else begin
                stg2_gx_abs <= {MAX_LANES*SUM_W{1'b0}};
                stg2_gy_abs <= {MAX_LANES*SUM_W{1'b0}};
                stg2_keep   <= {MAX_LANES{1'b0}};
                stg2_sof    <= 1'b0;
                stg2_eol    <= 1'b0;
                stg2_eof    <= 1'b0;
            end
        end
    end

    // Output register.
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
                m_data <= stg3_mag_comb;
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
