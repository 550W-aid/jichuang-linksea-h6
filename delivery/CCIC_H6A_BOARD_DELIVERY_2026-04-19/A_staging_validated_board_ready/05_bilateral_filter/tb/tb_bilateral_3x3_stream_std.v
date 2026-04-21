`timescale 1ns / 1ps

module tb_bilateral_3x3_stream_std;

localparam integer MAX_LANES   = 1;
localparam integer PIX_W_IN    = 24;
localparam integer PIX_W_OUT   = 8;
localparam integer WIDTH       = 3;
localparam integer HEIGHT      = 3;
localparam integer PIXELS      = WIDTH * HEIGHT;
localparam integer RANGE_SHIFT = 4;

integer in_idx;
integer out_idx;
integer mismatch_count;
integer first_mismatch_idx;

reg clk;
reg rst_n;
reg done;
reg m_ready;

reg                     s_valid;
wire                    s_ready;
reg  [PIX_W_IN-1:0]     s_data;
reg  [MAX_LANES-1:0]    s_keep;
reg                     s_sof;
reg                     s_eol;
reg                     s_eof;
wire                    m_valid;
wire [PIX_W_OUT-1:0]    m_data;
wire [MAX_LANES-1:0]    m_keep;
wire                    m_sof;
wire                    m_eol;
wire                    m_eof;

reg [7:0] gray_mem [0:PIXELS-1];
reg [7:0] expected_pixel;

function [7:0] sample_gray;
    input integer row;
    input integer col;
    integer clamped_row;
    integer clamped_col;
    begin
        clamped_row = row;
        clamped_col = col;
        if (clamped_row < 0) begin
            clamped_row = 0;
        end else if (clamped_row >= HEIGHT) begin
            clamped_row = HEIGHT - 1;
        end
        if (clamped_col < 0) begin
            clamped_col = 0;
        end else if (clamped_col >= WIDTH) begin
            clamped_col = WIDTH - 1;
        end
        sample_gray = gray_mem[clamped_row * WIDTH + clamped_col];
    end
endfunction

function [7:0] bilateral_ref;
    input integer pixel_idx;
    integer row;
    integer col;
    integer center;
    integer p00;
    integer p01;
    integer p02;
    integer p10;
    integer p11;
    integer p12;
    integer p20;
    integer p21;
    integer p22;
    integer weighted_sum;
    integer weight_sum;
    integer range_w;
    begin
        row = pixel_idx / WIDTH;
        col = pixel_idx % WIDTH;

        p00 = sample_gray(row - 1, col - 1);
        p01 = sample_gray(row - 1, col);
        p02 = sample_gray(row - 1, col + 1);
        p10 = sample_gray(row,     col - 1);
        p11 = sample_gray(row,     col);
        p12 = sample_gray(row,     col + 1);
        p20 = sample_gray(row + 1, col - 1);
        p21 = sample_gray(row + 1, col);
        p22 = sample_gray(row + 1, col + 1);
        center = p11;

        weighted_sum = 0;
        weight_sum   = 0;

        range_w = 16 - ((p00 > center) ? ((p00 - center) >> RANGE_SHIFT) : ((center - p00) >> RANGE_SHIFT));
        weighted_sum = weighted_sum + p00 * 1 * range_w;
        weight_sum   = weight_sum   + 1 * range_w;
        range_w = 16 - ((p01 > center) ? ((p01 - center) >> RANGE_SHIFT) : ((center - p01) >> RANGE_SHIFT));
        weighted_sum = weighted_sum + p01 * 2 * range_w;
        weight_sum   = weight_sum   + 2 * range_w;
        range_w = 16 - ((p02 > center) ? ((p02 - center) >> RANGE_SHIFT) : ((center - p02) >> RANGE_SHIFT));
        weighted_sum = weighted_sum + p02 * 1 * range_w;
        weight_sum   = weight_sum   + 1 * range_w;
        range_w = 16 - ((p10 > center) ? ((p10 - center) >> RANGE_SHIFT) : ((center - p10) >> RANGE_SHIFT));
        weighted_sum = weighted_sum + p10 * 2 * range_w;
        weight_sum   = weight_sum   + 2 * range_w;
        range_w = 16 - ((p11 > center) ? ((p11 - center) >> RANGE_SHIFT) : ((center - p11) >> RANGE_SHIFT));
        weighted_sum = weighted_sum + p11 * 4 * range_w;
        weight_sum   = weight_sum   + 4 * range_w;
        range_w = 16 - ((p12 > center) ? ((p12 - center) >> RANGE_SHIFT) : ((center - p12) >> RANGE_SHIFT));
        weighted_sum = weighted_sum + p12 * 2 * range_w;
        weight_sum   = weight_sum   + 2 * range_w;
        range_w = 16 - ((p20 > center) ? ((p20 - center) >> RANGE_SHIFT) : ((center - p20) >> RANGE_SHIFT));
        weighted_sum = weighted_sum + p20 * 1 * range_w;
        weight_sum   = weight_sum   + 1 * range_w;
        range_w = 16 - ((p21 > center) ? ((p21 - center) >> RANGE_SHIFT) : ((center - p21) >> RANGE_SHIFT));
        weighted_sum = weighted_sum + p21 * 2 * range_w;
        weight_sum   = weight_sum   + 2 * range_w;
        range_w = 16 - ((p22 > center) ? ((p22 - center) >> RANGE_SHIFT) : ((center - p22) >> RANGE_SHIFT));
        weighted_sum = weighted_sum + p22 * 1 * range_w;
        weight_sum   = weight_sum   + 1 * range_w;

        if (weight_sum == 0) begin
            bilateral_ref = center;
        end else begin
            bilateral_ref = weighted_sum / weight_sum;
        end
    end
endfunction

bilateral_3x3_stream_std #(
    .MAX_LANES  (MAX_LANES),
    .IMG_WIDTH  (WIDTH),
    .IMG_HEIGHT (HEIGHT),
    .RANGE_SHIFT(RANGE_SHIFT)
) dut (
    .clk    (clk),
    .rst_n  (rst_n),
    .s_valid(s_valid),
    .s_ready(s_ready),
    .s_data (s_data),
    .s_keep (s_keep),
    .s_sof  (s_sof),
    .s_eol  (s_eol),
    .s_eof  (s_eof),
    .m_valid(m_valid),
    .m_ready(m_ready),
    .m_data (m_data),
    .m_keep (m_keep),
    .m_sof  (m_sof),
    .m_eol  (m_eol),
    .m_eof  (m_eof)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    gray_mem[0] = 8'd10;
    gray_mem[1] = 8'd20;
    gray_mem[2] = 8'd30;
    gray_mem[3] = 8'd40;
    gray_mem[4] = 8'd80;
    gray_mem[5] = 8'd60;
    gray_mem[6] = 8'd70;
    gray_mem[7] = 8'd90;
    gray_mem[8] = 8'd100;

    rst_n = 1'b0;
    done = 1'b0;
    m_ready = 1'b1;
    in_idx = 0;
    out_idx = 0;
    mismatch_count = 0;
    first_mismatch_idx = -1;

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
        s_data  = {gray_mem[in_idx], gray_mem[in_idx], gray_mem[in_idx]};
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
        out_idx <= 0;
        done <= 1'b0;
    end else if (m_valid && m_ready) begin
        expected_pixel = bilateral_ref(out_idx);
        if ((m_keep !== 1'b1) ||
            (m_data !== expected_pixel) ||
            (m_sof !== (out_idx == 0)) ||
            (m_eol !== ((out_idx % WIDTH) == (WIDTH - 1))) ||
            (m_eof !== (out_idx == (PIXELS - 1)))) begin
            mismatch_count = mismatch_count + 1;
            if (first_mismatch_idx < 0) begin
                first_mismatch_idx = out_idx;
            end
        end
        if (out_idx == (PIXELS - 1)) begin
            done <= 1'b1;
        end
        out_idx <= out_idx + 1;
    end
end

initial begin
    wait (done == 1'b1);
    #20;
    if (mismatch_count != 0) begin
        $fatal(1, "tb_bilateral_3x3_stream_std mismatch count=%0d first=%0d",
               mismatch_count, first_mismatch_idx);
    end
    $display("tb_bilateral_3x3_stream_std passed.");
    $finish;
end

endmodule
