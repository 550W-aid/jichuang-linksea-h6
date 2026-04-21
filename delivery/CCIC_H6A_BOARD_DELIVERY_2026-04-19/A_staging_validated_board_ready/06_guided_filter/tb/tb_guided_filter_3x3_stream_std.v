`timescale 1ns / 1ps

module tb_guided_filter_3x3_stream_std;

localparam integer MAX_LANES  = 1;
localparam integer PIX_W_IN   = 24;
localparam integer PIX_W_OUT  = 8;
localparam integer WIDTH      = 3;
localparam integer HEIGHT     = 3;
localparam integer PIXELS     = WIDTH * HEIGHT;
localparam [7:0] EDGE_THRESH  = 8'd12;
localparam [3:0] EDGE_GAIN    = 4'd3;
localparam [3:0] FLAT_GAIN    = 4'd1;

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

function [7:0] sat_u8_ref;
    input integer value;
    begin
        if (value < 0) begin
            sat_u8_ref = 8'd0;
        end else if (value > 255) begin
            sat_u8_ref = 8'hFF;
        end else begin
            sat_u8_ref = value[7:0];
        end
    end
endfunction

function [7:0] guided_ref;
    input integer pixel_idx;
    integer row;
    integer col;
    reg [7:0] p00;
    reg [7:0] p01;
    reg [7:0] p02;
    reg [7:0] p10;
    reg [7:0] p11;
    reg [7:0] p12;
    reg [7:0] p20;
    reg [7:0] p21;
    reg [7:0] p22;
    reg [11:0] sum_all;
    reg [7:0] mean9;
    reg signed [8:0] diff;
    reg [7:0] abs_diff;
    reg [3:0] gain_sel;
    reg signed [12:0] enhanced;
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

        sum_all = p00 + p01 + p02 + p10 + p11 + p12 + p20 + p21 + p22;
        mean9 = (sum_all * 57) >> 9;
        diff = $signed({1'b0, p11}) - $signed({1'b0, mean9});
        abs_diff = diff[8] ? (~diff[7:0] + 8'd1) : diff[7:0];
        gain_sel = (abs_diff > EDGE_THRESH) ? EDGE_GAIN : FLAT_GAIN;
        enhanced = $signed({1'b0, mean9}) + ((diff * $signed({1'b0, gain_sel})) >>> 1);
        guided_ref = sat_u8_ref(enhanced);
    end
endfunction

guided_filter_3x3_stream_std #(
    .MAX_LANES (MAX_LANES),
    .IMG_WIDTH (WIDTH),
    .IMG_HEIGHT(HEIGHT),
    .EDGE_THRESH(EDGE_THRESH),
    .EDGE_GAIN  (EDGE_GAIN),
    .FLAT_GAIN  (FLAT_GAIN)
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
    gray_mem[0] = 8'd20;
    gray_mem[1] = 8'd24;
    gray_mem[2] = 8'd28;
    gray_mem[3] = 8'd22;
    gray_mem[4] = 8'd96;
    gray_mem[5] = 8'd26;
    gray_mem[6] = 8'd24;
    gray_mem[7] = 8'd28;
    gray_mem[8] = 8'd32;

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
        expected_pixel = guided_ref(out_idx);
        if ((m_keep !== 1'b1) ||
            (m_data !== expected_pixel) ||
            (m_sof !== (out_idx == 0)) ||
            (m_eol !== ((out_idx % WIDTH) == (WIDTH - 1))) ||
            (m_eof !== (out_idx == (PIXELS - 1)))) begin
            mismatch_count = mismatch_count + 1;
            if (first_mismatch_idx < 0) begin
                first_mismatch_idx = out_idx;
            end
            $display(
                "guided mismatch idx=%0d got=%0d exp=%0d keep=%b sof=%0d eol=%0d eof=%0d",
                out_idx,
                m_data,
                expected_pixel,
                m_keep,
                m_sof,
                m_eol,
                m_eof
            );
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
        $fatal(1, "tb_guided_filter_3x3_stream_std mismatch count=%0d first=%0d",
               mismatch_count, first_mismatch_idx);
    end
    $display("tb_guided_filter_3x3_stream_std passed.");
    $finish;
end

endmodule
