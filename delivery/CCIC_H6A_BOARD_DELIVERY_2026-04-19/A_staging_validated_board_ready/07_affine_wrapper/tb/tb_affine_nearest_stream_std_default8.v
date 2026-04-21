`timescale 1ns / 1ps

module tb_affine_nearest_stream_std_default8;

localparam integer MAX_LANES  = 8;
localparam integer IMG_WIDTH  = 16;
localparam integer IMG_HEIGHT = 2;
localparam integer PIX_W      = 24;
localparam integer PIXELS     = IMG_WIDTH * IMG_HEIGHT;
localparam integer BEATS      = PIXELS / MAX_LANES;

integer beat_idx;
integer lane_idx;
integer pix_idx;
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
wire                       m_valid;
reg                        m_ready;
wire [MAX_LANES*PIX_W-1:0] m_data;
wire [MAX_LANES-1:0]       m_keep;
wire                       m_sof;
wire                       m_eol;
wire                       m_eof;

reg [23:0] demo_pixels [0:PIXELS-1];
reg [MAX_LANES*PIX_W-1:0] expected_data;

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

task send_frame;
    begin
        for (beat_idx = 0; beat_idx < BEATS; beat_idx = beat_idx + 1) begin
            @(negedge clk);
            s_valid = 1'b1;
            s_data  = {MAX_LANES*PIX_W{1'b0}};
            s_keep  = {MAX_LANES{1'b1}};
            s_sof   = (beat_idx == 0);
            s_eol   = beat_idx[0];
            s_eof   = (beat_idx == (BEATS - 1));

            for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                pix_idx = beat_idx * MAX_LANES + lane_idx;
                s_data[lane_idx*PIX_W +: PIX_W] = demo_pixels[pix_idx];
            end

            wait (s_ready);
            @(negedge clk);
            s_valid = 1'b0;
            s_data  = {MAX_LANES*PIX_W{1'b0}};
            s_keep  = {MAX_LANES{1'b0}};
            s_sof   = 1'b0;
            s_eol   = 1'b0;
            s_eof   = 1'b0;
        end
    end
endtask

task wait_for_output;
    begin
        wait_cycles = 0;
        while (!m_valid) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
            if (wait_cycles > 128) begin
                $fatal(1, "Timed out waiting for affine default8 output.");
            end
        end
    end
endtask

task expect_current_beat;
    input [MAX_LANES*PIX_W-1:0] exp_data;
    input                       exp_sof;
    input                       exp_eol;
    input                       exp_eof;
    begin
        if (m_data !== exp_data) begin
            $fatal(1, "Beat data mismatch. got=%h expected=%h", m_data, exp_data);
        end
        if (m_keep !== {MAX_LANES{1'b1}}) begin
            $fatal(1, "Beat keep mismatch. got=%b", m_keep);
        end
        if ((m_sof !== exp_sof) || (m_eol !== exp_eol) || (m_eof !== exp_eof)) begin
            $fatal(1,
                   "Beat marker mismatch. got=%b%b%b expected=%b%b%b",
                   m_sof, m_eol, m_eof, exp_sof, exp_eol, exp_eof);
        end
    end
endtask

task accept_beat;
    begin
        @(negedge clk);
        m_ready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        m_ready = 1'b0;
    end
endtask

task expect_output_beat;
    input [MAX_LANES*PIX_W-1:0] exp_data;
    input                       exp_sof;
    input                       exp_eol;
    input                       exp_eof;
    begin
        wait_for_output();
        expect_current_beat(exp_data, exp_sof, exp_eol, exp_eof);
        accept_beat();
    end
endtask

task stall_and_expect_beat;
    input [MAX_LANES*PIX_W-1:0] exp_data;
    input                       exp_sof;
    input                       exp_eol;
    input                       exp_eof;
    begin
        wait_for_output();
        repeat (2) @(posedge clk);
        if (!m_valid) begin
            $fatal(1, "Output did not stay valid during backpressure.");
        end
        expect_current_beat(exp_data, exp_sof, exp_eol, exp_eof);
        accept_beat();
    end
endtask

task build_expected_identity;
    input integer start_idx;
    begin
        expected_data = {MAX_LANES*PIX_W{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            expected_data[lane_idx*PIX_W +: PIX_W] = demo_pixels[start_idx + lane_idx];
        end
    end
endtask

task build_expected_translate_x1;
    input integer row_base;
    input integer start_x;
    begin
        expected_data = {MAX_LANES*PIX_W{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if ((start_x + lane_idx + 1) < IMG_WIDTH) begin
                expected_data[lane_idx*PIX_W +: PIX_W] =
                    demo_pixels[row_base + start_x + lane_idx + 1];
            end else begin
                expected_data[lane_idx*PIX_W +: PIX_W] = 24'h000000;
            end
        end
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
    .active_m00(),
    .active_m01(),
    .active_m02(),
    .active_m10(),
    .active_m11(),
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
    for (pix_idx = 0; pix_idx < PIXELS; pix_idx = pix_idx + 1) begin
        demo_pixels[pix_idx] = 24'h200000 + pix_idx;
    end

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
    expected_data = {MAX_LANES*PIX_W{1'b0}};

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    send_frame();

    build_expected_identity(0);
    expect_output_beat(expected_data, 1'b1, 1'b0, 1'b0);
    build_expected_identity(8);
    stall_and_expect_beat(expected_data, 1'b0, 1'b1, 1'b0);
    build_expected_identity(16);
    expect_output_beat(expected_data, 1'b0, 1'b0, 1'b0);
    build_expected_identity(24);
    expect_output_beat(expected_data, 1'b0, 1'b1, 1'b1);

    push_cfg(16'sd256, 16'sd0, 16'sd1,
             16'sd0,   16'sd256, 16'sd0);
    send_frame();

    build_expected_translate_x1(0, 0);
    expect_output_beat(expected_data, 1'b1, 1'b0, 1'b0);
    build_expected_translate_x1(0, 8);
    expect_output_beat(expected_data, 1'b0, 1'b1, 1'b0);
    build_expected_translate_x1(16, 0);
    expect_output_beat(expected_data, 1'b0, 1'b0, 1'b0);
    build_expected_translate_x1(16, 8);
    expect_output_beat(expected_data, 1'b0, 1'b1, 1'b1);

    $display("tb_affine_nearest_stream_std_default8 passed.");
    $finish;
end

endmodule
