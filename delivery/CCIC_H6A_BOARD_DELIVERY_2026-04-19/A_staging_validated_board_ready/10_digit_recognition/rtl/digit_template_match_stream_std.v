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
    parameter [8:0]   MIN_FG_PIX    = 9'd8
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

    wire [NUM_DIGITS-1:0]   slot_valid_w;
    wire [NUM_DIGITS-1:0]   slot_present_w;
    wire [NUM_DIGITS*4-1:0] slot_id_w;
    wire [NUM_DIGITS*8-1:0] slot_score_w;

    genvar gi;
    generate
        for (gi = 0; gi < NUM_DIGITS; gi = gi + 1) begin : g_slot_core
            digit_template_match_slot_core #(
                .ROI_X(ROI_X + gi * SLOT_PITCH),
                .ROI_Y(ROI_Y),
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
        end else begin
            o_digit_valid <= 1'b0;
            o_digits_valid <= 1'b0;

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

