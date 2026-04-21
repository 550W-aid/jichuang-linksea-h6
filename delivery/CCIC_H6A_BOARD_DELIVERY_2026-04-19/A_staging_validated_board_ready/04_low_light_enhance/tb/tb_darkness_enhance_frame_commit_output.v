`timescale 1ns / 1ps

module tb_darkness_enhance_frame_commit_output;

localparam integer MAX_LANES = 8;
localparam integer PIX_W     = 24;

integer lane_idx;
integer wait_cycles;

reg                        clk;
reg                        rst_n;
reg                        s_valid;
wire                       s_ready;
reg  [MAX_LANES*PIX_W-1:0] s_data;
reg  [MAX_LANES-1:0]       s_keep;
reg                        s_sof;
reg                        s_eol;
reg                        s_eof;
reg                        cfg_valid;
wire                       cfg_ready;
reg  signed [8:0]          cfg_brightness_offset;
wire signed [8:0]          active_brightness_offset;
wire                       m_valid;
reg                        m_ready;
wire [MAX_LANES*PIX_W-1:0] m_data;
wire [MAX_LANES-1:0]       m_keep;
wire                       m_sof;
wire                       m_eol;
wire                       m_eof;

reg [23:0] src_pixels [0:2];
reg [23:0] got_pixel;
reg [23:0] exp_pixel;

function [7:0] clamp_u8;
    input [31:0] value;
    begin
        if (value > 255) begin
            clamp_u8 = 8'hFF;
        end else begin
            clamp_u8 = value[7:0];
        end
    end
endfunction

function [23:0] rgb_to_ycbcr_ref;
    input [23:0] rgb;
    reg [31:0] y_tmp;
    reg [31:0] cb_tmp;
    reg [31:0] cr_tmp;
    begin
        y_tmp  = 32'd66  * rgb[23:16] + 32'd129 * rgb[15:8] + 32'd25  * rgb[7:0] + 32'd4096;
        cb_tmp = 32'd32768 + 32'd112 * rgb[7:0]  - 32'd38 * rgb[23:16] - 32'd74 * rgb[15:8];
        cr_tmp = 32'd32768 + 32'd112 * rgb[23:16] - 32'd94 * rgb[15:8] - 32'd18 * rgb[7:0];
        rgb_to_ycbcr_ref = {
            clamp_u8(y_tmp >> 8),
            clamp_u8(cb_tmp >> 8),
            clamp_u8(cr_tmp >> 8)
        };
    end
endfunction

function [7:0] apply_brightness_offset_ref;
    input [7:0] value;
    input signed [8:0] brightness_offset;
    reg signed [9:0] adjusted;
    begin
        adjusted = $signed({1'b0, value}) + brightness_offset;
        if (adjusted < 0) begin
            apply_brightness_offset_ref = 8'd0;
        end else if (adjusted > 10'sd255) begin
            apply_brightness_offset_ref = 8'hFF;
        end else begin
            apply_brightness_offset_ref = adjusted[7:0];
        end
    end
endfunction

function [23:0] ycbcr_to_rgb_ref;
    input [23:0] ycbcr;
    reg [31:0] r_base;
    reg [31:0] g_base;
    reg [31:0] g_sub;
    reg [31:0] b_base;
    reg [31:0] r_tmp;
    reg [31:0] g_tmp;
    reg [31:0] b_tmp;
    begin
        r_base = 32'd298 * ycbcr[23:16] + 32'd408 * ycbcr[7:0];
        g_base = 32'd298 * ycbcr[23:16] + 32'd34816;
        g_sub  = 32'd100 * ycbcr[15:8] + 32'd208 * ycbcr[7:0];
        b_base = 32'd298 * ycbcr[23:16] + 32'd516 * ycbcr[15:8];

        if (r_base <= 32'd57088) begin
            r_tmp = 32'd0;
        end else begin
            r_tmp = (r_base - 32'd57088) >> 8;
        end

        if (g_base <= g_sub) begin
            g_tmp = 32'd0;
        end else begin
            g_tmp = (g_base - g_sub) >> 8;
        end

        if (b_base <= 32'd70912) begin
            b_tmp = 32'd0;
        end else begin
            b_tmp = (b_base - 32'd70912) >> 8;
        end

        ycbcr_to_rgb_ref = {
            clamp_u8(r_tmp),
            clamp_u8(g_tmp),
            clamp_u8(b_tmp)
        };
    end
endfunction

function [23:0] expected_pixel;
    input [23:0] rgb;
    input signed [8:0] brightness_offset;
    reg [23:0] tmp_ycbcr;
    begin
        tmp_ycbcr = rgb_to_ycbcr_ref(rgb);
        tmp_ycbcr[23:16] = apply_brightness_offset_ref(
            tmp_ycbcr[23:16],
            brightness_offset
        );
        expected_pixel = ycbcr_to_rgb_ref(tmp_ycbcr);
    end
endfunction

task push_cfg;
    input signed [8:0] value;
    begin
        @(negedge clk);
        cfg_valid             = 1'b1;
        cfg_brightness_offset = value;
        @(negedge clk);
        cfg_valid             = 1'b0;
        cfg_brightness_offset = 9'sd0;
    end
endtask

task send_frame;
    begin
        @(negedge clk);
        s_valid = 1'b1;
        s_data  = {120'd0, src_pixels[2], src_pixels[1], src_pixels[0]};
        s_keep  = 8'b0000_0111;
        s_sof   = 1'b1;
        s_eol   = 1'b1;
        s_eof   = 1'b1;
        wait (s_ready);
        @(negedge clk);
        s_valid = 1'b0;
        s_data  = {MAX_LANES*PIX_W{1'b0}};
        s_keep  = {MAX_LANES{1'b0}};
        s_sof   = 1'b0;
        s_eol   = 1'b0;
        s_eof   = 1'b0;
    end
endtask

task wait_for_output;
    begin
        wait_cycles = 0;
        while (!m_valid) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
            if (wait_cycles > 64) begin
                $fatal(1, "Timeout waiting for output beat.");
            end
        end
    end
endtask

task check_output;
    input signed [8:0] expected_offset;
    begin
        if (m_keep !== 8'b0000_0111) begin
            $fatal(1, "m_keep mismatch: got %b", m_keep);
        end
        if ({m_sof, m_eol, m_eof} !== 3'b111) begin
            $fatal(
                1,
                "frame markers mismatch: sof=%0d eol=%0d eof=%0d",
                m_sof,
                m_eol,
                m_eof
            );
        end
        for (lane_idx = 0; lane_idx < 3; lane_idx = lane_idx + 1) begin
            got_pixel = m_data[lane_idx*PIX_W +: PIX_W];
            exp_pixel = expected_pixel(src_pixels[lane_idx], expected_offset);
            if (got_pixel !== exp_pixel) begin
                $fatal(
                    1,
                    "lane%0d mismatch: got %h expected %h for offset %0d",
                    lane_idx,
                    got_pixel,
                    exp_pixel,
                    expected_offset
                );
            end
        end
    end
endtask

darkness_enhance_rgb888_stream_std #(
    .MAX_LANES (MAX_LANES),
    .GAMMA_MODE(2'd0)
) dut (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .s_valid                 (s_valid),
    .s_ready                 (s_ready),
    .s_data                  (s_data),
    .s_keep                  (s_keep),
    .s_sof                   (s_sof),
    .s_eol                   (s_eol),
    .s_eof                   (s_eof),
    .cfg_valid               (cfg_valid),
    .cfg_ready               (cfg_ready),
    .cfg_brightness_offset   (cfg_brightness_offset),
    .active_brightness_offset(active_brightness_offset),
    .m_valid                 (m_valid),
    .m_ready                 (m_ready),
    .m_data                  (m_data),
    .m_keep                  (m_keep),
    .m_sof                   (m_sof),
    .m_eol                   (m_eol),
    .m_eof                   (m_eof)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    src_pixels[0] = 24'h102030;
    src_pixels[1] = 24'h406080;
    src_pixels[2] = 24'h804020;
end

initial begin
    rst_n                  = 1'b0;
    s_valid                = 1'b0;
    s_data                 = {MAX_LANES*PIX_W{1'b0}};
    s_keep                 = {MAX_LANES{1'b0}};
    s_sof                  = 1'b0;
    s_eol                  = 1'b0;
    s_eof                  = 1'b0;
    cfg_valid              = 1'b0;
    cfg_brightness_offset  = 9'sd0;
    m_ready                = 1'b1;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    push_cfg(9'sd24);
    if (active_brightness_offset !== 9'sd0) begin
        $fatal(1, "Config committed before frame start.");
    end

    send_frame();
    wait_for_output();
    if (active_brightness_offset !== 9'sd24) begin
        $fatal(1, "Frame0 config did not commit on frame start.");
    end
    check_output(9'sd24);

    push_cfg(9'sd72);
    if (active_brightness_offset !== 9'sd24) begin
        $fatal(1, "Config changed during frame gap without new frame.");
    end

    send_frame();
    wait_for_output();
    if (active_brightness_offset !== 9'sd72) begin
        $fatal(1, "Frame1 config did not commit on frame start.");
    end
    check_output(9'sd72);

    $display("tb_darkness_enhance_frame_commit_output passed.");
    $finish;
end

endmodule
