`timescale 1ns / 1ps

module tb_gray_window_sobel_small_std;

localparam integer MAX_LANES    = 1;
localparam integer PIX_W_IN     = 24;
localparam integer PIX_W_GRAY   = 8;
localparam integer PIX_W_WINDOW = 72;
localparam integer WIDTH        = 4;
localparam integer HEIGHT       = 3;
localparam integer PIXELS       = WIDTH * HEIGHT;

integer in_idx;
integer gray_idx;
integer window_idx;
integer final_idx;
integer gray_mismatch_count;
integer window_mismatch_count;
integer final_mismatch_count;
integer gray_first_mismatch_idx;
integer window_first_mismatch_idx;
integer final_first_mismatch_idx;
integer tap_row;
integer tap_col;

reg clk;
reg rst_n;
reg done;
reg final_ready;

reg                            s_valid;
wire                           s_ready;
reg  [PIX_W_IN-1:0]            s_data;
reg  [MAX_LANES-1:0]           s_keep;
reg                            s_sof;
reg                            s_eol;
reg                            s_eof;

wire                           gray_valid;
wire                           gray_ready;
wire [PIX_W_GRAY-1:0]          gray_data;
wire [MAX_LANES-1:0]           gray_keep;
wire                           gray_sof;
wire                           gray_eol;
wire                           gray_eof;

wire                           window_valid;
wire                           window_ready;
wire [PIX_W_WINDOW-1:0]        window_data;
wire [MAX_LANES-1:0]           window_keep;
wire                           window_sof;
wire                           window_eol;
wire                           window_eof;

wire                           final_valid;
wire [PIX_W_GRAY-1:0]          final_data;
wire [MAX_LANES-1:0]           final_keep;
wire                           final_sof;
wire                           final_eol;
wire                           final_eof;

reg [23:0] rgb_mem [0:PIXELS-1];
reg [7:0] expected_gray;
reg [71:0] expected_window_value;
reg [7:0] expected_final;

function integer clamp_idx;
    input integer value;
    input integer low;
    input integer high;
    begin
        if (value < low) begin
            clamp_idx = low;
        end else if (value > high) begin
            clamp_idx = high;
        end else begin
            clamp_idx = value;
        end
    end
endfunction

function [7:0] rgb888_to_gray8;
    input [23:0] rgb;
    reg [15:0] weighted_sum;
    begin
        weighted_sum = (rgb[23:16] * 8'd77) +
                       (rgb[15:8]  * 8'd150) +
                       (rgb[7:0]   * 8'd29);
        rgb888_to_gray8 = weighted_sum[15:8];
    end
endfunction

function [71:0] expected_window;
    input integer pixel_idx;
    integer center_row;
    integer center_col;
    integer src_row;
    integer src_col;
    integer tap_idx;
    reg [71:0] tmp;
    begin
        center_row = pixel_idx / WIDTH;
        center_col = pixel_idx % WIDTH;
        tmp = 72'h0;
        tap_idx = 0;
        for (tap_row = -1; tap_row <= 1; tap_row = tap_row + 1) begin
            for (tap_col = -1; tap_col <= 1; tap_col = tap_col + 1) begin
                src_row = clamp_idx(center_row + tap_row, 0, HEIGHT - 1);
                src_col = clamp_idx(center_col + tap_col, 0, WIDTH - 1);
                tmp[(8 - tap_idx)*8 +: 8] = rgb888_to_gray8(rgb_mem[src_row*WIDTH + src_col]);
                tap_idx = tap_idx + 1;
            end
        end
        expected_window = tmp;
    end
endfunction

function [7:0] sobel9;
    input [71:0] window;
    integer p0;
    integer p1;
    integer p2;
    integer p3;
    integer p4;
    integer p5;
    integer p6;
    integer p7;
    integer p8;
    integer gx;
    integer gy;
    integer magnitude;
    begin
        p0 = window[71:64];
        p1 = window[63:56];
        p2 = window[55:48];
        p3 = window[47:40];
        p4 = window[39:32];
        p5 = window[31:24];
        p6 = window[23:16];
        p7 = window[15:8];
        p8 = window[7:0];

        gx = -p0 + p2 - (p3 * 2) + (p5 * 2) - p6 + p8;
        gy =  p0 + (p1 * 2) + p2 - p6 - (p7 * 2) - p8;
        if (gx < 0) begin
            gx = -gx;
        end
        if (gy < 0) begin
            gy = -gy;
        end
        magnitude = gx + gy;
        if (magnitude > 255) begin
            sobel9 = 8'hFF;
        end else begin
            sobel9 = magnitude[7:0];
        end
    end
endfunction

grayscale_stream_std #(
    .MAX_LANES(MAX_LANES),
    .PIX_W_IN (PIX_W_IN),
    .PIX_W_OUT(PIX_W_GRAY)
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
    .DATA_W    (PIX_W_GRAY),
    .IMG_WIDTH (WIDTH),
    .IMG_HEIGHT(HEIGHT)
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

sobel3x3_stream_std #(
    .MAX_LANES(MAX_LANES),
    .DATA_W   (PIX_W_GRAY)
) u_sobel (
    .clk    (clk),
    .rst_n  (rst_n),
    .s_valid(window_valid),
    .s_ready(window_ready),
    .s_data (window_data),
    .s_keep (window_keep),
    .s_sof  (window_sof),
    .s_eol  (window_eol),
    .s_eof  (window_eof),
    .m_valid(final_valid),
    .m_ready(final_ready),
    .m_data (final_data),
    .m_keep (final_keep),
    .m_sof  (final_sof),
    .m_eol  (final_eol),
    .m_eof  (final_eof)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rgb_mem[0]  = 24'h01_01_01;
    rgb_mem[1]  = 24'h02_02_02;
    rgb_mem[2]  = 24'h03_03_03;
    rgb_mem[3]  = 24'h04_04_04;
    rgb_mem[4]  = 24'h05_05_05;
    rgb_mem[5]  = 24'h06_06_06;
    rgb_mem[6]  = 24'h07_07_07;
    rgb_mem[7]  = 24'h08_08_08;
    rgb_mem[8]  = 24'h09_09_09;
    rgb_mem[9]  = 24'h0A_0A_0A;
    rgb_mem[10] = 24'h0B_0B_0B;
    rgb_mem[11] = 24'h0C_0C_0C;

    rst_n = 1'b0;
    done = 1'b0;
    final_ready = 1'b1;
    in_idx = 0;
    gray_idx = 0;
    window_idx = 0;
    final_idx = 0;
    gray_mismatch_count = 0;
    window_mismatch_count = 0;
    final_mismatch_count = 0;
    gray_first_mismatch_idx = -1;
    window_first_mismatch_idx = -1;
    final_first_mismatch_idx = -1;

    #20;
    rst_n = 1'b1;
end

always @* begin
    s_valid = 1'b0;
    s_data  = {PIX_W_IN{1'b0}};
    s_keep  = {MAX_LANES{1'b0}};
    s_sof   = 1'b0;
    s_eol   = 1'b0;
    s_eof   = 1'b0;

    if (rst_n && (in_idx < PIXELS)) begin
        s_valid = 1'b1;
        s_data  = rgb_mem[in_idx];
        s_keep  = 1'b1;
        s_sof   = (in_idx == 0);
        s_eol   = ((in_idx % WIDTH) == (WIDTH - 1));
        s_eof   = (in_idx == (PIXELS - 1));
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_idx <= 0;
    end else if (s_valid && s_ready) begin
        in_idx <= in_idx + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gray_idx <= 0;
    end else if (gray_valid && gray_ready) begin
        expected_gray = rgb888_to_gray8(rgb_mem[gray_idx]);
        if ((gray_keep !== 1'b1) ||
            (gray_data !== expected_gray) ||
            (gray_sof !== (gray_idx == 0)) ||
            (gray_eol !== ((gray_idx % WIDTH) == (WIDTH - 1))) ||
            (gray_eof !== (gray_idx == (PIXELS - 1)))) begin
            gray_mismatch_count = gray_mismatch_count + 1;
            if (gray_first_mismatch_idx < 0) begin
                gray_first_mismatch_idx = gray_idx;
            end
        end
        gray_idx <= gray_idx + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        window_idx <= 0;
    end else if (window_valid && window_ready) begin
        expected_window_value = expected_window(window_idx);
        if ((window_keep !== 1'b1) ||
            (window_data !== expected_window_value) ||
            (window_sof !== (window_idx == 0)) ||
            (window_eol !== ((window_idx % WIDTH) == (WIDTH - 1))) ||
            (window_eof !== (window_idx == (PIXELS - 1)))) begin
            window_mismatch_count = window_mismatch_count + 1;
            if (window_first_mismatch_idx < 0) begin
                window_first_mismatch_idx = window_idx;
            end
        end
        window_idx <= window_idx + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        final_idx <= 0;
        done <= 1'b0;
    end else if (final_valid && final_ready) begin
        expected_final = sobel9(expected_window(final_idx));
        if ((final_keep !== 1'b1) ||
            (final_data !== expected_final) ||
            (final_sof !== (final_idx == 0)) ||
            (final_eol !== ((final_idx % WIDTH) == (WIDTH - 1))) ||
            (final_eof !== (final_idx == (PIXELS - 1)))) begin
            final_mismatch_count = final_mismatch_count + 1;
            if (final_first_mismatch_idx < 0) begin
                final_first_mismatch_idx = final_idx;
            end
        end

        if (final_idx == (PIXELS - 1)) begin
            done <= 1'b1;
        end
        final_idx <= final_idx + 1;
    end
end

initial begin
    wait (done == 1'b1);
    #20;

    if (gray_mismatch_count != 0) begin
        $display("small sobel gray first mismatch index = %0d", gray_first_mismatch_idx);
        $fatal(1, "small sobel gray mismatch count = %0d", gray_mismatch_count);
    end
    if (window_mismatch_count != 0) begin
        $display("small sobel window first mismatch index = %0d", window_first_mismatch_idx);
        $fatal(1, "small sobel window mismatch count = %0d", window_mismatch_count);
    end
    if (final_mismatch_count != 0) begin
        $display("small sobel final first mismatch index = %0d", final_first_mismatch_idx);
        $fatal(1, "small sobel final mismatch count = %0d", final_mismatch_count);
    end

    $display("tb_gray_window_sobel_small_std passed.");
    $finish;
end

endmodule
