`timescale 1ns / 1ps

module digit_template_match_slot_core #(
    parameter integer ROI_W         = 64,
    parameter integer ROI_H         = 64,
    parameter integer SAMPLE_STRIDE = 4,
    parameter [8:0]   MIN_FG_PIX    = 9'd8
) (
    input  wire        clk,             // Processing clock.
    input  wire        rst_n,           // Active-low reset.
    input  wire        i_feat_accept,   // Feature beat valid.
    input  wire [11:0] i_pix_x,         // Feature-aligned pixel x coordinate.
    input  wire [11:0] i_pix_y,         // Feature-aligned pixel y coordinate.
    input  wire        i_sof,           // Feature start-of-frame.
    input  wire        i_eof,           // Feature end-of-frame.
    input  wire        i_pix_fg,        // Foreground flag after threshold.
    input  wire        i_roi_enable,    // Current slot ROI enabled for matching.
    input  wire [11:0] i_roi_x,         // Current slot ROI left x.
    input  wire [11:0] i_roi_y,         // Current slot ROI top y.
    output reg         o_digit_valid,   // One-cycle pulse when slot digit is ready.
    output reg         o_digit_present, // Slot has enough foreground samples.
    output reg  [3:0]  o_digit_id,      // Slot recognized digit id.
    output reg  [7:0]  o_digit_score    // Slot matching score.
);

    localparam integer GRID_W = ROI_W / SAMPLE_STRIDE;

    // 16x16 seven-segment-like templates, row-major, bit=1 means foreground (dark digit).
    localparam [255:0] TEMPLATE_0 = 256'h00001ff81ff860066006600660060000000060066006600660061ff81ff80000;
    localparam [255:0] TEMPLATE_1 = 256'h0000000000000006000600060006000000000006000600060006000000000000;
    localparam [255:0] TEMPLATE_2 = 256'h00001ff81ff800060006000600061ff81ff860006000600060001ff81ff80000;
    localparam [255:0] TEMPLATE_3 = 256'h00001ff81ff800060006000600061ff81ff800060006000600061ff81ff80000;
    localparam [255:0] TEMPLATE_4 = 256'h00000000000060066006600660061ff81ff80006000600060006000000000000;
    localparam [255:0] TEMPLATE_5 = 256'h00001ff81ff860006000600060001ff81ff800060006000600061ff81ff80000;
    localparam [255:0] TEMPLATE_6 = 256'h00001ff81ff860006000600060001ff81ff860066006600660061ff81ff80000;
    localparam [255:0] TEMPLATE_7 = 256'h00001ff81ff80006000600060006000000000006000600060006000000000000;
    localparam [255:0] TEMPLATE_8 = 256'h00001ff81ff860066006600660061ff81ff860066006600660061ff81ff80000;
    localparam [255:0] TEMPLATE_9 = 256'h00001ff81ff860066006600660061ff81ff800060006000600061ff81ff80000;

    reg [8:0] sample_fg_cnt;           // Foreground sampled points count in current frame.
    reg [8:0] match_cnt_0;             // Current-frame overlap count for digit 0.
    reg [8:0] match_cnt_1;             // Current-frame overlap count for digit 1.
    reg [8:0] match_cnt_2;             // Current-frame overlap count for digit 2.
    reg [8:0] match_cnt_3;             // Current-frame overlap count for digit 3.
    reg [8:0] match_cnt_4;             // Current-frame overlap count for digit 4.
    reg [8:0] match_cnt_5;             // Current-frame overlap count for digit 5.
    reg [8:0] match_cnt_6;             // Current-frame overlap count for digit 6.
    reg [8:0] match_cnt_7;             // Current-frame overlap count for digit 7.
    reg [8:0] match_cnt_8;             // Current-frame overlap count for digit 8.
    reg [8:0] match_cnt_9;             // Current-frame overlap count for digit 9.
    reg       frame_done_pending;      // Frame-end event latch.
    reg       eval_active;             // Evaluator active flag.
    reg       eval_phase;              // Evaluator phase: 0=prepare candidate, 1=compare/update.
    reg [3:0] eval_idx;                // Compare index (0..8 => compare 1..9).
    reg [3:0] best_digit_reg;          // Running best digit.
    reg [8:0] best_match_reg;          // Running best match count.
    reg signed [10:0] best_metric_reg; // Running best metric.
    reg [3:0] cand_digit_reg;          // Candidate digit in current compare phase.
    reg [8:0] cand_match_reg;          // Candidate match count.
    reg signed [10:0] cand_metric_reg; // Candidate metric.

    wire roi_x_hit = (i_pix_x >= i_roi_x) && (i_pix_x < i_roi_x + ROI_W);
    wire roi_y_hit = (i_pix_y >= i_roi_y) && (i_pix_y < i_roi_y + ROI_H);
    wire roi_hit = i_roi_enable && roi_x_hit && roi_y_hit;

    wire [11:0] roi_x_rel = i_pix_x - i_roi_x;
    wire [11:0] roi_y_rel = i_pix_y - i_roi_y;
    wire stride_x_hit = (roi_x_rel % SAMPLE_STRIDE) == (SAMPLE_STRIDE / 2);
    wire stride_y_hit = (roi_y_rel % SAMPLE_STRIDE) == (SAMPLE_STRIDE / 2);
    wire sample_hit = roi_hit && stride_x_hit && stride_y_hit;
    wire [7:0] sample_gx = roi_x_rel / SAMPLE_STRIDE;
    wire [7:0] sample_gy = roi_y_rel / SAMPLE_STRIDE;
    wire [7:0] sample_idx = (sample_gy * GRID_W[7:0]) + sample_gx;

    wire cand_better_w = (cand_metric_reg >= best_metric_reg);
    wire [3:0] best_digit_sel_w = cand_better_w ? cand_digit_reg : best_digit_reg;
    wire [8:0] best_match_sel_w = cand_better_w ? cand_match_reg : best_match_reg;
    wire signed [10:0] best_metric_sel_w = cand_better_w ? cand_metric_reg : best_metric_reg;

    function template_bit;
        input [3:0] digit;
        input [7:0] idx;
        begin
            case (digit)
                4'd0: template_bit = TEMPLATE_0[8'd255 - idx];
                4'd1: template_bit = TEMPLATE_1[8'd255 - idx];
                4'd2: template_bit = TEMPLATE_2[8'd255 - idx];
                4'd3: template_bit = TEMPLATE_3[8'd255 - idx];
                4'd4: template_bit = TEMPLATE_4[8'd255 - idx];
                4'd5: template_bit = TEMPLATE_5[8'd255 - idx];
                4'd6: template_bit = TEMPLATE_6[8'd255 - idx];
                4'd7: template_bit = TEMPLATE_7[8'd255 - idx];
                4'd8: template_bit = TEMPLATE_8[8'd255 - idx];
                default: template_bit = TEMPLATE_9[8'd255 - idx];
            endcase
        end
    endfunction

    function [8:0] match_for_digit;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: match_for_digit = match_cnt_0;
                4'd1: match_for_digit = match_cnt_1;
                4'd2: match_for_digit = match_cnt_2;
                4'd3: match_for_digit = match_cnt_3;
                4'd4: match_for_digit = match_cnt_4;
                4'd5: match_for_digit = match_cnt_5;
                4'd6: match_for_digit = match_cnt_6;
                4'd7: match_for_digit = match_cnt_7;
                4'd8: match_for_digit = match_cnt_8;
                default: match_for_digit = match_cnt_9;
            endcase
        end
    endfunction

    function [7:0] ones_for_digit;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: ones_for_digit = 8'd72;
                4'd1: ones_for_digit = 8'd16;
                4'd2: ones_for_digit = 8'd76;
                4'd3: ones_for_digit = 8'd76;
                4'd4: ones_for_digit = 8'd44;
                4'd5: ones_for_digit = 8'd76;
                4'd6: ones_for_digit = 8'd84;
                4'd7: ones_for_digit = 8'd36;
                4'd8: ones_for_digit = 8'd92;
                default: ones_for_digit = 8'd84;
            endcase
        end
    endfunction

    function signed [10:0] metric_from;
        input [8:0] match_cnt_in;
        input [7:0] ones_cnt;
        begin
            metric_from = $signed({1'b0, match_cnt_in, 1'b0}) - $signed({3'd0, ones_cnt});
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_fg_cnt <= 9'd0;
            match_cnt_0 <= 9'd0;
            match_cnt_1 <= 9'd0;
            match_cnt_2 <= 9'd0;
            match_cnt_3 <= 9'd0;
            match_cnt_4 <= 9'd0;
            match_cnt_5 <= 9'd0;
            match_cnt_6 <= 9'd0;
            match_cnt_7 <= 9'd0;
            match_cnt_8 <= 9'd0;
            match_cnt_9 <= 9'd0;
            frame_done_pending <= 1'b0;
            eval_active <= 1'b0;
            eval_phase <= 1'b0;
            eval_idx <= 4'd0;
            best_digit_reg <= 4'd0;
            best_match_reg <= 9'd0;
            best_metric_reg <= 11'sd0;
            cand_digit_reg <= 4'd0;
            cand_match_reg <= 9'd0;
            cand_metric_reg <= 11'sd0;
            o_digit_valid <= 1'b0;
            o_digit_present <= 1'b0;
            o_digit_id <= 4'hF;
            o_digit_score <= 8'd0;
        end else begin
            o_digit_valid <= 1'b0;

            if (frame_done_pending && !eval_active) begin
                frame_done_pending <= 1'b0;
                eval_active <= 1'b1;
                eval_phase <= 1'b0;
                eval_idx <= 4'd0;
                best_digit_reg <= 4'd0;
                best_match_reg <= match_cnt_0;
                best_metric_reg <= metric_from(match_cnt_0, 8'd72);
            end

            if (eval_active) begin
                if (!eval_phase) begin
                    cand_digit_reg <= eval_idx + 4'd1;
                    cand_match_reg <= match_for_digit(eval_idx + 4'd1);
                    cand_metric_reg <= metric_from(match_for_digit(eval_idx + 4'd1),
                                                   ones_for_digit(eval_idx + 4'd1));
                    eval_phase <= 1'b1;
                end else begin
                    best_digit_reg <= best_digit_sel_w;
                    best_match_reg <= best_match_sel_w;
                    best_metric_reg <= best_metric_sel_w;

                    if (eval_idx == 4'd8) begin
                        eval_active <= 1'b0;
                        eval_phase <= 1'b0;
                        o_digit_valid <= 1'b1;
                        if (i_roi_enable && (sample_fg_cnt >= MIN_FG_PIX)) begin
                            o_digit_present <= 1'b1;
                            o_digit_id <= best_digit_sel_w;
                            o_digit_score <= best_match_sel_w[8] ? 8'hFF : best_match_sel_w[7:0];
                        end else begin
                            o_digit_present <= 1'b0;
                            o_digit_id <= 4'hF;
                            o_digit_score <= 8'd0;
                        end
                    end else begin
                        eval_idx <= eval_idx + 1'b1;
                        eval_phase <= 1'b0;
                    end
                end
            end

            if (i_feat_accept && i_sof) begin
                sample_fg_cnt <= 9'd0;
                match_cnt_0 <= 9'd0;
                match_cnt_1 <= 9'd0;
                match_cnt_2 <= 9'd0;
                match_cnt_3 <= 9'd0;
                match_cnt_4 <= 9'd0;
                match_cnt_5 <= 9'd0;
                match_cnt_6 <= 9'd0;
                match_cnt_7 <= 9'd0;
                match_cnt_8 <= 9'd0;
                match_cnt_9 <= 9'd0;
            end

            if (i_feat_accept && sample_hit) begin
                if (i_pix_fg) begin
                    sample_fg_cnt <= sample_fg_cnt + 1'b1;
                end
                if (i_pix_fg && template_bit(4'd0, sample_idx)) match_cnt_0 <= match_cnt_0 + 1'b1;
                if (i_pix_fg && template_bit(4'd1, sample_idx)) match_cnt_1 <= match_cnt_1 + 1'b1;
                if (i_pix_fg && template_bit(4'd2, sample_idx)) match_cnt_2 <= match_cnt_2 + 1'b1;
                if (i_pix_fg && template_bit(4'd3, sample_idx)) match_cnt_3 <= match_cnt_3 + 1'b1;
                if (i_pix_fg && template_bit(4'd4, sample_idx)) match_cnt_4 <= match_cnt_4 + 1'b1;
                if (i_pix_fg && template_bit(4'd5, sample_idx)) match_cnt_5 <= match_cnt_5 + 1'b1;
                if (i_pix_fg && template_bit(4'd6, sample_idx)) match_cnt_6 <= match_cnt_6 + 1'b1;
                if (i_pix_fg && template_bit(4'd7, sample_idx)) match_cnt_7 <= match_cnt_7 + 1'b1;
                if (i_pix_fg && template_bit(4'd8, sample_idx)) match_cnt_8 <= match_cnt_8 + 1'b1;
                if (i_pix_fg && template_bit(4'd9, sample_idx)) match_cnt_9 <= match_cnt_9 + 1'b1;
            end

            if (i_feat_accept && i_eof) begin
                frame_done_pending <= 1'b1;
            end
        end
    end

endmodule
