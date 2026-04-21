`timescale 1ns / 1ps

module tb_window3x3_stream_std_unit;

localparam integer MAX_LANES = 1;
localparam integer DATA_W    = 8;
localparam integer WIDTH     = 4;
localparam integer HEIGHT    = 3;
localparam integer PIXELS    = WIDTH * HEIGHT;

integer in_idx;
integer out_idx;
integer mismatch_count;
integer first_mismatch_idx;
integer i;

reg clk;
reg rst_n;

reg                          s_valid;
wire                         s_ready;
reg  [MAX_LANES*DATA_W-1:0]  s_data;
reg  [MAX_LANES-1:0]         s_keep;
reg                          s_sof;
reg                          s_eol;
reg                          s_eof;

wire                         m_valid;
reg                          m_ready;
wire [MAX_LANES*DATA_W*9-1:0] m_data;
wire [MAX_LANES-1:0]         m_keep;
wire                         m_sof;
wire                         m_eol;
wire                         m_eof;

reg [DATA_W-1:0] img_mem [0:PIXELS-1];
reg [DATA_W*9-1:0] expected_win;

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

function [DATA_W*9-1:0] expected_window;
    input integer pixel_idx;
    integer center_row;
    integer center_col;
    integer tap_row;
    integer tap_col;
    integer src_row;
    integer src_col;
    integer tap_idx;
    reg [DATA_W*9-1:0] tmp;
    begin
        center_row = pixel_idx / WIDTH;
        center_col = pixel_idx % WIDTH;
        tmp = {(DATA_W*9){1'b0}};
        tap_idx = 0;
        for (tap_row = -1; tap_row <= 1; tap_row = tap_row + 1) begin
            for (tap_col = -1; tap_col <= 1; tap_col = tap_col + 1) begin
                src_row = clamp_idx(center_row + tap_row, 0, HEIGHT - 1);
                src_col = clamp_idx(center_col + tap_col, 0, WIDTH - 1);
                tmp[(8 - tap_idx)*DATA_W +: DATA_W] = img_mem[src_row*WIDTH + src_col];
                tap_idx = tap_idx + 1;
            end
        end
        expected_window = tmp;
    end
endfunction

window3x3_stream_std #(
    .MAX_LANES (MAX_LANES),
    .DATA_W    (DATA_W),
    .IMG_WIDTH (WIDTH),
    .IMG_HEIGHT(HEIGHT)
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
    img_mem[0]  = 8'h01;
    img_mem[1]  = 8'h02;
    img_mem[2]  = 8'h03;
    img_mem[3]  = 8'h04;
    img_mem[4]  = 8'h05;
    img_mem[5]  = 8'h06;
    img_mem[6]  = 8'h07;
    img_mem[7]  = 8'h08;
    img_mem[8]  = 8'h09;
    img_mem[9]  = 8'h0A;
    img_mem[10] = 8'h0B;
    img_mem[11] = 8'h0C;

    rst_n = 1'b0;
    m_ready = 1'b1;
    in_idx = 0;
    out_idx = 0;
    mismatch_count = 0;
    first_mismatch_idx = -1;

    #30;
    rst_n = 1'b1;
end

always @* begin
    s_valid = 1'b0;
    s_data  = {DATA_W{1'b0}};
    s_keep  = 1'b0;
    s_sof   = 1'b0;
    s_eol   = 1'b0;
    s_eof   = 1'b0;

    if (rst_n && (in_idx < PIXELS)) begin
        s_valid = 1'b1;
        s_data  = img_mem[in_idx];
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
    end else if (m_valid && m_ready) begin
        expected_win = expected_window(out_idx);
        if (m_keep !== 1'b1) begin
            mismatch_count = mismatch_count + 1;
            if (first_mismatch_idx < 0) begin
                first_mismatch_idx = out_idx;
            end
        end
        if (m_data !== expected_win) begin
            mismatch_count = mismatch_count + 1;
            if (first_mismatch_idx < 0) begin
                first_mismatch_idx = out_idx;
            end
        end
        if (m_sof !== (out_idx == 0)) begin
            mismatch_count = mismatch_count + 1;
            if (first_mismatch_idx < 0) begin
                first_mismatch_idx = out_idx;
            end
        end
        if (m_eol !== ((out_idx % WIDTH) == (WIDTH - 1))) begin
            mismatch_count = mismatch_count + 1;
            if (first_mismatch_idx < 0) begin
                first_mismatch_idx = out_idx;
            end
        end
        if (m_eof !== (out_idx == (PIXELS - 1))) begin
            mismatch_count = mismatch_count + 1;
            if (first_mismatch_idx < 0) begin
                first_mismatch_idx = out_idx;
            end
        end
        out_idx <= out_idx + 1;
    end
end

initial begin
    wait (rst_n == 1'b1);
    wait (out_idx == PIXELS);
    #20;
    if (mismatch_count != 0) begin
        $display("tb_window3x3_stream_std_unit first mismatch at pixel %0d", first_mismatch_idx);
        $fatal(1, "window3x3_stream_std mismatches = %0d", mismatch_count);
    end
    $display("tb_window3x3_stream_std_unit passed.");
    $finish;
end

endmodule
