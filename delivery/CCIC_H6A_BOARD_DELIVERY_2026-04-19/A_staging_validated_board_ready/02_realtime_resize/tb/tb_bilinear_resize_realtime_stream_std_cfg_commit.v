`timescale 1ns / 1ps

module tb_bilinear_resize_realtime_stream_std_cfg_commit;

localparam integer MAX_LANES  = 1;
localparam integer IMG_WIDTH  = 4;
localparam integer IMG_HEIGHT = 4;
localparam integer OUT_WIDTH  = 3;
localparam integer OUT_HEIGHT = 3;
localparam integer IN_PIXELS  = IMG_WIDTH * IMG_HEIGHT;
localparam [31:0] SCALE_3X3_X_FP = ((IMG_WIDTH  - 1) << 16) / (3 - 1);
localparam [31:0] SCALE_3X3_Y_FP = ((IMG_HEIGHT - 1) << 16) / (3 - 1);
localparam [31:0] SCALE_2X2_X_FP = ((IMG_WIDTH  - 1) << 16) / (2 - 1);
localparam [31:0] SCALE_2X2_Y_FP = ((IMG_HEIGHT - 1) << 16) / (2 - 1);

integer pixel_idx;
integer output_count_in_frame;
integer finished_frames;
integer timeout_cycles;

reg         clk;
reg         rst_n;
reg         cfg_valid;
wire        cfg_ready;
reg [15:0]  cfg_out_width;
reg [15:0]  cfg_out_height;
reg [31:0]  cfg_scale_x_fp;
reg [31:0]  cfg_scale_y_fp;
reg         s_valid;
wire        s_ready;
reg [23:0]  s_data;
reg         s_keep;
reg         s_sof;
reg         s_eol;
reg         s_eof;
wire        m_valid;
reg         m_ready;
wire [23:0] m_data;
wire        m_keep;
wire        m_sof;
wire        m_eol;
wire        m_eof;

reg [23:0] pixel_mem [0:IN_PIXELS-1];

task pulse_cfg;
    input [15:0] out_w;
    input [15:0] out_h;
    input [31:0] scale_x_fp;
    input [31:0] scale_y_fp;
    begin
        @(negedge clk);
        cfg_out_width  = out_w;
        cfg_out_height = out_h;
        cfg_scale_x_fp = scale_x_fp;
        cfg_scale_y_fp = scale_y_fp;
        cfg_valid = 1'b1;
        @(negedge clk);
        cfg_valid = 1'b0;
    end
endtask

task send_frame;
    input integer frame_number;
    input integer cfg_inject_after_pixel;
    integer idx;
    begin
        for (idx = 0; idx < IN_PIXELS; idx = idx + 1) begin
            @(negedge clk);
            s_valid = 1'b1;
            s_data  = pixel_mem[idx];
            s_keep  = 1'b1;
            s_sof   = (idx == 0);
            s_eol   = ((idx % IMG_WIDTH) == (IMG_WIDTH - 1));
            s_eof   = (idx == (IN_PIXELS - 1));

            wait (s_ready);
            @(negedge clk);
            s_valid = 1'b0;
            s_data  = 24'd0;
            s_keep  = 1'b0;
            s_sof   = 1'b0;
            s_eol   = 1'b0;
            s_eof   = 1'b0;

            if ((frame_number == 0) && (idx == cfg_inject_after_pixel)) begin
                pulse_cfg(16'd2, 16'd2, SCALE_2X2_X_FP, SCALE_2X2_Y_FP);
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
    cfg_out_width  = 16'd3;
    cfg_out_height = 16'd3;
    cfg_scale_x_fp = SCALE_3X3_X_FP;
    cfg_scale_y_fp = SCALE_3X3_Y_FP;
    s_valid = 1'b0;
    s_data  = 24'd0;
    s_keep  = 1'b0;
    s_sof   = 1'b0;
    s_eol   = 1'b0;
    s_eof   = 1'b0;
    m_ready = 1'b1;
    output_count_in_frame = 0;
    finished_frames = 0;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    send_frame(0, 5);
    send_frame(1, -1);

    timeout_cycles = 0;
    while (finished_frames < 2) begin
        @(posedge clk);
        timeout_cycles = timeout_cycles + 1;
        if (timeout_cycles > 600) begin
            $fatal(1, "tb_bilinear_resize_realtime_stream_std_cfg_commit timeout");
        end
    end

    #20;
    $display("tb_bilinear_resize_realtime_stream_std_cfg_commit passed.");
    $finish;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        output_count_in_frame <= 0;
        finished_frames <= 0;
    end else if (m_valid && m_ready) begin
        if (m_keep !== 1'b1) begin
            $fatal(1, "Unexpected keep during cfg-commit test: %b", m_keep);
        end

        if (m_sof) begin
            if (output_count_in_frame != 0) begin
                $fatal(1, "New output frame started before previous frame closed.");
            end
        end

        output_count_in_frame <= output_count_in_frame + 1;

        if (m_eof) begin
            if (finished_frames == 0) begin
                if ((output_count_in_frame + 1) != 9) begin
                    $fatal(1, "First frame output count changed mid-frame, got=%0d expected=9",
                           output_count_in_frame + 1);
                end
            end else if (finished_frames == 1) begin
                if ((output_count_in_frame + 1) != 4) begin
                    $fatal(1, "Second frame output count did not pick up new cfg, got=%0d expected=4",
                           output_count_in_frame + 1);
                end
            end else begin
                $fatal(1, "Unexpected extra output frame.");
            end

            finished_frames <= finished_frames + 1;
            output_count_in_frame <= 0;
        end
    end
end

endmodule
