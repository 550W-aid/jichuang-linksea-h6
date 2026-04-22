`timescale 1ns / 1ps

module digit_template_match_stream_std #(
    parameter integer FRAME_WIDTH   = 640,
    parameter integer FRAME_HEIGHT  = 480,
    parameter integer ROI_X         = 288,
    parameter integer ROI_Y         = 208,
    parameter integer ROI_W         = 64,
    parameter integer ROI_H         = 64,
    parameter integer SAMPLE_STRIDE = 4,
    parameter [7:0]   THRESHOLD     = 8'd96
) (
    input  wire        clk,            // Processing clock.
    input  wire        rst_n,          // Active-low reset.
    input  wire        s_valid,        // Input beat valid.
    output wire        s_ready,        // Input beat ready.
    input  wire [23:0] s_data,         // Input RGB888 pixel.
    input  wire        s_keep,         // Input lane keep.
    input  wire        s_sof,          // Input start-of-frame.
    input  wire        s_eol,          // Input end-of-line.
    input  wire        s_eof,          // Input end-of-frame.
    output wire        m_valid,        // Output beat valid (passthrough).
    input  wire        m_ready,        // Output beat ready (passthrough).
    output wire [23:0] m_data,         // Output RGB888 pixel (passthrough).
    output wire        m_keep,         // Output keep (passthrough).
    output wire        m_sof,          // Output SOF (passthrough).
    output wire        m_eol,          // Output EOL (passthrough).
    output wire        m_eof,          // Output EOF (passthrough).
    output reg         o_digit_valid,  // One-cycle pulse when frame digit is ready.
    output reg  [3:0]  o_digit_id,     // Recognized digit ID (0~9).
    output reg  [7:0]  o_digit_score   // Matching score (0~255).
);

    localparam integer GRID_W = ROI_W / SAMPLE_STRIDE;
    localparam integer GRID_H = ROI_H / SAMPLE_STRIDE;
    localparam integer GRID_N = GRID_W * GRID_H;

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

    reg  [11:0] x_cnt;                 // Internal stream x counter.
    reg  [11:0] y_cnt;                 // Internal stream y counter.
    reg  [8:0]  sample_count;          // Number of sampled points in current frame.
    reg  [8:0]  match_cnt_0;           // Current-frame foreground intersection count for digit 0.
    reg  [8:0]  match_cnt_1;           // Current-frame foreground intersection count for digit 1.
    reg  [8:0]  match_cnt_2;           // Current-frame foreground intersection count for digit 2.
    reg  [8:0]  match_cnt_3;           // Current-frame foreground intersection count for digit 3.
    reg  [8:0]  match_cnt_4;           // Current-frame foreground intersection count for digit 4.
    reg  [8:0]  match_cnt_5;           // Current-frame foreground intersection count for digit 5.
    reg  [8:0]  match_cnt_6;           // Current-frame foreground intersection count for digit 6.
    reg  [8:0]  match_cnt_7;           // Current-frame foreground intersection count for digit 7.
    reg  [8:0]  match_cnt_8;           // Current-frame foreground intersection count for digit 8.
    reg  [8:0]  match_cnt_9;           // Current-frame foreground intersection count for digit 9.
    reg         frame_done_pending;    // Latch frame-end event and start sequential class scan.
    reg         eval_active;           // Class scan active flag.
    reg  [3:0]  eval_idx;              // Class scan index (0..8 => compare digit 1..9).
    reg  [3:0]  best_digit_reg;        // Running best digit during class scan.
    reg  [8:0]  best_match_reg;        // Running best match count during class scan.
    reg signed [10:0] best_metric_reg; // Running best metric during class scan.

    wire accept = s_valid && s_ready && s_keep;
    wire [11:0] pix_x = s_sof ? 12'd0 : x_cnt;
    wire [11:0] pix_y = s_sof ? 12'd0 : y_cnt;

    wire [7:0] pix_r = s_data[23:16];
    wire [7:0] pix_g = s_data[15:8];
    wire [7:0] pix_b = s_data[7:0];
    wire [15:0] gray_mul = (pix_r * 8'd77) + (pix_g * 8'd150) + (pix_b * 8'd29);
    wire [7:0] gray_u8 = gray_mul[15:8];
    wire pix_fg = (gray_u8 < THRESHOLD);

    wire roi_x_hit = (pix_x >= ROI_X) && (pix_x < ROI_X + ROI_W);
    wire roi_y_hit = (pix_y >= ROI_Y) && (pix_y < ROI_Y + ROI_H);
    wire roi_hit = roi_x_hit && roi_y_hit;

    wire [11:0] roi_x_rel = pix_x - ROI_X;
    wire [11:0] roi_y_rel = pix_y - ROI_Y;
    wire stride_x_hit = (roi_x_rel % SAMPLE_STRIDE) == (SAMPLE_STRIDE / 2);
    wire stride_y_hit = (roi_y_rel % SAMPLE_STRIDE) == (SAMPLE_STRIDE / 2);
    wire sample_hit = roi_hit && stride_x_hit && stride_y_hit;
    wire [7:0] sample_gx = roi_x_rel / SAMPLE_STRIDE;
    wire [7:0] sample_gy = roi_y_rel / SAMPLE_STRIDE;
    wire [7:0] sample_idx = (sample_gy * GRID_W[7:0]) + sample_gx;

    reg [3:0]         cand_digit;
    reg [8:0]         cand_match;
    reg signed [10:0] cand_metric;
    reg [3:0]         best_digit_next;
    reg [8:0]         best_match_next;
    reg signed [10:0] best_metric_next;

    assign s_ready = m_ready;
    assign m_valid = s_valid;
    assign m_data  = s_data;
    assign m_keep  = s_keep;
    assign m_sof   = s_sof;
    assign m_eol   = s_eol;
    assign m_eof   = s_eof;

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
        input [8:0] match_cnt;
        input [7:0] ones_cnt;
        begin
            metric_from = $signed({1'b0, match_cnt, 1'b0}) - $signed({3'd0, ones_cnt});
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 12'd0;
            y_cnt <= 12'd0;
            sample_count <= 9'd0;
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
            eval_idx <= 4'd0;
            best_digit_reg <= 4'd0;
            best_match_reg <= 9'd0;
            best_metric_reg <= 11'sd0;
            o_digit_valid <= 1'b0;
            o_digit_id <= 4'd0;
            o_digit_score <= 8'd0;
        end else begin
            o_digit_valid <= 1'b0;

            if (frame_done_pending) begin
                frame_done_pending <= 1'b0;
                eval_active <= 1'b1;
                eval_idx <= 4'd0;
                best_digit_reg <= 4'd0;
                best_match_reg <= match_cnt_0;
                best_metric_reg <= metric_from(match_cnt_0, 8'd72);
            end

            if (eval_active) begin
                cand_digit = eval_idx + 4'd1;
                cand_match = match_for_digit(cand_digit);
                cand_metric = metric_from(cand_match, ones_for_digit(cand_digit));

                best_digit_next = best_digit_reg;
                best_match_next = best_match_reg;
                best_metric_next = best_metric_reg;

                if (cand_metric >= best_metric_reg) begin
                    best_digit_next = cand_digit;
                    best_match_next = cand_match;
                    best_metric_next = cand_metric;
                end

                best_digit_reg <= best_digit_next;
                best_match_reg <= best_match_next;
                best_metric_reg <= best_metric_next;

                if (eval_idx == 4'd8) begin
                    eval_active <= 1'b0;
                    o_digit_valid <= 1'b1;
                    o_digit_id <= best_digit_next;
                    o_digit_score <= best_match_next[8] ? 8'hFF : best_match_next[7:0];
                end else begin
                    eval_idx <= eval_idx + 4'd1;
                end
            end

            if (accept && s_sof) begin
                sample_count <= 9'd0;
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

            if (accept && sample_hit) begin
                sample_count <= sample_count + 1'b1;
                if (pix_fg && template_bit(4'd0, sample_idx)) match_cnt_0 <= match_cnt_0 + 1'b1;
                if (pix_fg && template_bit(4'd1, sample_idx)) match_cnt_1 <= match_cnt_1 + 1'b1;
                if (pix_fg && template_bit(4'd2, sample_idx)) match_cnt_2 <= match_cnt_2 + 1'b1;
                if (pix_fg && template_bit(4'd3, sample_idx)) match_cnt_3 <= match_cnt_3 + 1'b1;
                if (pix_fg && template_bit(4'd4, sample_idx)) match_cnt_4 <= match_cnt_4 + 1'b1;
                if (pix_fg && template_bit(4'd5, sample_idx)) match_cnt_5 <= match_cnt_5 + 1'b1;
                if (pix_fg && template_bit(4'd6, sample_idx)) match_cnt_6 <= match_cnt_6 + 1'b1;
                if (pix_fg && template_bit(4'd7, sample_idx)) match_cnt_7 <= match_cnt_7 + 1'b1;
                if (pix_fg && template_bit(4'd8, sample_idx)) match_cnt_8 <= match_cnt_8 + 1'b1;
                if (pix_fg && template_bit(4'd9, sample_idx)) match_cnt_9 <= match_cnt_9 + 1'b1;
            end

            if (accept && s_eof) begin
                frame_done_pending <= 1'b1;
            end

            if (accept) begin
                if (s_eof) begin
                    x_cnt <= 12'd0;
                    y_cnt <= 12'd0;
                end else if (s_eol) begin
                    x_cnt <= 12'd0;
                    if (y_cnt < FRAME_HEIGHT - 1) begin
                        y_cnt <= y_cnt + 1'b1;
                    end
                end else begin
                    if (x_cnt < FRAME_WIDTH - 1) begin
                        x_cnt <= x_cnt + 1'b1;
                    end
                end
            end
        end
    end

endmodule
