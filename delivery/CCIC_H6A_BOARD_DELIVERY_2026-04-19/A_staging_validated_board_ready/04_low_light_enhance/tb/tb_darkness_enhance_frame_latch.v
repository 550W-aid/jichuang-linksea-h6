`timescale 1ns / 1ps

module tb_darkness_enhance_frame_latch;

localparam integer MAX_LANES = 8;
localparam integer PIX_W     = 24;

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

task send_frame;
    input [23:0] pixel0;
    input [23:0] pixel1;
    begin
        @(negedge clk);
        s_valid = 1'b1;
        s_data  = {144'd0, pixel1, pixel0};
        s_keep  = 8'b0000_0011;
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

darkness_enhance_rgb888_stream_std #(
    .MAX_LANES (MAX_LANES),
    .GAMMA_MODE(2'd0)
) dut (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .s_valid                (s_valid),
    .s_ready                (s_ready),
    .s_data                 (s_data),
    .s_keep                 (s_keep),
    .s_sof                  (s_sof),
    .s_eol                  (s_eol),
    .s_eof                  (s_eof),
    .cfg_valid              (cfg_valid),
    .cfg_ready              (cfg_ready),
    .cfg_brightness_offset  (cfg_brightness_offset),
    .active_brightness_offset(active_brightness_offset),
    .m_valid                (m_valid),
    .m_ready                (m_ready),
    .m_data                 (m_data),
    .m_keep                 (m_keep),
    .m_sof                  (m_sof),
    .m_eol                  (m_eol),
    .m_eof                  (m_eof)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
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

    push_cfg(9'sd32);
    if (active_brightness_offset !== 9'sd0) begin
        $fatal(1, "Active parameter changed before frame start.");
    end

    send_frame(24'h101010, 24'h202020);
    @(posedge clk);
    if (active_brightness_offset !== 9'sd32) begin
        $fatal(1, "First frame did not commit pending parameter.");
    end

    push_cfg(9'sd96);
    if (active_brightness_offset !== 9'sd32) begin
        $fatal(1, "Parameter changed immediately instead of waiting for next frame.");
    end

    send_frame(24'h303030, 24'h404040);
    @(posedge clk);
    if (active_brightness_offset !== 9'sd96) begin
        $fatal(1, "Second frame did not commit next pending parameter.");
    end

    wait_cycles = 0;
    while (wait_cycles < 32) begin
        @(posedge clk);
        wait_cycles = wait_cycles + 1;
    end

    $display("tb_darkness_enhance_frame_latch passed.");
    $finish;
end

endmodule
