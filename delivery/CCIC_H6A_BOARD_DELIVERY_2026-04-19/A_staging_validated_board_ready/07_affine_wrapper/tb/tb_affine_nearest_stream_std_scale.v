`timescale 1ns / 1ps

module tb_affine_nearest_stream_std_scale;

localparam integer MAX_LANES  = 1;
localparam integer IMG_WIDTH  = 4;
localparam integer IMG_HEIGHT = 4;
localparam integer PIX_W      = 24;

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
reg  signed [15:0]         cfg_m00;
reg  signed [15:0]         cfg_m01;
reg  signed [15:0]         cfg_m02;
reg  signed [15:0]         cfg_m10;
reg  signed [15:0]         cfg_m11;
reg  signed [15:0]         cfg_m12;
wire signed [15:0]         active_m00;
wire signed [15:0]         active_m11;
wire                       m_valid;
reg                        m_ready;
wire [MAX_LANES*PIX_W-1:0] m_data;
wire [MAX_LANES-1:0]       m_keep;
wire                       m_sof;
wire                       m_eol;
wire                       m_eof;

task push_cfg;
    input signed [15:0] m00;
    input signed [15:0] m01;
    input signed [15:0] m02;
    input signed [15:0] m10;
    input signed [15:0] m11;
    input signed [15:0] m12;
    begin
        @(negedge clk);
        cfg_valid = 1'b1;
        cfg_m00   = m00;
        cfg_m01   = m01;
        cfg_m02   = m02;
        cfg_m10   = m10;
        cfg_m11   = m11;
        cfg_m12   = m12;
        @(negedge clk);
        cfg_valid = 1'b0;
        cfg_m00   = 16'sd0;
        cfg_m01   = 16'sd0;
        cfg_m02   = 16'sd0;
        cfg_m10   = 16'sd0;
        cfg_m11   = 16'sd0;
        cfg_m12   = 16'sd0;
    end
endtask

task send_pixel;
    input [23:0] pixel;
    input        sof;
    input        eol;
    input        eof;
    begin
        @(negedge clk);
        s_valid = 1'b1;
        s_data  = pixel;
        s_keep  = 1'b1;
        s_sof   = sof;
        s_eol   = eol;
        s_eof   = eof;
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

task send_demo_frame;
    begin
        send_pixel(24'h000001, 1'b1, 1'b0, 1'b0);
        send_pixel(24'h000002, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h000003, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h000004, 1'b0, 1'b1, 1'b0);
        send_pixel(24'h000005, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h000006, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h000007, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h000008, 1'b0, 1'b1, 1'b0);
        send_pixel(24'h000009, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h00000A, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h00000B, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h00000C, 1'b0, 1'b1, 1'b0);
        send_pixel(24'h00000D, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h00000E, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h00000F, 1'b0, 1'b0, 1'b0);
        send_pixel(24'h000010, 1'b0, 1'b1, 1'b1);
    end
endtask

task wait_for_output;
    begin
        wait_cycles = 0;
        while (!m_valid) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
            if (wait_cycles > 64) begin
                $fatal(1, "Timed out waiting for affine scale output.");
            end
        end
    end
endtask

task expect_output_pixel;
    input [23:0] pixel;
    input        sof;
    input        eol;
    input        eof;
    begin
        wait_for_output();
        if (m_data[23:0] !== pixel) begin
            $fatal(1, "Pixel mismatch. got=%06h expected=%06h", m_data[23:0], pixel);
        end
        if (m_keep !== 1'b1) begin
            $fatal(1, "Keep mismatch. got=%b expected=1", m_keep);
        end
        if ((m_sof !== sof) || (m_eol !== eol) || (m_eof !== eof)) begin
            $fatal(1,
                   "Marker mismatch. got sof/eol/eof=%b%b%b expected=%b%b%b",
                   m_sof, m_eol, m_eof, sof, eol, eof);
        end
        @(negedge clk);
        m_ready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        m_ready = 1'b0;
    end
endtask

affine_nearest_stream_std #(
    .MAX_LANES (MAX_LANES),
    .IMG_WIDTH (IMG_WIDTH),
    .IMG_HEIGHT(IMG_HEIGHT)
) dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .s_valid   (s_valid),
    .s_ready   (s_ready),
    .s_data    (s_data),
    .s_keep    (s_keep),
    .s_sof     (s_sof),
    .s_eol     (s_eol),
    .s_eof     (s_eof),
    .cfg_valid (cfg_valid),
    .cfg_ready (cfg_ready),
    .cfg_m00   (cfg_m00),
    .cfg_m01   (cfg_m01),
    .cfg_m02   (cfg_m02),
    .cfg_m10   (cfg_m10),
    .cfg_m11   (cfg_m11),
    .cfg_m12   (cfg_m12),
    .active_m00(active_m00),
    .active_m01(),
    .active_m02(),
    .active_m10(),
    .active_m11(active_m11),
    .active_m12(),
    .m_valid   (m_valid),
    .m_ready   (m_ready),
    .m_data    (m_data),
    .m_keep    (m_keep),
    .m_sof     (m_sof),
    .m_eol     (m_eol),
    .m_eof     (m_eof)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n     = 1'b0;
    s_valid   = 1'b0;
    s_data    = {MAX_LANES*PIX_W{1'b0}};
    s_keep    = {MAX_LANES{1'b0}};
    s_sof     = 1'b0;
    s_eol     = 1'b0;
    s_eof     = 1'b0;
    cfg_valid = 1'b0;
    cfg_m00   = 16'sd0;
    cfg_m01   = 16'sd0;
    cfg_m02   = 16'sd0;
    cfg_m10   = 16'sd0;
    cfg_m11   = 16'sd0;
    cfg_m12   = 16'sd0;
    m_ready   = 1'b0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    push_cfg(16'sd128, 16'sd0, 16'sd0,
             16'sd0,   16'sd256, 16'sd0);
    send_demo_frame();

    if ((active_m00 !== 16'sd128) || (active_m11 !== 16'sd256)) begin
        $fatal(1, "Scale matrix did not commit on frame start.");
    end

    expect_output_pixel(24'h000001, 1'b1, 1'b0, 1'b0);
    expect_output_pixel(24'h000001, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h000002, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h000002, 1'b0, 1'b1, 1'b0);
    expect_output_pixel(24'h000005, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h000005, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h000006, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h000006, 1'b0, 1'b1, 1'b0);
    expect_output_pixel(24'h000009, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h000009, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h00000A, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h00000A, 1'b0, 1'b1, 1'b0);
    expect_output_pixel(24'h00000D, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h00000D, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h00000E, 1'b0, 1'b0, 1'b0);
    expect_output_pixel(24'h00000E, 1'b0, 1'b1, 1'b1);

    $display("tb_affine_nearest_stream_std_scale passed.");
    $finish;
end

endmodule
