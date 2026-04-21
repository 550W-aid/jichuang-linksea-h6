`timescale 1ns / 1ps

module tb_gray_threshold_small_std;

localparam integer MAX_LANES  = 1;
localparam integer PIX_W_IN   = 24;
localparam integer PIX_W_GRAY = 8;
localparam integer WIDTH      = 4;
localparam integer HEIGHT     = 3;
localparam integer PIXELS     = WIDTH * HEIGHT;
localparam [7:0] THRESHOLD    = 8'd8;

integer in_idx;
integer gray_idx;
integer final_idx;
integer gray_mismatch_count;
integer final_mismatch_count;
integer gray_first_mismatch_idx;
integer final_first_mismatch_idx;

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

wire                        final_valid;
wire [PIX_W_GRAY-1:0]       final_data;
wire [MAX_LANES-1:0]        final_keep;
wire                        final_sof;
wire                        final_eol;
wire                        final_eof;

reg [23:0] rgb_mem [0:PIXELS-1];
reg [7:0] expected_gray;
reg [7:0] expected_final;

function [7:0] expected_binary;
    input integer pixel_idx;
    begin
        expected_binary = (rgb_mem[pixel_idx][7:0] >= THRESHOLD) ? 8'hFF : 8'h00;
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
    final_idx = 0;
    gray_mismatch_count = 0;
    final_mismatch_count = 0;
    gray_first_mismatch_idx = -1;
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
        expected_gray = rgb_mem[gray_idx][7:0];
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
        final_idx <= 0;
        done <= 1'b0;
    end else if (final_valid && final_ready) begin
        expected_final = expected_binary(final_idx);
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
        $fatal(1, "tb_gray_threshold_small_std gray mismatch count=%0d first=%0d",
               gray_mismatch_count, gray_first_mismatch_idx);
    end
    if (final_mismatch_count != 0) begin
        $fatal(1, "tb_gray_threshold_small_std threshold mismatch count=%0d first=%0d",
               final_mismatch_count, final_first_mismatch_idx);
    end
    $display("tb_gray_threshold_small_std passed.");
    $finish;
end

endmodule
