`timescale 1ns / 1ps

module tb_bilinear_resize_realtime_stream_std_default8;

localparam integer MAX_LANES  = 8;
localparam integer IMG_WIDTH  = 8;
localparam integer IMG_HEIGHT = 2;
localparam integer OUT_WIDTH  = 8;
localparam integer OUT_HEIGHT = 1;
localparam [31:0] SCALE_X_FP  = ((IMG_WIDTH - 1) << 16) / (OUT_WIDTH - 1);

integer lane_idx;
integer hold_cycles;
integer wait_cycles;

reg                        clk;
reg                        rst_n;
reg                        cfg_valid;
wire                       cfg_ready;
reg  [15:0]                cfg_out_width;
reg  [15:0]                cfg_out_height;
reg  [31:0]                cfg_scale_x_fp;
reg  [31:0]                cfg_scale_y_fp;
reg                        s_valid;
wire                       s_ready;
reg  [MAX_LANES*24-1:0]    s_data;
reg  [MAX_LANES-1:0]       s_keep;
reg                        s_sof;
reg                        s_eol;
reg                        s_eof;
wire                       m_valid;
reg                        m_ready;
wire [MAX_LANES*24-1:0]    m_data;
wire [MAX_LANES-1:0]       m_keep;
wire                       m_sof;
wire                       m_eol;
wire                       m_eof;

reg [23:0] pixel_mem [0:(IMG_WIDTH*IMG_HEIGHT)-1];

task push_cfg;
    begin
        @(negedge clk);
        cfg_valid = 1'b1;
        @(negedge clk);
        cfg_valid = 1'b0;
    end
endtask

task send_row;
    input integer row_idx;
    input        sof;
    input        eof;
    integer local_lane;
    begin
        @(negedge clk);
        s_valid = 1'b1;
        s_keep  = {MAX_LANES{1'b1}};
        s_sof   = sof;
        s_eol   = 1'b1;
        s_eof   = eof;
        for (local_lane = 0; local_lane < MAX_LANES; local_lane = local_lane + 1) begin
            s_data[local_lane*24 +: 24] = pixel_mem[row_idx * IMG_WIDTH + local_lane];
        end
        wait (s_ready);
        @(negedge clk);
        s_valid = 1'b0;
        s_data  = {MAX_LANES*24{1'b0}};
        s_keep  = {MAX_LANES{1'b0}};
        s_sof   = 1'b0;
        s_eol   = 1'b0;
        s_eof   = 1'b0;
    end
endtask

task send_frame;
    begin
        send_row(0, 1'b1, 1'b0);
        send_row(1, 1'b0, 1'b1);
    end
endtask

task check_output_beat;
    begin
        if (m_keep !== {MAX_LANES{1'b1}}) begin
            $fatal(1, "Unexpected keep=%b", m_keep);
        end
        if ({m_sof, m_eol, m_eof} !== 3'b111) begin
            $fatal(1, "Unexpected frame metadata sof/eol/eof=%b%b%b", m_sof, m_eol, m_eof);
        end
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (m_data[lane_idx*24 +: 24] !== pixel_mem[lane_idx]) begin
                $fatal(1, "Pixel mismatch at lane=%0d got=%06h expected=%06h",
                       lane_idx,
                       m_data[lane_idx*24 +: 24],
                       pixel_mem[lane_idx]);
            end
        end
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
    pixel_mem[4]  = 24'h50_60_70;
    pixel_mem[5]  = 24'h60_70_80;
    pixel_mem[6]  = 24'h70_80_90;
    pixel_mem[7]  = 24'h80_90_A0;
    pixel_mem[8]  = 24'h90_A0_B0;
    pixel_mem[9]  = 24'hA0_B0_C0;
    pixel_mem[10] = 24'hB0_C0_D0;
    pixel_mem[11] = 24'hC0_D0_E0;
    pixel_mem[12] = 24'hD0_E0_F0;
    pixel_mem[13] = 24'hE0_F0_10;
    pixel_mem[14] = 24'hF0_10_20;
    pixel_mem[15] = 24'h11_22_33;

    rst_n = 1'b0;
    cfg_valid = 1'b0;
    cfg_out_width  = OUT_WIDTH[15:0];
    cfg_out_height = OUT_HEIGHT[15:0];
    cfg_scale_x_fp = SCALE_X_FP;
    cfg_scale_y_fp = 32'd0;
    s_valid = 1'b0;
    s_data  = {MAX_LANES*24{1'b0}};
    s_keep  = {MAX_LANES{1'b0}};
    s_sof   = 1'b0;
    s_eol   = 1'b0;
    s_eof   = 1'b0;
    m_ready = 1'b0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    push_cfg();
    send_frame();

    wait_cycles = 0;
    while (!m_valid) begin
        @(posedge clk);
        wait_cycles = wait_cycles + 1;
        if (wait_cycles > 100) begin
            $fatal(1, "Timed out waiting for default8 output beat.");
        end
    end

    check_output_beat();
    if (s_ready) begin
        $fatal(1, "Input should be stalled while output is backpressured.");
    end

    for (hold_cycles = 0; hold_cycles < 2; hold_cycles = hold_cycles + 1) begin
        @(posedge clk);
        if (!m_valid) begin
            $fatal(1, "Output valid dropped during backpressure hold cycle=%0d", hold_cycles);
        end
        check_output_beat();
        if (s_ready) begin
            $fatal(1, "Input ready unexpectedly reasserted during backpressure hold cycle=%0d", hold_cycles);
        end
    end

    @(negedge clk);
    m_ready = 1'b1;
    @(posedge clk);
    @(negedge clk);
    m_ready = 1'b0;

    repeat (3) begin
        @(posedge clk);
        if (m_valid) begin
            $fatal(1, "Unexpected extra output beat after default8 frame.");
        end
    end

    $display("tb_bilinear_resize_realtime_stream_std_default8 passed.");
    $finish;
end

endmodule
