`timescale 1ns / 1ps

module tb_gray_window_median_std;

localparam integer MAX_LANES      = 1;
localparam integer PIX_W_IN       = 24;
localparam integer PIX_W_GRAY     = 8;
localparam integer PIX_W_WINDOW   = 72;
localparam integer WIDTH          = 1440;
localparam integer HEIGHT         = 1920;
localparam integer PIXELS         = WIDTH * HEIGHT;
localparam integer CLK_HALF       = 5;
localparam integer TIMEOUT_CYCLES = 6000000;

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
integer sort_i;
integer sort_j;

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

reg  [7:0] expected_gray;
reg  [7:0] expected_final;
reg  [71:0] expected_window_value;

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

function [7:0] median9;
    input [71:0] window;
    reg [7:0] local_buf [0:8];
    reg [7:0] local_tmp;
    begin
        for (sort_i = 0; sort_i < 9; sort_i = sort_i + 1) begin
            local_buf[sort_i] = window[(8 - sort_i)*8 +: 8];
        end
        for (sort_i = 0; sort_i < 9; sort_i = sort_i + 1) begin
            for (sort_j = sort_i + 1; sort_j < 9; sort_j = sort_j + 1) begin
                if (local_buf[sort_i] > local_buf[sort_j]) begin
                    local_tmp = local_buf[sort_i];
                    local_buf[sort_i] = local_buf[sort_j];
                    local_buf[sort_j] = local_tmp;
                end
            end
        end
        median9 = local_buf[4];
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

median3x3_stream_std #(
    .MAX_LANES(MAX_LANES),
    .DATA_W   (PIX_W_GRAY)
) u_median (
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

    $readmemh("face_input_1440x1920_rgb888.hex", rgb_mem);

    file_gray = $fopen("sim_gray_window_median_gray.hex", "w");
    file_window = $fopen("sim_gray_window_median_window.hex", "w");
    file_final = $fopen("sim_gray_window_median_final.hex", "w");
    if ((file_gray == 0) || (file_window == 0) || (file_final == 0)) begin
        $error("tb_gray_window_median_std failed to open output files.");
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

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gray_idx <= 0;
    end else if (gray_valid && gray_ready) begin
        expected_gray = rgb888_to_gray8(rgb_mem[gray_idx]);
        $fwrite(file_gray, "%02h\n", gray_data);

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
        $fwrite(file_window, "%018h\n", window_data);

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
        expected_final = median9(expected_window(final_idx));
        $fwrite(file_final, "%02h\n", final_data);

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

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timeout_count <= 0;
    end else if (!done) begin
        timeout_count <= timeout_count + 1;
        if (timeout_count > TIMEOUT_CYCLES) begin
            $error("tb_gray_window_median_std timeout.");
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

    if (gray_mismatch_count != 0) begin
        $display("gray first mismatch index = %0d", gray_first_mismatch_idx);
        $fatal(1, "gray mismatch count = %0d", gray_mismatch_count);
    end
    if (window_mismatch_count != 0) begin
        $display("window first mismatch index = %0d", window_first_mismatch_idx);
        $fatal(1, "window mismatch count = %0d", window_mismatch_count);
    end
    if (final_mismatch_count != 0) begin
        $display("median first mismatch index = %0d", final_first_mismatch_idx);
        $fatal(1, "median mismatch count = %0d", final_mismatch_count);
    end

    $display("tb_gray_window_median_std passed with %0d pixels.", PIXELS);
    $finish;
end

endmodule
