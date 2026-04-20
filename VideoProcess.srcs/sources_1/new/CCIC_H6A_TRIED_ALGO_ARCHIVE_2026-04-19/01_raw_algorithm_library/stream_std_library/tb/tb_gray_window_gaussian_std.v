`timescale 1ns / 1ps

module tb_gray_window_gaussian_std #(
    parameter integer MAX_LANES            = 1,
    parameter integer PIX_W_IN             = 24,
    parameter integer PIX_W_GRAY           = 8,
    parameter integer PIX_W_WINDOW         = 72,
    parameter integer WIDTH                = 1440,
    parameter integer HEIGHT               = 1920,
    parameter integer CLK_HALF             = 5,
    parameter integer TIMEOUT_CYCLES       = 0,
    parameter integer USE_SYNTHETIC_PATTERN = 0
);

localparam integer PIXELS                  = WIDTH * HEIGHT;
localparam integer EFFECTIVE_TIMEOUT_CYCLES = (TIMEOUT_CYCLES > 0) ? TIMEOUT_CYCLES : (PIXELS * 4 + 1000);

integer init_idx;
integer timeout_count;

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

integer file_gray;
integer file_window;
integer file_final;

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

reg  [23:0] rgb_mem [0:PIXELS-1];
reg  [7:0]  expected_gray;
reg  [71:0] expected_window_value;
reg  [7:0]  expected_final;

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

function [7:0] gaussian9;
    input [71:0] window;
    reg [11:0] weighted_sum;
    reg [7:0] p0;
    reg [7:0] p1;
    reg [7:0] p2;
    reg [7:0] p3;
    reg [7:0] p4;
    reg [7:0] p5;
    reg [7:0] p6;
    reg [7:0] p7;
    reg [7:0] p8;
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

        weighted_sum = p0 + (p1 << 1) + p2 +
                       (p3 << 1) + (p4 << 2) + (p5 << 1) +
                        p6 + (p7 << 1) + p8;
        gaussian9 = weighted_sum[11:4];
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

gaussian3x3_stream_std #(
    .MAX_LANES(MAX_LANES),
    .DATA_W   (PIX_W_GRAY)
) u_gaussian (
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
    forever #CLK_HALF clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    done = 1'b0;
    final_ready = 1'b1;
    timeout_count = 0;

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

    if (USE_SYNTHETIC_PATTERN != 0) begin
        for (init_idx = 0; init_idx < PIXELS; init_idx = init_idx + 1) begin
            rgb_mem[init_idx] = {
                (init_idx * 8'd13 + 8'd17) & 8'hFF,
                (init_idx * 8'd7  + 8'd33) & 8'hFF,
                (init_idx * 8'd3  + 8'd91) & 8'hFF
            };
        end
        $display("tb_gray_window_gaussian_std using synthetic pattern, %0dx%0d", WIDTH, HEIGHT);
    end else begin
        $readmemh("face_input_1440x1920_rgb888.hex", rgb_mem);
        $display("tb_gray_window_gaussian_std using face_input_1440x1920_rgb888.hex with logical size %0dx%0d", WIDTH, HEIGHT);
    end

    file_gray = $fopen("sim_gray_window_gaussian_gray.hex", "w");
    file_window = $fopen("sim_gray_window_gaussian_window.hex", "w");
    file_final = $fopen("sim_gray_window_gaussian_final.hex", "w");
    if ((file_gray == 0) || (file_window == 0) || (file_final == 0)) begin
        $error("tb_gray_window_gaussian_std failed to open output files.");
        $finish;
    end

    #50;
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
        s_keep  = {{(MAX_LANES-1){1'b0}}, 1'b1};
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

always @(posedge clk) begin
    if (gray_valid && gray_ready) begin
        expected_gray = rgb888_to_gray8(rgb_mem[gray_idx]);
        $fwrite(file_gray, "%02h\n", gray_data);

        if (gray_data !== expected_gray) begin
            gray_mismatch_count <= gray_mismatch_count + 1;
            if (gray_first_mismatch_idx < 0) begin
                gray_first_mismatch_idx <= gray_idx;
            end
            $display("gaussian tb gray mismatch idx=%0d got=%02h exp=%02h", gray_idx, gray_data, expected_gray);
        end
        if (gray_keep !== {{(MAX_LANES-1){1'b0}}, 1'b1}) begin
            $fatal(1, "gaussian tb gray keep mismatch idx=%0d got=%b", gray_idx, gray_keep);
        end
        if ((gray_idx == 0) && !gray_sof) begin
            $fatal(1, "gaussian tb gray missing sof on first pixel");
        end
        if (((gray_idx % WIDTH) == (WIDTH - 1)) && !gray_eol) begin
            $fatal(1, "gaussian tb gray missing eol at idx=%0d", gray_idx);
        end
        if ((gray_idx == (PIXELS - 1)) && !gray_eof) begin
            $fatal(1, "gaussian tb gray missing eof on last pixel");
        end

        gray_idx <= gray_idx + 1;
    end

    if (window_valid && window_ready) begin
        expected_window_value = expected_window(window_idx);
        $fwrite(file_window, "%018h\n", window_data);

        if (window_data !== expected_window_value) begin
            window_mismatch_count <= window_mismatch_count + 1;
            if (window_first_mismatch_idx < 0) begin
                window_first_mismatch_idx <= window_idx;
            end
            $display("gaussian tb window mismatch idx=%0d got=%018h exp=%018h", window_idx, window_data, expected_window_value);
        end
        if (window_keep !== {{(MAX_LANES-1){1'b0}}, 1'b1}) begin
            $fatal(1, "gaussian tb window keep mismatch idx=%0d got=%b", window_idx, window_keep);
        end
        if ((window_idx == 0) && !window_sof) begin
            $fatal(1, "gaussian tb window missing sof on first pixel");
        end
        if (((window_idx % WIDTH) == (WIDTH - 1)) && !window_eol) begin
            $fatal(1, "gaussian tb window missing eol at idx=%0d", window_idx);
        end
        if ((window_idx == (PIXELS - 1)) && !window_eof) begin
            $fatal(1, "gaussian tb window missing eof on last pixel");
        end

        window_idx <= window_idx + 1;
    end

    if (final_valid && final_ready) begin
        expected_final = gaussian9(expected_window(final_idx));
        $fwrite(file_final, "%02h\n", final_data);

        if (final_data !== expected_final) begin
            final_mismatch_count <= final_mismatch_count + 1;
            if (final_first_mismatch_idx < 0) begin
                final_first_mismatch_idx <= final_idx;
            end
            $display("gaussian tb final mismatch idx=%0d got=%02h exp=%02h", final_idx, final_data, expected_final);
        end
        if (final_keep !== {{(MAX_LANES-1){1'b0}}, 1'b1}) begin
            $fatal(1, "gaussian tb final keep mismatch idx=%0d got=%b", final_idx, final_keep);
        end
        if ((final_idx == 0) && !final_sof) begin
            $fatal(1, "gaussian tb final missing sof on first pixel");
        end
        if (((final_idx % WIDTH) == (WIDTH - 1)) && !final_eol) begin
            $fatal(1, "gaussian tb final missing eol at idx=%0d", final_idx);
        end
        if ((final_idx == (PIXELS - 1)) && !final_eof) begin
            $fatal(1, "gaussian tb final missing eof on last pixel");
        end

        if (final_idx == (PIXELS - 1)) begin
            done <= 1'b1;
        end
        final_idx <= final_idx + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timeout_count <= 0;
    end else if (!done) begin
        timeout_count <= timeout_count + 1;
        if (timeout_count > EFFECTIVE_TIMEOUT_CYCLES) begin
            $error("tb_gray_window_gaussian_std timeout.");
            $finish;
        end
    end
end

initial begin
    wait (done == 1'b1);
    #20;
    $fclose(file_gray);
    $fclose(file_window);
    $fclose(file_final);

    if ((gray_mismatch_count != 0) || (window_mismatch_count != 0) || (final_mismatch_count != 0)) begin
        $fatal(
            1,
            "tb_gray_window_gaussian_std failed: gray=%0d(first=%0d) window=%0d(first=%0d) final=%0d(first=%0d)",
            gray_mismatch_count,
            gray_first_mismatch_idx,
            window_mismatch_count,
            window_first_mismatch_idx,
            final_mismatch_count,
            final_first_mismatch_idx
        );
    end

    $display("tb_gray_window_gaussian_std passed with %0d pixels.", PIXELS);
    $finish;
end

endmodule
