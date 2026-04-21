`timescale 1ns / 1ps

module tb_bilinear_resize_realtime_stream_std_backpressure;

localparam integer MAX_LANES  = 1;
localparam integer IMG_WIDTH  = 4;
localparam integer IMG_HEIGHT = 4;
localparam integer OUT_WIDTH  = 3;
localparam integer OUT_HEIGHT = 3;
localparam integer IN_PIXELS  = IMG_WIDTH * IMG_HEIGHT;
localparam integer OUT_PIXELS = OUT_WIDTH * OUT_HEIGHT;
localparam [31:0] SCALE_X_FP  = ((IMG_WIDTH  - 1) << 16) / (OUT_WIDTH  - 1);
localparam [31:0] SCALE_Y_FP  = ((IMG_HEIGHT - 1) << 16) / (OUT_HEIGHT - 1);

integer in_idx;
integer out_idx;
integer wait_cycles;

reg                    clk;
reg                    rst_n;
reg                    cfg_valid;
wire                   cfg_ready;
reg  [15:0]            cfg_out_width;
reg  [15:0]            cfg_out_height;
reg  [31:0]            cfg_scale_x_fp;
reg  [31:0]            cfg_scale_y_fp;
reg                    s_valid;
wire                   s_ready;
reg  [23:0]            s_data;
reg                    s_keep;
reg                    s_sof;
reg                    s_eol;
reg                    s_eof;
wire                   m_valid;
reg                    m_ready;
wire [23:0]            m_data;
wire                   m_keep;
wire                   m_sof;
wire                   m_eol;
wire                   m_eof;

reg [23:0] pixel_mem [0:IN_PIXELS-1];

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

function [7:0] bilinear_mix_ch;
    input [7:0] p00;
    input [7:0] p01;
    input [7:0] p10;
    input [7:0] p11;
    input integer fx;
    input integer fy;
    integer inv_fx;
    integer inv_fy;
    integer top_mix;
    integer bot_mix;
    integer mix_all;
    begin
        inv_fx = 256 - fx;
        inv_fy = 256 - fy;
        top_mix = (p00 * inv_fx) + (p01 * fx);
        bot_mix = (p10 * inv_fx) + (p11 * fx);
        mix_all = (top_mix * inv_fy) + (bot_mix * fy);
        bilinear_mix_ch = (mix_all >>> 16) & 8'hFF;
    end
endfunction

function [23:0] expected_rgb;
    input integer target_idx;
    integer tx;
    integer ty;
    integer src_x_fp_v;
    integer src_y_fp_v;
    integer src_x0_v;
    integer src_x1_v;
    integer src_y0_v;
    integer src_y1_v;
    integer fx_v;
    integer fy_v;
    reg [23:0] p00_v;
    reg [23:0] p01_v;
    reg [23:0] p10_v;
    reg [23:0] p11_v;
    begin
        tx = target_idx % OUT_WIDTH;
        ty = target_idx / OUT_WIDTH;

        src_x_fp_v = tx * SCALE_X_FP;
        src_y_fp_v = ty * SCALE_Y_FP;
        src_x0_v = src_x_fp_v >>> 16;
        src_y0_v = src_y_fp_v >>> 16;
        src_x1_v = clamp_idx(src_x0_v + 1, 0, IMG_WIDTH - 1);
        src_y1_v = clamp_idx(src_y0_v + 1, 0, IMG_HEIGHT - 1);
        fx_v = (src_x_fp_v >> 8) & 8'hFF;
        fy_v = (src_y_fp_v >> 8) & 8'hFF;

        p00_v = pixel_mem[src_y0_v*IMG_WIDTH + src_x0_v];
        p01_v = pixel_mem[src_y0_v*IMG_WIDTH + src_x1_v];
        p10_v = pixel_mem[src_y1_v*IMG_WIDTH + src_x0_v];
        p11_v = pixel_mem[src_y1_v*IMG_WIDTH + src_x1_v];

        expected_rgb[23:16] = bilinear_mix_ch(p00_v[23:16], p01_v[23:16], p10_v[23:16], p11_v[23:16], fx_v, fy_v);
        expected_rgb[15:8]  = bilinear_mix_ch(p00_v[15:8],  p01_v[15:8],  p10_v[15:8],  p11_v[15:8],  fx_v, fy_v);
        expected_rgb[7:0]   = bilinear_mix_ch(p00_v[7:0],   p01_v[7:0],   p10_v[7:0],   p11_v[7:0],   fx_v, fy_v);
    end
endfunction

task wait_for_output;
    begin
        wait_cycles = 0;
        while (!m_valid) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
            if (wait_cycles > 300) begin
                $fatal(1, "Timed out waiting for realtime resize output.");
            end
        end
    end
endtask

task check_current_output;
    input integer pixel_idx;
    begin
        if (m_data !== expected_rgb(pixel_idx)) begin
            $fatal(1, "Pixel mismatch at idx=%0d got=%06h expected=%06h",
                   pixel_idx, m_data, expected_rgb(pixel_idx));
        end
        if (m_keep !== 1'b1) begin
            $fatal(1, "Keep mismatch at idx=%0d got=%b", pixel_idx, m_keep);
        end
        if (m_sof !== (pixel_idx == 0)) begin
            $fatal(1, "SOF mismatch at idx=%0d", pixel_idx);
        end
        if (m_eol !== ((pixel_idx % OUT_WIDTH) == (OUT_WIDTH - 1))) begin
            $fatal(1, "EOL mismatch at idx=%0d", pixel_idx);
        end
        if (m_eof !== (pixel_idx == (OUT_PIXELS - 1))) begin
            $fatal(1, "EOF mismatch at idx=%0d", pixel_idx);
        end
    end
endtask

task stall_and_consume;
    input integer pixel_idx;
    begin
        wait_for_output();
        check_current_output(pixel_idx);
        repeat (2) begin
            @(posedge clk);
            if (!m_valid) begin
                $fatal(1, "Output lost valid during backpressure at idx=%0d", pixel_idx);
            end
            check_current_output(pixel_idx);
            if (s_ready) begin
                $fatal(1, "Input should be stalled during output backpressure at idx=%0d", pixel_idx);
            end
        end
        @(negedge clk);
        m_ready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        m_ready = 1'b0;
    end
endtask

bilinear_resize_realtime_stream_std #(
    .MAX_LANES (MAX_LANES),
    .IMG_WIDTH (IMG_WIDTH),
    .IMG_HEIGHT(IMG_HEIGHT),
    .OUT_WIDTH (OUT_WIDTH),
    .OUT_HEIGHT(OUT_HEIGHT)
) dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .s_valid        (s_valid),
    .s_ready        (s_ready),
    .s_data         (s_data),
    .s_keep         (s_keep),
    .s_sof          (s_sof),
    .s_eol          (s_eol),
    .s_eof          (s_eof),
    .cfg_valid      (cfg_valid),
    .cfg_ready      (cfg_ready),
    .cfg_out_width  (cfg_out_width),
    .cfg_out_height (cfg_out_height),
    .cfg_scale_x_fp (cfg_scale_x_fp),
    .cfg_scale_y_fp (cfg_scale_y_fp),
    .m_valid        (m_valid),
    .m_ready        (m_ready),
    .m_data         (m_data),
    .m_keep         (m_keep),
    .m_sof          (m_sof),
    .m_eol          (m_eol),
    .m_eof          (m_eof)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    pixel_mem[0]  = 24'h10_20_30;
    pixel_mem[1]  = 24'h20_30_40;
    pixel_mem[2]  = 24'h30_40_50;
    pixel_mem[3]  = 24'h40_50_60;
    pixel_mem[4]  = 24'h20_40_60;
    pixel_mem[5]  = 24'h30_50_70;
    pixel_mem[6]  = 24'h40_60_80;
    pixel_mem[7]  = 24'h50_70_90;
    pixel_mem[8]  = 24'h30_60_90;
    pixel_mem[9]  = 24'h40_70_A0;
    pixel_mem[10] = 24'h50_80_B0;
    pixel_mem[11] = 24'h60_90_C0;
    pixel_mem[12] = 24'h40_80_C0;
    pixel_mem[13] = 24'h50_90_D0;
    pixel_mem[14] = 24'h60_A0_E0;
    pixel_mem[15] = 24'h70_B0_F0;

    rst_n = 1'b0;
    cfg_valid = 1'b0;
    cfg_out_width = OUT_WIDTH[15:0];
    cfg_out_height = OUT_HEIGHT[15:0];
    cfg_scale_x_fp = SCALE_X_FP;
    cfg_scale_y_fp = SCALE_Y_FP;
    s_valid = 1'b0;
    s_data = 24'd0;
    s_keep = 1'b0;
    s_sof = 1'b0;
    s_eol = 1'b0;
    s_eof = 1'b0;
    m_ready = 1'b0;
    in_idx = 0;
    out_idx = 0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    @(negedge clk);
    cfg_valid = 1'b1;
    @(negedge clk);
    cfg_valid = 1'b0;
end

always @* begin
    s_valid = 1'b0;
    s_data  = 24'd0;
    s_keep  = 1'b0;
    s_sof   = 1'b0;
    s_eol   = 1'b0;
    s_eof   = 1'b0;

    if (rst_n && (in_idx < IN_PIXELS)) begin
        s_valid = 1'b1;
        s_data  = pixel_mem[in_idx];
        s_keep  = 1'b1;
        s_sof   = (in_idx == 0);
        s_eol   = ((in_idx % IMG_WIDTH) == (IMG_WIDTH - 1));
        s_eof   = (in_idx == (IN_PIXELS - 1));
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_idx <= 0;
    end else if (s_valid && s_ready) begin
        in_idx <= in_idx + 1;
    end
end

initial begin
    wait (rst_n == 1'b1);

    stall_and_consume(0);
    stall_and_consume(1);
    stall_and_consume(2);
    stall_and_consume(3);
    stall_and_consume(4);
    stall_and_consume(5);
    stall_and_consume(6);
    stall_and_consume(7);
    stall_and_consume(8);

    $display("tb_bilinear_resize_realtime_stream_std_backpressure passed.");
    $finish;
end

endmodule
