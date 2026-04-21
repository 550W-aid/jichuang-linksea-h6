`timescale 1ns / 1ps

module tb_fixed_angle_rotate_stream_std;

localparam integer MAX_LANES  = 2;
localparam integer IMG_WIDTH  = 4;
localparam integer IMG_HEIGHT = 2;
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
reg  [1:0]                 cfg_angle_sel;
wire [1:0]                 active_angle_sel;
wire                       m_valid;
reg                        m_ready;
wire [MAX_LANES*PIX_W-1:0] m_data;
wire [MAX_LANES-1:0]       m_keep;
wire                       m_sof;
wire                       m_eol;
wire                       m_eof;

task push_cfg;
    input [1:0] angle_sel;
    begin
        @(negedge clk);
        cfg_valid     = 1'b1;
        cfg_angle_sel = angle_sel;
        @(negedge clk);
        cfg_valid     = 1'b0;
        cfg_angle_sel = 2'd0;
    end
endtask

task send_beat;
    input [23:0] lane0;
    input [23:0] lane1;
    input [1:0]  keep;
    input        sof;
    input        eol;
    input        eof;
    begin
        @(negedge clk);
        s_valid = 1'b1;
        s_data  = {lane1, lane0};
        s_keep  = keep;
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
        send_beat(24'h000001, 24'h000002, 2'b11, 1'b1, 1'b0, 1'b0);
        send_beat(24'h000003, 24'h000004, 2'b11, 1'b0, 1'b1, 1'b0);
        send_beat(24'h000005, 24'h000006, 2'b11, 1'b0, 1'b0, 1'b0);
        send_beat(24'h000007, 24'h000008, 2'b11, 1'b0, 1'b1, 1'b1);
    end
endtask

task wait_for_output;
    begin
        wait_cycles = 0;
        while (!m_valid) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
            if (wait_cycles > 32) begin
                $fatal(1, "Timed out waiting for rotated output.");
            end
        end
    end
endtask

task expect_output_beat;
    input [23:0] lane0;
    input [23:0] lane1;
    input [1:0]  keep;
    input        sof;
    input        eol;
    input        eof;
    begin
        wait_for_output();
        if (m_data[23:0] !== lane0) begin
            $fatal(1, "Lane0 mismatch. got=%06h expected=%06h", m_data[23:0], lane0);
        end
        if (m_data[47:24] !== lane1) begin
            $fatal(1, "Lane1 mismatch. got=%06h expected=%06h", m_data[47:24], lane1);
        end
        if (m_keep !== keep) begin
            $fatal(1, "Keep mismatch. got=%b expected=%b", m_keep, keep);
        end
        if (m_sof !== sof || m_eol !== eol || m_eof !== eof) begin
            $fatal(1, "Marker mismatch. got sof/eol/eof=%b%b%b expected=%b%b%b",
                   m_sof, m_eol, m_eof, sof, eol, eof);
        end
        @(posedge clk);
    end
endtask

fixed_angle_rotate_stream_std #(
    .MAX_LANES (MAX_LANES),
    .IMG_WIDTH (IMG_WIDTH),
    .IMG_HEIGHT(IMG_HEIGHT)
) dut (
    .clk             (clk),
    .rst_n           (rst_n),
    .s_valid         (s_valid),
    .s_ready         (s_ready),
    .s_data          (s_data),
    .s_keep          (s_keep),
    .s_sof           (s_sof),
    .s_eol           (s_eol),
    .s_eof           (s_eof),
    .cfg_valid       (cfg_valid),
    .cfg_ready       (cfg_ready),
    .cfg_angle_sel   (cfg_angle_sel),
    .active_angle_sel(active_angle_sel),
    .m_valid         (m_valid),
    .m_ready         (m_ready),
    .m_data          (m_data),
    .m_keep          (m_keep),
    .m_sof           (m_sof),
    .m_eol           (m_eol),
    .m_eof           (m_eof)
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n         = 1'b0;
    s_valid       = 1'b0;
    s_data        = {MAX_LANES*PIX_W{1'b0}};
    s_keep        = {MAX_LANES{1'b0}};
    s_sof         = 1'b0;
    s_eol         = 1'b0;
    s_eof         = 1'b0;
    cfg_valid     = 1'b0;
    cfg_angle_sel = 2'd0;
    m_ready       = 1'b1;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    push_cfg(2'd1);
    if (active_angle_sel !== 2'd0) begin
        $fatal(1, "Angle changed before frame start.");
    end

    send_demo_frame();
    if (active_angle_sel !== 2'd1) begin
        $fatal(1, "Angle did not commit on the first frame.");
    end

    expect_output_beat(24'h000005, 24'h000001, 2'b11, 1'b1, 1'b1, 1'b0);
    expect_output_beat(24'h000006, 24'h000002, 2'b11, 1'b0, 1'b1, 1'b0);
    expect_output_beat(24'h000007, 24'h000003, 2'b11, 1'b0, 1'b1, 1'b0);
    expect_output_beat(24'h000008, 24'h000004, 2'b11, 1'b0, 1'b1, 1'b1);

    push_cfg(2'd2);
    if (active_angle_sel !== 2'd1) begin
        $fatal(1, "Angle changed mid-frame instead of waiting for next frame.");
    end

    send_demo_frame();
    if (active_angle_sel !== 2'd2) begin
        $fatal(1, "Angle did not commit on the second frame.");
    end

    expect_output_beat(24'h000008, 24'h000007, 2'b11, 1'b1, 1'b0, 1'b0);
    expect_output_beat(24'h000006, 24'h000005, 2'b11, 1'b0, 1'b1, 1'b0);
    expect_output_beat(24'h000004, 24'h000003, 2'b11, 1'b0, 1'b0, 1'b0);
    expect_output_beat(24'h000002, 24'h000001, 2'b11, 1'b0, 1'b1, 1'b1);

    $display("tb_fixed_angle_rotate_stream_std passed.");
    $finish;
end

endmodule
