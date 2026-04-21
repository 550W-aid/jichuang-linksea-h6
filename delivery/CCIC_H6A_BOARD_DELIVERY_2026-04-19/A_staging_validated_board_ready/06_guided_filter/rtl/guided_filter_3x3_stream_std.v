`timescale 1ns / 1ps

module guided_filter_3x3_stream_std #(
    parameter integer MAX_LANES   = 1,
    parameter integer PIX_W_IN    = 24,
    parameter integer PIX_W_OUT   = 8,
    parameter integer IMG_WIDTH   = 64,
    parameter integer IMG_HEIGHT  = 64,
    parameter [7:0]   EDGE_THRESH = 8'd12,
    parameter [3:0]   EDGE_GAIN   = 4'd3,
    parameter [3:0]   FLAT_GAIN   = 4'd1
) (
    input  wire                           clk,     // processing clock
    input  wire                           rst_n,   // active-low reset
    input  wire                           s_valid, // upstream valid
    output wire                           s_ready, // upstream ready
    input  wire [MAX_LANES*PIX_W_IN-1:0]  s_data,  // input RGB pixel stream
    input  wire [MAX_LANES-1:0]           s_keep,  // input lane keep
    input  wire                           s_sof,   // start of frame
    input  wire                           s_eol,   // end of line
    input  wire                           s_eof,   // end of frame
    output reg                            m_valid, // downstream valid
    input  wire                           m_ready, // downstream ready
    output reg  [MAX_LANES*PIX_W_OUT-1:0] m_data,  // output grayscale pixel
    output reg  [MAX_LANES-1:0]           m_keep,  // output lane keep
    output reg                            m_sof,   // output start of frame
    output reg                            m_eol,   // output end of line
    output reg                            m_eof    // output end of frame
);

    wire                             gray_valid;
    wire                             gray_ready;
    wire [MAX_LANES*PIX_W_OUT-1:0]   gray_data;
    wire [MAX_LANES-1:0]             gray_keep;
    wire                             gray_sof;
    wire                             gray_eol;
    wire                             gray_eof;

    wire                             window_valid;
    wire                             window_ready;
    wire [MAX_LANES*PIX_W_OUT*9-1:0] window_data;
    wire [MAX_LANES-1:0]             window_keep;
    wire                             window_sof;
    wire                             window_eol;
    wire                             window_eof;

    wire                             core_in_ready;
    wire                             core_valid;
    wire [7:0]                       core_pixel;
    wire                             stage_ready;
    wire                             meta_s7_ready;
    wire                             meta_s6_ready;
    wire                             meta_s5_ready;
    wire                             meta_s4_ready;
    wire                             meta_s3_ready;
    wire                             meta_s2_ready;
    wire                             meta_s1_ready;
    wire                             shared_ready;
    wire                             shared_accept;

    reg  [MAX_LANES-1:0]             meta_s1_keep;
    reg                              meta_s1_sof;
    reg                              meta_s1_eol;
    reg                              meta_s1_eof;
    reg                              meta_s1_valid;

    reg  [MAX_LANES-1:0]             meta_s2_keep;
    reg                              meta_s2_sof;
    reg                              meta_s2_eol;
    reg                              meta_s2_eof;
    reg                              meta_s2_valid;

    reg  [MAX_LANES-1:0]             meta_s3_keep;
    reg                              meta_s3_sof;
    reg                              meta_s3_eol;
    reg                              meta_s3_eof;
    reg                              meta_s3_valid;

    reg  [MAX_LANES-1:0]             meta_s4_keep;
    reg                              meta_s4_sof;
    reg                              meta_s4_eol;
    reg                              meta_s4_eof;
    reg                              meta_s4_valid;

    reg  [MAX_LANES-1:0]             meta_s5_keep;
    reg                              meta_s5_sof;
    reg                              meta_s5_eol;
    reg                              meta_s5_eof;
    reg                              meta_s5_valid;

    reg  [MAX_LANES-1:0]             meta_s6_keep;
    reg                              meta_s6_sof;
    reg                              meta_s6_eol;
    reg                              meta_s6_eof;
    reg                              meta_s6_valid;

    reg  [MAX_LANES-1:0]             meta_s7_keep;
    reg                              meta_s7_sof;
    reg                              meta_s7_eol;
    reg                              meta_s7_eof;
    reg                              meta_s7_valid;

    // Delivery note:
    // This wrapper is only validated for MAX_LANES=1 and PIX_W_OUT=8 in the
    // current handoff package.
    assign stage_ready   = (~m_valid) | m_ready;
    assign meta_s7_ready = stage_ready;
    assign meta_s6_ready = (~meta_s6_valid) | meta_s7_ready;
    assign meta_s5_ready = (~meta_s5_valid) | meta_s6_ready;
    assign meta_s4_ready = (~meta_s4_valid) | meta_s5_ready;
    assign meta_s3_ready = (~meta_s3_valid) | meta_s4_ready;
    assign meta_s2_ready = (~meta_s2_valid) | meta_s3_ready;
    assign meta_s1_ready = (~meta_s1_valid) | meta_s2_ready;
    assign shared_ready  = core_in_ready && meta_s1_ready;
    assign shared_accept = window_valid && shared_ready;
    assign window_ready  = shared_ready;

    grayscale_stream_std #(
        .MAX_LANES(MAX_LANES),
        .PIX_W_IN (PIX_W_IN),
        .PIX_W_OUT(PIX_W_OUT)
    ) u_gray (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data (s_data),
        .s_keep (s_keep),
        .s_sof  (s_sof),
        .s_eol  (s_eol),
        .s_eof  (s_eof),
        .m_valid(gray_valid),
        .m_ready(gray_ready),
        .m_data (gray_data),
        .m_keep (gray_keep),
        .m_sof  (gray_sof),
        .m_eol  (gray_eol),
        .m_eof  (gray_eof)
    );

    window3x3_stream_std #(
        .MAX_LANES (MAX_LANES),
        .DATA_W    (PIX_W_OUT),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT)
    ) u_window (
        .clk    (clk),
        .rst_n  (rst_n),
        .s_valid(gray_valid),
        .s_ready(gray_ready),
        .s_data (gray_data),
        .s_keep (gray_keep),
        .s_sof  (gray_sof),
        .s_eol  (gray_eol),
        .s_eof  (gray_eof),
        .m_valid(window_valid),
        .m_ready(window_ready),
        .m_data (window_data),
        .m_keep (window_keep),
        .m_sof  (window_sof),
        .m_eol  (window_eol),
        .m_eof  (window_eof)
    );

    guided_filter_3x3_core #(
        .EDGE_THRESH(EDGE_THRESH),
        .EDGE_GAIN  (EDGE_GAIN),
        .FLAT_GAIN  (FLAT_GAIN)
    ) u_core (
        .clk    (clk),
        .rst_n  (rst_n),
        .i_valid(shared_accept),
        .i_ready(core_in_ready),
        .i_window(window_data[PIX_W_OUT*9-1:0]),
        .o_valid(core_valid),
        .o_ready(stage_ready),
        .o_pixel(core_pixel)
    );

    // Keep frame-control metadata aligned with the deeper guided-filter core.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            meta_s1_valid <= 1'b0;
            meta_s1_keep  <= {MAX_LANES{1'b0}};
            meta_s1_sof   <= 1'b0;
            meta_s1_eol   <= 1'b0;
            meta_s1_eof   <= 1'b0;
            meta_s2_valid <= 1'b0;
            meta_s2_keep  <= {MAX_LANES{1'b0}};
            meta_s2_sof   <= 1'b0;
            meta_s2_eol   <= 1'b0;
            meta_s2_eof   <= 1'b0;
            meta_s3_valid <= 1'b0;
            meta_s3_keep  <= {MAX_LANES{1'b0}};
            meta_s3_sof   <= 1'b0;
            meta_s3_eol   <= 1'b0;
            meta_s3_eof   <= 1'b0;
            meta_s4_valid <= 1'b0;
            meta_s4_keep  <= {MAX_LANES{1'b0}};
            meta_s4_sof   <= 1'b0;
            meta_s4_eol   <= 1'b0;
            meta_s4_eof   <= 1'b0;
            meta_s5_valid <= 1'b0;
            meta_s5_keep  <= {MAX_LANES{1'b0}};
            meta_s5_sof   <= 1'b0;
            meta_s5_eol   <= 1'b0;
            meta_s5_eof   <= 1'b0;
            meta_s6_valid <= 1'b0;
            meta_s6_keep  <= {MAX_LANES{1'b0}};
            meta_s6_sof   <= 1'b0;
            meta_s6_eol   <= 1'b0;
            meta_s6_eof   <= 1'b0;
            meta_s7_valid <= 1'b0;
            meta_s7_keep  <= {MAX_LANES{1'b0}};
            meta_s7_sof   <= 1'b0;
            meta_s7_eol   <= 1'b0;
            meta_s7_eof   <= 1'b0;
            m_valid       <= 1'b0;
            m_data        <= {MAX_LANES*PIX_W_OUT{1'b0}};
            m_keep        <= {MAX_LANES{1'b0}};
            m_sof         <= 1'b0;
            m_eol         <= 1'b0;
            m_eof         <= 1'b0;
        end else begin
            if (meta_s1_ready) begin
                meta_s1_valid <= shared_accept;
                if (shared_accept) begin
                    meta_s1_keep <= window_keep;
                    meta_s1_sof  <= window_sof;
                    meta_s1_eol  <= window_eol;
                    meta_s1_eof  <= window_eof;
                end else begin
                    meta_s1_keep <= {MAX_LANES{1'b0}};
                    meta_s1_sof  <= 1'b0;
                    meta_s1_eol  <= 1'b0;
                    meta_s1_eof  <= 1'b0;
                end
            end

            if (meta_s2_ready) begin
                meta_s2_valid <= meta_s1_valid;
                if (meta_s1_valid) begin
                    meta_s2_keep <= meta_s1_keep;
                    meta_s2_sof  <= meta_s1_sof;
                    meta_s2_eol  <= meta_s1_eol;
                    meta_s2_eof  <= meta_s1_eof;
                end else begin
                    meta_s2_keep <= {MAX_LANES{1'b0}};
                    meta_s2_sof  <= 1'b0;
                    meta_s2_eol  <= 1'b0;
                    meta_s2_eof  <= 1'b0;
                end
            end

            if (meta_s3_ready) begin
                meta_s3_valid <= meta_s2_valid;
                if (meta_s2_valid) begin
                    meta_s3_keep <= meta_s2_keep;
                    meta_s3_sof  <= meta_s2_sof;
                    meta_s3_eol  <= meta_s2_eol;
                    meta_s3_eof  <= meta_s2_eof;
                end else begin
                    meta_s3_keep <= {MAX_LANES{1'b0}};
                    meta_s3_sof  <= 1'b0;
                    meta_s3_eol  <= 1'b0;
                    meta_s3_eof  <= 1'b0;
                end
            end

            if (meta_s4_ready) begin
                meta_s4_valid <= meta_s3_valid;
                if (meta_s3_valid) begin
                    meta_s4_keep <= meta_s3_keep;
                    meta_s4_sof  <= meta_s3_sof;
                    meta_s4_eol  <= meta_s3_eol;
                    meta_s4_eof  <= meta_s3_eof;
                end else begin
                    meta_s4_keep <= {MAX_LANES{1'b0}};
                    meta_s4_sof  <= 1'b0;
                    meta_s4_eol  <= 1'b0;
                    meta_s4_eof  <= 1'b0;
                end
            end

            if (meta_s5_ready) begin
                meta_s5_valid <= meta_s4_valid;
                if (meta_s4_valid) begin
                    meta_s5_keep <= meta_s4_keep;
                    meta_s5_sof  <= meta_s4_sof;
                    meta_s5_eol  <= meta_s4_eol;
                    meta_s5_eof  <= meta_s4_eof;
                end else begin
                    meta_s5_keep <= {MAX_LANES{1'b0}};
                    meta_s5_sof  <= 1'b0;
                    meta_s5_eol  <= 1'b0;
                    meta_s5_eof  <= 1'b0;
                end
            end

            if (meta_s6_ready) begin
                meta_s6_valid <= meta_s5_valid;
                if (meta_s5_valid) begin
                    meta_s6_keep <= meta_s5_keep;
                    meta_s6_sof  <= meta_s5_sof;
                    meta_s6_eol  <= meta_s5_eol;
                    meta_s6_eof  <= meta_s5_eof;
                end else begin
                    meta_s6_keep <= {MAX_LANES{1'b0}};
                    meta_s6_sof  <= 1'b0;
                    meta_s6_eol  <= 1'b0;
                    meta_s6_eof  <= 1'b0;
                end
            end

            if (meta_s7_ready) begin
                meta_s7_valid <= meta_s6_valid;
                if (meta_s6_valid) begin
                    meta_s7_keep <= meta_s6_keep;
                    meta_s7_sof  <= meta_s6_sof;
                    meta_s7_eol  <= meta_s6_eol;
                    meta_s7_eof  <= meta_s6_eof;
                end else begin
                    meta_s7_keep <= {MAX_LANES{1'b0}};
                    meta_s7_sof  <= 1'b0;
                    meta_s7_eol  <= 1'b0;
                    meta_s7_eof  <= 1'b0;
                end
            end

            if (stage_ready) begin
                m_valid <= core_valid;
                if (core_valid) begin
                    m_data <= core_pixel;
                    m_keep <= meta_s7_keep;
                    m_sof  <= meta_s7_sof;
                    m_eol  <= meta_s7_eol;
                    m_eof  <= meta_s7_eof;
                end else begin
                    m_data <= {MAX_LANES*PIX_W_OUT{1'b0}};
                    m_keep <= {MAX_LANES{1'b0}};
                    m_sof  <= 1'b0;
                    m_eol  <= 1'b0;
                    m_eof  <= 1'b0;
                end
            end
        end
    end
endmodule
