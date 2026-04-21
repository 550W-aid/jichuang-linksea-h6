`timescale 1ns / 1ps

module tb_histogram_equalizer_stream_std;

localparam integer MAX_LANES = 8;

integer lane_idx;

reg                    clk;
reg                    rst_n;
reg                    s_valid;
wire                   s_ready;
reg  [MAX_LANES*8-1:0] s_data;
reg  [MAX_LANES-1:0]   s_keep;
reg                    s_sof;
reg                    s_eol;
reg                    s_eof;
reg  [MAX_LANES*8-1:0] s_map_data;
wire                   m_valid;
reg                    m_ready;
wire [MAX_LANES*8-1:0] m_data;
wire [MAX_LANES-1:0]   m_keep;
wire                   m_sof;
wire                   m_eol;
wire                   m_eof;

reg [7:0] expected0 [0:4];
reg [7:0] expected1 [0:2];

histogram_equalizer_stream_std #(
    .MAX_LANES(MAX_LANES)
) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .s_valid  (s_valid),
    .s_ready  (s_ready),
    .s_data   (s_data),
    .s_keep   (s_keep),
    .s_sof    (s_sof),
    .s_eol    (s_eol),
    .s_eof    (s_eof),
    .s_map_data(s_map_data),
    .m_valid  (m_valid),
    .m_ready  (m_ready),
    .m_data   (m_data),
    .m_keep   (m_keep),
    .m_sof    (m_sof),
    .m_eol    (m_eol),
    .m_eof    (m_eof)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

task send_beat;
    input [MAX_LANES*8-1:0] beat_data;
    input [MAX_LANES*8-1:0] beat_map;
    input [MAX_LANES-1:0]   beat_keep;
    input                   beat_sof;
    input                   beat_eol;
    input                   beat_eof;
    begin
        @(negedge clk);
        s_valid    = 1'b1;
        s_data     = beat_data;
        s_map_data = beat_map;
        s_keep     = beat_keep;
        s_sof      = beat_sof;
        s_eol      = beat_eol;
        s_eof      = beat_eof;
        wait (s_ready);
        @(negedge clk);
        s_valid    = 1'b0;
        s_data     = {MAX_LANES*8{1'b0}};
        s_map_data = {MAX_LANES*8{1'b0}};
        s_keep     = {MAX_LANES{1'b0}};
        s_sof      = 1'b0;
        s_eol      = 1'b0;
        s_eof      = 1'b0;
    end
endtask

task check_beat0;
    begin
        wait (m_valid);
        if (m_keep !== 8'b0001_1111) begin
            $fatal(1, "Beat0 keep mismatch: %b", m_keep);
        end
        if ({m_sof,m_eol,m_eof} !== 3'b100) begin
            $fatal(1, "Beat0 markers mismatch.");
        end
        for (lane_idx = 0; lane_idx < 5; lane_idx = lane_idx + 1) begin
            if (m_data[lane_idx*8 +: 8] !== expected0[lane_idx]) begin
                $fatal(1, "Beat0 lane %0d mismatch: got %02h expected %02h",
                       lane_idx, m_data[lane_idx*8 +: 8], expected0[lane_idx]);
            end
        end
        @(posedge clk);
    end
endtask

task check_beat1;
    begin
        wait (m_valid);
        if (m_keep !== 8'b0000_0111) begin
            $fatal(1, "Beat1 keep mismatch: %b", m_keep);
        end
        if ({m_sof,m_eol,m_eof} !== 3'b011) begin
            $fatal(1, "Beat1 markers mismatch.");
        end
        for (lane_idx = 0; lane_idx < 3; lane_idx = lane_idx + 1) begin
            if (m_data[lane_idx*8 +: 8] !== expected1[lane_idx]) begin
                $fatal(1, "Beat1 lane %0d mismatch: got %02h expected %02h",
                       lane_idx, m_data[lane_idx*8 +: 8], expected1[lane_idx]);
            end
        end
        @(posedge clk);
    end
endtask

initial begin
    expected0[0] = 8'h10;
    expected0[1] = 8'h22;
    expected0[2] = 8'h38;
    expected0[3] = 8'h7A;
    expected0[4] = 8'hF0;
    expected1[0] = 8'h40;
    expected1[1] = 8'h90;
    expected1[2] = 8'hFF;

    rst_n     = 1'b0;
    s_valid   = 1'b0;
    s_data    = {MAX_LANES*8{1'b0}};
    s_map_data= {MAX_LANES*8{1'b0}};
    s_keep    = {MAX_LANES{1'b0}};
    s_sof     = 1'b0;
    s_eol     = 1'b0;
    s_eof     = 1'b0;
    m_ready   = 1'b1;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    send_beat(
        {24'd0,8'h40,8'h30,8'h20,8'h10,8'h00},
        {24'd0,expected0[4],expected0[3],expected0[2],expected0[1],expected0[0]},
        8'b0001_1111,
        1'b1,
        1'b0,
        1'b0
    );
    check_beat0();

    send_beat(
        {40'd0,8'hA0,8'h80,8'h60},
        {40'd0,expected1[2],expected1[1],expected1[0]},
        8'b0000_0111,
        1'b0,
        1'b1,
        1'b1
    );
    check_beat1();

    $display("tb_histogram_equalizer_stream_std passed.");
    $finish;
end

endmodule
