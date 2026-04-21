`timescale 1ns / 1ps

module sobel3x3_stream_std #(
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

    localparam integer ABS_W = DATA_W + 3;

    integer lane_idx;

    wire has_active_lane;
    wire out_ready;
    wire stg2_ready;
    wire stg1_ready;
    wire stg0_ready;

    reg                             stg0_valid;
    reg  [MAX_LANES*DATA_W*9-1:0]   stg0_data;
    reg  [MAX_LANES-1:0]            stg0_keep;
    reg                             stg0_sof;
    reg                             stg0_eol;
    reg                             stg0_eof;

    reg                             stg1_valid;
    reg  [MAX_LANES*ABS_W*2-1:0]    stg1_grad_pair;
    reg  [MAX_LANES-1:0]            stg1_keep;
    reg                             stg1_sof;
    reg                             stg1_eol;
    reg                             stg1_eof;

    reg                             stg2_valid;
    reg  [MAX_LANES*ABS_W*2-1:0]    stg2_abs_pair;
    reg  [MAX_LANES-1:0]            stg2_keep;
    reg                             stg2_sof;
    reg                             stg2_eol;
    reg                             stg2_eof;

    reg  [MAX_LANES*ABS_W*2-1:0]    stg1_grad_pair_comb;
    reg  [MAX_LANES*ABS_W*2-1:0]    stg2_abs_pair_comb;

    function [DATA_W-1:0] tap9;
        input [DATA_W*9-1:0] window;
        input integer tap_idx;
        begin
            tap9 = window[(8-tap_idx)*DATA_W +: DATA_W];
        end
    endfunction

    // Output format: {gx_signed, gy_signed}, each ABS_W bits signed.
    function [ABS_W*2-1:0] sobel_grad_pair;
        input [DATA_W*9-1:0] window;
        reg [DATA_W-1:0] p0;
        reg [DATA_W-1:0] p1;
        reg [DATA_W-1:0] p2;
        reg [DATA_W-1:0] p3;
        reg [DATA_W-1:0] p5;
        reg [DATA_W-1:0] p6;
        reg [DATA_W-1:0] p7;
        reg [DATA_W-1:0] p8;
        reg signed [ABS_W:0] gx_pos;
        reg signed [ABS_W:0] gx_neg;
        reg signed [ABS_W:0] gy_pos;
        reg signed [ABS_W:0] gy_neg;
        reg signed [ABS_W:0] gx;
        reg signed [ABS_W:0] gy;
        begin
            p0 = tap9(window, 0);
            p1 = tap9(window, 1);
            p2 = tap9(window, 2);
            p3 = tap9(window, 3);
            p5 = tap9(window, 5);
            p6 = tap9(window, 6);
            p7 = tap9(window, 7);
            p8 = tap9(window, 8);

            gx_pos = $signed({1'b0, p2}) + $signed({p5, 1'b0}) + $signed({1'b0, p8});
            gx_neg = $signed({1'b0, p0}) + $signed({p3, 1'b0}) + $signed({1'b0, p6});
            gy_pos = $signed({1'b0, p0}) + $signed({p1, 1'b0}) + $signed({1'b0, p2});
            gy_neg = $signed({1'b0, p6}) + $signed({p7, 1'b0}) + $signed({1'b0, p8});

            gx = gx_pos - gx_neg;
            gy = gy_pos - gy_neg;
            sobel_grad_pair = {gx[ABS_W-1:0], gy[ABS_W-1:0]};
        end
    endfunction

    // Input format: {gx_signed, gy_signed}. Output format: {abs_gx, abs_gy}.
    function [ABS_W*2-1:0] grad_to_abs_pair;
        input [ABS_W*2-1:0] grad_pair;
        reg signed [ABS_W-1:0] gx;
        reg signed [ABS_W-1:0] gy;
        reg [ABS_W-1:0] abs_gx;
        reg [ABS_W-1:0] abs_gy;
        begin
            gx = $signed(grad_pair[ABS_W*2-1:ABS_W]);
            gy = $signed(grad_pair[ABS_W-1:0]);
            abs_gx = gx[ABS_W-1] ? (~gx + 1'b1) : gx;
            abs_gy = gy[ABS_W-1] ? (~gy + 1'b1) : gy;
            grad_to_abs_pair = {abs_gx[ABS_W-1:0], abs_gy[ABS_W-1:0]};
        end
    endfunction

    function [DATA_W-1:0] sobel_clip_from_pair;
        input [ABS_W*2-1:0] abs_pair;
        reg [ABS_W:0] magnitude;
        reg [ABS_W:0] max_value;
        begin
            magnitude = abs_pair[ABS_W*2-1:ABS_W] + abs_pair[ABS_W-1:0];
            max_value = ({{ABS_W{1'b0}}, 1'b1} << DATA_W) - 1'b1;
            if (magnitude > max_value) begin
                sobel_clip_from_pair = {DATA_W{1'b1}};
            end else begin
                sobel_clip_from_pair = magnitude[DATA_W-1:0];
            end
        end
    endfunction

    assign has_active_lane = |s_keep;
    assign out_ready  = (~m_valid) | m_ready;
    assign stg2_ready = (~stg2_valid) | out_ready;
    assign stg1_ready = (~stg1_valid) | stg2_ready;
    assign stg0_ready = (~stg0_valid) | stg1_ready;
    assign s_ready    = stg0_ready;

    always @* begin
        stg1_grad_pair_comb = {MAX_LANES*ABS_W*2{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg0_keep[lane_idx]) begin
                stg1_grad_pair_comb[lane_idx*ABS_W*2 +: ABS_W*2] =
                    sobel_grad_pair(stg0_data[lane_idx*DATA_W*9 +: DATA_W*9]);
            end
        end
    end

    always @* begin
        stg2_abs_pair_comb = {MAX_LANES*ABS_W*2{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg1_keep[lane_idx]) begin
                stg2_abs_pair_comb[lane_idx*ABS_W*2 +: ABS_W*2] =
                    grad_to_abs_pair(stg1_grad_pair[lane_idx*ABS_W*2 +: ABS_W*2]);
            end
        end
    end

    // Stage 0: input latch.
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

    // Stage 1: gradient stage.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg1_valid     <= 1'b0;
            stg1_grad_pair <= {MAX_LANES*ABS_W*2{1'b0}};
            stg1_keep      <= {MAX_LANES{1'b0}};
            stg1_sof       <= 1'b0;
            stg1_eol       <= 1'b0;
            stg1_eof       <= 1'b0;
        end else if (stg1_ready) begin
            stg1_valid <= stg0_valid;
            if (stg0_valid) begin
                stg1_grad_pair <= stg1_grad_pair_comb;
                stg1_keep      <= stg0_keep;
                stg1_sof       <= stg0_sof;
                stg1_eol       <= stg0_eol;
                stg1_eof       <= stg0_eof;
            end else begin
                stg1_grad_pair <= {MAX_LANES*ABS_W*2{1'b0}};
                stg1_keep      <= {MAX_LANES{1'b0}};
                stg1_sof       <= 1'b0;
                stg1_eol       <= 1'b0;
                stg1_eof       <= 1'b0;
            end
        end
    end

    // Stage 2: absolute stage.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg2_valid    <= 1'b0;
            stg2_abs_pair <= {MAX_LANES*ABS_W*2{1'b0}};
            stg2_keep     <= {MAX_LANES{1'b0}};
            stg2_sof      <= 1'b0;
            stg2_eol      <= 1'b0;
            stg2_eof      <= 1'b0;
        end else if (stg2_ready) begin
            stg2_valid <= stg1_valid;
            if (stg1_valid) begin
                stg2_abs_pair <= stg2_abs_pair_comb;
                stg2_keep     <= stg1_keep;
                stg2_sof      <= stg1_sof;
                stg2_eol      <= stg1_eol;
                stg2_eof      <= stg1_eof;
            end else begin
                stg2_abs_pair <= {MAX_LANES*ABS_W*2{1'b0}};
                stg2_keep     <= {MAX_LANES{1'b0}};
                stg2_sof      <= 1'b0;
                stg2_eol      <= 1'b0;
                stg2_eof      <= 1'b0;
            end
        end
    end

    // Output stage: clip.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= {MAX_LANES*DATA_W{1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else if (out_ready) begin
            m_valid <= stg2_valid;
            if (stg2_valid) begin
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    if (stg2_keep[lane_idx]) begin
                        m_data[lane_idx*DATA_W +: DATA_W] <=
                            sobel_clip_from_pair(stg2_abs_pair[lane_idx*ABS_W*2 +: ABS_W*2]);
                    end else begin
                        m_data[lane_idx*DATA_W +: DATA_W] <= {DATA_W{1'b0}};
                    end
                end
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
