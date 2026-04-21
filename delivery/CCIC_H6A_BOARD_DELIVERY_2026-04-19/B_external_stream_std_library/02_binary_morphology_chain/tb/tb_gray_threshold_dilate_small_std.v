`timescale 1ns / 1ps

module tb_gray_threshold_dilate_small_std;

localparam integer MAX_LANES    = 1;
localparam integer PIX_W_IN     = 24;
localparam integer PIX_W_GRAY   = 8;
localparam integer PIX_W_WINDOW = 72;
localparam integer WIDTH        = 4;
localparam integer HEIGHT       = 3;
localparam integer PIXELS       = WIDTH * HEIGHT;
localparam [7:0] THRESHOLD      = 8'd8;

integer in_idx;
integer mask_idx;
integer final_idx;
integer mask_mismatch_count;
integer final_mismatch_count;
integer mask_first_mismatch_idx;
integer final_first_mismatch_idx;
integer tap_row;
integer tap_col;

reg clk;
reg rst_n;
reg done;
reg final_ready;

reg                         s_valid;
wire                        s_ready;
reg  [PIX_W_IN-1:0]         s_data;
reg  [MAX_LANES-1:0]        s_keep;
reg                         s_sof;
reg                         s_eol;
reg                         s_eof;

wire                        gray_valid;
wire                        gray_ready;
wire [PIX_W_GRAY-1:0]       gray_data;
wire [MAX_LANES-1:0]        gray_keep;
wire                        gray_sof;
wire                        gray_eol;
wire                        gray_eof;

wire                        mask_valid;
wire                        mask_ready;
wire [PIX_W_GRAY-1:0]       mask_data;
wire [MAX_LANES-1:0]        mask_keep;
wire                        mask_sof;
wire                        mask_eol;
wire                        mask_eof;

wire                        window_valid;
wire                        window_ready;
wire [PIX_W_WINDOW-1:0]     window_data;
wire [MAX_LANES-1:0]        window_keep;
wire                        window_sof;
wire                        window_eol;
wire                        window_eof;

wire                        final_valid;
wire [PIX_W_GRAY-1:0]       final_data;
wire [MAX_LANES-1:0]        final_keep;
wire                        final_sof;
wire                        final_eol;
wire                        final_eof;

reg [23:0] rgb_mem [0:PIXELS-1];
reg [7:0] expected_mask;
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

function [7:0] expected_binary;
    input integer pixel_idx;
    begin
        expected_binary = (rgb_mem[pixel_idx][7:0] >= THRESHOLD) ? 8'hFF : 8'h00;
    end
endfunction

function [71:0] expected_mask_window;
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
                tmp[(8 - tap_idx)*8 +: 8] = expected_binary(src_row*WIDTH + src_col);
                tap_idx = tap_idx + 1;
            end
        end
        expected_mask_window = tmp;
    end
endfunction

function [7:0] expected_dilate;
    input integer pixel_idx;
    integer tap_idx;
    reg [71:0] window;
    reg any_set;
    begin
        window = expected_mask_window(pixel_idx);
        any_set = 1'b0;
        for (tap_idx = 0; tap_idx < 9; tap_idx = tap_idx + 1) begin
            if (window[tap_idx*8 +: 8] != 8'h00) begin
                any_set = 1'b1;
            end
        end
        expected_dilate = any_set ? 8'hFF : 8'h00;
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

binary_threshold_stream_std #(
    .MAX_LANES(MAX_LANES),
    .DATA_W   (PIX_W_GRAY),
    .THRESHOLD(THRESHOLD)
) u_threshold (
    .clk    (clk),
    .rst_n  (rst_n),
    .s_valid(gray_valid),
    .s_ready(gray_ready),
    .s_data (gray_data),
    .s_keep (gray_keep),
    .s_sof  (gray_sof),
    .s_eol  (gray_eol),
    .s_eof  (gray_eof),
    .m_valid(mask_valid),
    .m_ready(mask_ready),
    .m_data (mask_data),
    .m_keep (mask_keep),
    .m_sof  (mask_sof),
    .m_eol  (mask_eol),
    .m_eof  (mask_eof)
);

window3x3_stream_std #(
    .MAX_LANES (MAX_LANES),
    .DATA_W    (PIX_W_GRAY),
    .IMG_WIDTH (WIDTH),
    .IMG_HEIGHT(HEIGHT)
) u_window (
    .clk    (clk),
    .rst_n  (rst_n),
    .s_valid(mask_valid),
    .s_ready(mask_ready),
    .s_data (mask_data),
    .s_keep (mask_keep),
    .s_sof  (mask_sof),
    .s_eol  (mask_eol),
    .s_eof  (mask_eof),
    .m_valid(window_valid),
    .m_ready(window_ready),
    .m_data (window_data),
    .m_keep (window_keep),
    .m_sof  (window_sof),
    .m_eol  (window_eol),
    .m_eof  (window_eof)
);

dilate3x3_binary_stream_std #(
    .MAX_LANES(MAX_LANES),
    .DATA_W   (PIX_W_GRAY)
) u_dilate (
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
    mask_idx = 0;
    final_idx = 0;
    mask_mismatch_count = 0;
    final_mismatch_count = 0;
    mask_first_mismatch_idx = -1;
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
        mask_idx <= 0;
    end else if (mask_valid && mask_ready) begin
        expected_mask = expected_binary(mask_idx);
        if ((mask_keep !== 1'b1) ||
            (mask_data !== expected_mask) ||
            (mask_sof !== (mask_idx == 0)) ||
            (mask_eol !== ((mask_idx % WIDTH) == (WIDTH - 1))) ||
            (mask_eof !== (mask_idx == (PIXELS - 1)))) begin
            mask_mismatch_count = mask_mismatch_count + 1;
            if (mask_first_mismatch_idx < 0) begin
                mask_first_mismatch_idx = mask_idx;
            end
        end
        mask_idx <= mask_idx + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        final_idx <= 0;
        done <= 1'b0;
    end else if (final_valid && final_ready) begin
        expected_final = expected_dilate(final_idx);
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
    if (mask_mismatch_count != 0) begin
        $fatal(1, "tb_gray_threshold_dilate_small_std threshold mismatch count=%0d first=%0d",
               mask_mismatch_count, mask_first_mismatch_idx);
    end
    if (final_mismatch_count != 0) begin
        $fatal(1, "tb_gray_threshold_dilate_small_std dilate mismatch count=%0d first=%0d",
               final_mismatch_count, final_first_mismatch_idx);
    end
    $display("tb_gray_threshold_dilate_small_std passed.");
    $finish;
end

endmodule
