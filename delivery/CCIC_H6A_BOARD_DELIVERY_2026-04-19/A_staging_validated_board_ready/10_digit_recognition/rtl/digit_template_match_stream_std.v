`timescale 1ns / 1ps

module digit_template_match_stream_std #(
    parameter integer FRAME_WIDTH   = 640,
    parameter integer FRAME_HEIGHT  = 480,
    parameter integer ROI_X         = 64,
    parameter integer ROI_Y         = 208,
    parameter integer DIGIT_W       = 64,
    parameter integer DIGIT_H       = 64,
    parameter integer NUM_DIGITS    = 4,
    parameter integer DIGIT_GAP     = 16,
    parameter integer SAMPLE_STRIDE = 4,
    parameter [7:0]   THRESHOLD     = 8'd96,
    parameter [8:0]   MIN_FG_PIX    = 9'd8,
    parameter integer DETECT_X      = 0,
    parameter integer DETECT_Y      = 0,
    parameter integer DETECT_W      = FRAME_WIDTH,
    parameter integer DETECT_H      = FRAME_HEIGHT,
    parameter [11:0]  COL_THRESH    = 12'd8,
    parameter [11:0]  MIN_RUN_W     = 12'd6,
    parameter integer DETECT_BIN_SHIFT = 3
) (
    input  wire                          clk,              // Processing clock.
    input  wire                          rst_n,            // Active-low reset.
    input  wire                          s_valid,          // Input beat valid.
    output wire                          s_ready,          // Input beat ready.
    input  wire [23:0]                   s_data,           // Input RGB888 pixel.
    input  wire                          s_keep,           // Input lane keep.
    input  wire                          s_sof,            // Input start-of-frame.
    input  wire                          s_eol,            // Input end-of-line.
    input  wire                          s_eof,            // Input end-of-frame.
    output wire                          m_valid,          // Output beat valid (passthrough).
    input  wire                          m_ready,          // Output beat ready (passthrough).
    output wire [23:0]                   m_data,           // Output RGB888 pixel (passthrough).
    output wire                          m_keep,           // Output keep (passthrough).
    output wire                          m_sof,            // Output SOF (passthrough).
    output wire                          m_eol,            // Output EOL (passthrough).
    output wire                          m_eof,            // Output EOF (passthrough).
    output reg                           o_digit_valid,    // Backward-compatible: slot0 digit valid pulse.
    output reg  [3:0]                    o_digit_id,       // Backward-compatible: slot0 digit id.
    output reg  [7:0]                    o_digit_score,    // Backward-compatible: slot0 match score.
    output reg                           o_digits_valid,   // One-cycle pulse when all slots are updated.
    output reg  [NUM_DIGITS*4-1:0]       o_digit_ids,      // Packed ids: slot i at [i*4 +: 4].
    output reg  [NUM_DIGITS*8-1:0]       o_digit_scores,   // Packed scores: slot i at [i*8 +: 8].
    output reg  [NUM_DIGITS-1:0]         o_digit_present   // Slot has enough foreground samples.
);

    localparam integer SLOT_PITCH = DIGIT_W + DIGIT_GAP;
    localparam integer DETECT_X_END = DETECT_X + DETECT_W - 1;
    localparam integer DETECT_Y_END = DETECT_Y + DETECT_H - 1;
    localparam integer BIN_W = (1 << DETECT_BIN_SHIFT);
    localparam integer DETECT_BIN_NUM = (DETECT_W + BIN_W - 1) / BIN_W;

    wire accept = s_valid && s_ready && s_keep;

    wire gray_valid;
    wire [7:0] gray_data;
    wire gray_keep;
    wire gray_sof;
    wire gray_eol;
    wire gray_eof;

    wire bin_valid;
    wire [7:0] bin_data;
    wire bin_keep;
    wire bin_sof;
    wire bin_eol;
    wire bin_eof;

    wire feat_accept = bin_valid && bin_keep;
    wire pix_fg = ~bin_data[0];

    reg [11:0] x_cnt; // Pixel x counter aligned to binary feature stream.
    reg [11:0] y_cnt; // Pixel y counter aligned to binary feature stream.
    wire [11:0] pix_x = bin_sof ? 12'd0 : x_cnt;
    wire [11:0] pix_y = bin_sof ? 12'd0 : y_cnt;

    wire detect_x_hit = (pix_x >= DETECT_X) && (pix_x <= DETECT_X_END);
    wire detect_y_hit = (pix_y >= DETECT_Y) && (pix_y <= DETECT_Y_END);
    wire detect_hit = detect_x_hit && detect_y_hit;
    wire [11:0] pix_x_rel = pix_x - DETECT_X;
    wire [11:0] pix_bin_idx = pix_x_rel >> DETECT_BIN_SHIFT;

    reg [11:0] roi_x_runtime [0:NUM_DIGITS-1];
    reg [11:0] roi_x_pending [0:NUM_DIGITS-1];
    reg        roi_en_runtime [0:NUM_DIGITS-1];
    reg        roi_en_pending [0:NUM_DIGITS-1];
    reg        roi_pending_valid;

    reg [10:0] col_cnt0 [0:DETECT_BIN_NUM-1];
    reg [10:0] col_cnt1 [0:DETECT_BIN_NUM-1];

    reg        write_bank;
    reg        col_acc_valid_q;
    reg [11:0] col_acc_bin_q;
    reg        col_acc_bank_q;

    reg        scan_active;
    reg        scan_bank;
    reg [11:0] scan_issue_bin;
    reg        scan_issue_done;
    reg        scan_in_run;
    reg [11:0] scan_run_start;
    reg [7:0]  scan_found_slots;

    reg        scan_pipe_valid;
    reg [11:0] scan_bin_q;
    reg [10:0] scan_col_cnt_q;
    reg        scan_is_last_q;

    reg        slot_write_req;
    reg [7:0]  slot_write_idx;
    reg [11:0] slot_write_center_x;

    wire       scan_col_hit_q;
    wire       scan_run_open_q;
    wire       scan_run_close_q;
    wire [11:0] scan_run_start_eff_q;
    wire [11:0] scan_run_end_q;
    wire [11:0] scan_run_width_bins_q;
    wire [11:0] scan_run_width_pix_q;
    wire       scan_run_accept_q;
    wire [11:0] scan_run_center_bin_q;
    wire [11:0] scan_run_center_x_q;

    integer i;

    wire [NUM_DIGITS-1:0]   slot_valid_w;
    wire [NUM_DIGITS-1:0]   slot_present_w;
    wire [NUM_DIGITS*4-1:0] slot_id_w;
    wire [NUM_DIGITS*8-1:0] slot_score_w;

    assign scan_col_hit_q = ({1'b0, scan_col_cnt_q} >= COL_THRESH);
    assign scan_run_open_q = scan_pipe_valid && !scan_in_run && scan_col_hit_q && !scan_is_last_q;
    assign scan_run_close_q = scan_pipe_valid &&
                              ((scan_in_run && (!scan_col_hit_q || scan_is_last_q)) ||
                               (!scan_in_run && scan_col_hit_q && scan_is_last_q));
    assign scan_run_start_eff_q = scan_in_run ? scan_run_start : scan_bin_q;
    assign scan_run_end_q = (scan_col_hit_q && scan_is_last_q) ? scan_bin_q : (scan_bin_q - 1'b1);
    assign scan_run_width_bins_q = scan_run_end_q - scan_run_start_eff_q + 1'b1;
    assign scan_run_width_pix_q = scan_run_width_bins_q << DETECT_BIN_SHIFT;
    assign scan_run_accept_q = scan_run_close_q &&
                               (scan_run_width_pix_q >= MIN_RUN_W) &&
                               (scan_found_slots < NUM_DIGITS);
    assign scan_run_center_bin_q = (scan_run_start_eff_q + scan_run_end_q) >> 1;
    assign scan_run_center_x_q = DETECT_X + (scan_run_center_bin_q << DETECT_BIN_SHIFT) + (BIN_W >> 1);

    function [11:0] clamp_roi_x;
        input [11:0] center_x;
        reg [11:0] half_w;
        reg [11:0] max_x;
        begin
            half_w = DIGIT_W[11:0] >> 1;
            max_x = FRAME_WIDTH[11:0] - DIGIT_W[11:0];
            if (center_x <= half_w) begin
                clamp_roi_x = 12'd0;
            end else if (center_x >= max_x + half_w) begin
                clamp_roi_x = max_x;
            end else begin
                clamp_roi_x = center_x - half_w;
            end
        end
    endfunction

    genvar gi;
    generate
        for (gi = 0; gi < NUM_DIGITS; gi = gi + 1) begin : g_slot_core
            digit_template_match_slot_core #(
                .ROI_W(DIGIT_W),
                .ROI_H(DIGIT_H),
                .SAMPLE_STRIDE(SAMPLE_STRIDE),
                .MIN_FG_PIX(MIN_FG_PIX)
            ) u_slot_core (
                .clk(clk),
                .rst_n(rst_n),
                .i_feat_accept(feat_accept),
                .i_pix_x(pix_x),
                .i_pix_y(pix_y),
                .i_sof(bin_sof),
                .i_eof(bin_eof),
                .i_pix_fg(pix_fg),
                .i_roi_enable(roi_en_runtime[gi]),
                .i_roi_x(roi_x_runtime[gi]),
                .i_roi_y(ROI_Y[11:0]),
                .o_digit_valid(slot_valid_w[gi]),
                .o_digit_present(slot_present_w[gi]),
                .o_digit_id(slot_id_w[gi*4 +: 4]),
                .o_digit_score(slot_score_w[gi*8 +: 8])
            );
        end
    endgenerate

    assign s_ready = m_ready;
    assign m_valid = s_valid;
    assign m_data  = s_data;
    assign m_keep  = s_keep;
    assign m_sof   = s_sof;
    assign m_eol   = s_eol;
    assign m_eof   = s_eof;

    grayscale_stream_std #(
        .MAX_LANES(1),
        .PIX_W_IN(24),
        .PIX_W_OUT(8)
    ) u_grayscale_stream_std (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(accept),
        .s_ready(),
        .s_data (s_data),
        .s_keep (s_keep),
        .s_sof  (s_sof),
        .s_eol  (s_eol),
        .s_eof  (s_eof),
        .m_valid(gray_valid),
        .m_ready(1'b1),
        .m_data (gray_data),
        .m_keep (gray_keep),
        .m_sof  (gray_sof),
        .m_eol  (gray_eol),
        .m_eof  (gray_eof)
    );

    binary_threshold_stream_std #(
        .MAX_LANES(1),
        .DATA_W(8),
        .THRESHOLD(THRESHOLD)
    ) u_binary_threshold_stream_std (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(gray_valid),
        .s_ready(),
        .s_data (gray_data),
        .s_keep (gray_keep),
        .s_sof  (gray_sof),
        .s_eol  (gray_eol),
        .s_eof  (gray_eof),
        .m_valid(bin_valid),
        .m_ready(1'b1),
        .m_data (bin_data),
        .m_keep (bin_keep),
        .m_sof  (bin_sof),
        .m_eol  (bin_eol),
        .m_eof  (bin_eof)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_cnt <= 12'd0;
            y_cnt <= 12'd0;
            o_digit_valid <= 1'b0;
            o_digit_id <= 4'd0;
            o_digit_score <= 8'd0;
            o_digits_valid <= 1'b0;
            o_digit_ids <= {NUM_DIGITS*4{1'b0}};
            o_digit_scores <= {NUM_DIGITS*8{1'b0}};
            o_digit_present <= {NUM_DIGITS{1'b0}};
            roi_pending_valid <= 1'b0;
            write_bank <= 1'b0;
            col_acc_valid_q <= 1'b0;
            col_acc_bin_q <= 12'd0;
            col_acc_bank_q <= 1'b0;
            scan_active <= 1'b0;
            scan_bank <= 1'b0;
            scan_issue_bin <= 12'd0;
            scan_issue_done <= 1'b0;
            scan_in_run <= 1'b0;
            scan_run_start <= 12'd0;
            scan_found_slots <= 8'd0;
            scan_pipe_valid <= 1'b0;
            scan_bin_q <= 12'd0;
            scan_col_cnt_q <= 11'd0;
            scan_is_last_q <= 1'b0;
            slot_write_req <= 1'b0;
            slot_write_idx <= 8'd0;
            slot_write_center_x <= 12'd0;
            for (i = 0; i < NUM_DIGITS; i = i + 1) begin
                roi_x_runtime[i] <= clamp_roi_x(ROI_X + i*SLOT_PITCH + (DIGIT_W/2));
                roi_x_pending[i] <= clamp_roi_x(ROI_X + i*SLOT_PITCH + (DIGIT_W/2));
                roi_en_runtime[i] <= 1'b1;
                roi_en_pending[i] <= 1'b1;
            end
            for (i = 0; i < DETECT_BIN_NUM; i = i + 1) begin
                col_cnt0[i] <= 11'd0;
                col_cnt1[i] <= 11'd0;
            end
        end else begin
            o_digit_valid <= 1'b0;
            o_digits_valid <= 1'b0;
            scan_pipe_valid <= 1'b0;
            slot_write_req <= 1'b0;

            if (feat_accept && bin_sof && roi_pending_valid) begin
                roi_pending_valid <= 1'b0;
                for (i = 0; i < NUM_DIGITS; i = i + 1) begin
                    roi_x_runtime[i] <= roi_x_pending[i];
                    roi_en_runtime[i] <= roi_en_pending[i];
                end
            end

            if (feat_accept) begin
                if (bin_eof) begin
                    x_cnt <= 12'd0;
                    y_cnt <= 12'd0;
                end else if (bin_eol) begin
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

            if (feat_accept && bin_sof) begin
                for (i = 0; i < DETECT_BIN_NUM; i = i + 1) begin
                    if (!write_bank) begin
                        col_cnt0[i] <= 11'd0;
                    end else begin
                        col_cnt1[i] <= 11'd0;
                    end
                end
            end

            if (feat_accept && detect_hit && pix_fg && (pix_bin_idx < DETECT_BIN_NUM)) begin
                col_acc_valid_q <= 1'b1;
                col_acc_bin_q <= pix_bin_idx;
                col_acc_bank_q <= write_bank;
            end else begin
                col_acc_valid_q <= 1'b0;
            end

            if (col_acc_valid_q) begin
                if (!col_acc_bank_q) begin
                    col_cnt0[col_acc_bin_q] <= col_cnt0[col_acc_bin_q] + 1'b1;
                end else begin
                    col_cnt1[col_acc_bin_q] <= col_cnt1[col_acc_bin_q] + 1'b1;
                end
            end

            if (feat_accept && bin_eof) begin
                if (!scan_active && !roi_pending_valid) begin
                    scan_active <= 1'b1;
                    scan_bank <= write_bank;
                    scan_issue_bin <= 12'd0;
                    scan_issue_done <= 1'b0;
                    scan_in_run <= 1'b0;
                    scan_run_start <= 12'd0;
                    scan_found_slots <= 8'd0;
                    for (i = 0; i < NUM_DIGITS; i = i + 1) begin
                        roi_x_pending[i] <= roi_x_runtime[i];
                        roi_en_pending[i] <= 1'b0;
                    end
                end
                write_bank <= ~write_bank;
            end

            if (scan_active && !scan_issue_done) begin
                scan_pipe_valid <= 1'b1;
                scan_bin_q <= scan_issue_bin;
                scan_is_last_q <= (scan_issue_bin == (DETECT_BIN_NUM - 1));
                if (!scan_bank) begin
                    scan_col_cnt_q <= col_cnt0[scan_issue_bin];
                end else begin
                    scan_col_cnt_q <= col_cnt1[scan_issue_bin];
                end

                if (scan_issue_bin == (DETECT_BIN_NUM - 1)) begin
                    scan_issue_done <= 1'b1;
                end else begin
                    scan_issue_bin <= scan_issue_bin + 1'b1;
                end
            end

            if (scan_pipe_valid) begin
                if (scan_run_open_q) begin
                    scan_in_run <= 1'b1;
                    scan_run_start <= scan_bin_q;
                end

                if (scan_run_close_q) begin
                    scan_in_run <= 1'b0;
                end

                if (scan_run_accept_q) begin
                    slot_write_req <= 1'b1;
                    slot_write_idx <= scan_found_slots;
                    slot_write_center_x <= scan_run_center_x_q;
                    scan_found_slots <= scan_found_slots + 1'b1;
                end

                if (scan_is_last_q) begin
                    roi_pending_valid <= 1'b1;
                    scan_active <= 1'b0;
                    scan_issue_done <= 1'b0;
                    scan_issue_bin <= 12'd0;
                end
            end

            if (slot_write_req) begin
                if (slot_write_idx < NUM_DIGITS) begin
                    roi_x_pending[slot_write_idx] <= clamp_roi_x(slot_write_center_x);
                    roi_en_pending[slot_write_idx] <= 1'b1;
                end
            end

            // All slot cores are aligned to the same frame event; use slot0 valid as commit pulse.
            if (slot_valid_w[0]) begin
                o_digits_valid <= 1'b1;
                o_digit_valid <= 1'b1;
                o_digit_ids <= slot_id_w;
                o_digit_scores <= slot_score_w;
                o_digit_present <= slot_present_w;
                o_digit_id <= slot_id_w[3:0];
                o_digit_score <= slot_score_w[7:0];
            end
        end
    end

endmodule
