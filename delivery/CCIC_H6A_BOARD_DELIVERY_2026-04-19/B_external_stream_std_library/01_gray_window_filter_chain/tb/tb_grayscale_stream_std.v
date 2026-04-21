`timescale 1ns / 1ps

module tb_grayscale_stream_std;

localparam integer MAX_LANES      = 8;
localparam integer PIX_W_IN       = 24;
localparam integer PIX_W_OUT      = 8;
localparam integer WIDTH          = 1440;
localparam integer HEIGHT         = 1920;
localparam integer PIXELS         = WIDTH * HEIGHT;
localparam integer CLK_HALF       = 5;
localparam integer TIMEOUT_CYCLES = 5000000;

integer init_idx;
integer lane_idx;
integer file_out;
integer timeout_count;

integer in_base_idx;
integer out_base_idx;
integer accepted_lanes;
integer emitted_lanes;
integer mismatch_count;
integer first_mismatch_idx;
integer lane_count_comb;
integer task_lane_idx_comb;

reg clk;
reg rst_n;
reg done;

reg                           s_valid;
wire                          s_ready;
reg  [MAX_LANES*PIX_W_IN-1:0] s_data;
reg  [MAX_LANES-1:0]          s_keep;
reg                           s_sof;
reg                           s_eol;
reg                           s_eof;

wire                          m_valid;
reg                           m_ready;
wire [MAX_LANES*PIX_W_OUT-1:0] m_data;
wire [MAX_LANES-1:0]          m_keep;
wire                          m_sof;
wire                          m_eol;
wire                          m_eof;

reg  [23:0] rgb_mem  [0:PIXELS-1];
reg  [7:0]  gray_mem [0:PIXELS-1];

reg  [7:0] expected_gray;
reg  [7:0] actual_gray;

function [7:0] rgb888_to_gray8;
    input [23:0] rgb;
    reg [15:0] weighted_sum;
    begin
        weighted_sum = (rgb[23:16] * 8'd77) +
                       (rgb[15:8]  * 8'd150) +
                       (rgb[7:0]   * 8'd29);
        rgb888_to_gray8 = weighted_sum[15:8];
    end
endfunction

function integer beat_lane_count;
    input integer base_idx;
    integer col_idx;
    integer remain_in_line;
    integer remain_in_frame;
    begin
        if (base_idx >= PIXELS) begin
            beat_lane_count = 0;
        end else begin
            col_idx = base_idx % WIDTH;
            remain_in_line = WIDTH - col_idx;
            remain_in_frame = PIXELS - base_idx;
            beat_lane_count = MAX_LANES;
            if (remain_in_line < beat_lane_count) begin
                beat_lane_count = remain_in_line;
            end
            if (remain_in_frame < beat_lane_count) begin
                beat_lane_count = remain_in_frame;
            end
        end
    end
endfunction

function integer keep_count;
    input [MAX_LANES-1:0] keep_bits;
    integer idx;
    begin
        keep_count = 0;
        for (idx = 0; idx < MAX_LANES; idx = idx + 1) begin
            if (keep_bits[idx]) begin
                keep_count = keep_count + 1;
            end
        end
    end
endfunction

grayscale_stream_std #(
    .MAX_LANES(MAX_LANES),
    .PIX_W_IN (PIX_W_IN),
    .PIX_W_OUT(PIX_W_OUT)
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
    forever #CLK_HALF clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    done = 1'b0;
    m_ready = 1'b1;
    in_base_idx = 0;
    out_base_idx = 0;
    timeout_count = 0;
    mismatch_count = 0;
    first_mismatch_idx = -1;

    $readmemh("face_input_1440x1920_rgb888.hex", rgb_mem);

    for (init_idx = 0; init_idx < PIXELS; init_idx = init_idx + 1) begin
        gray_mem[init_idx] = 8'h00;
    end

    #50;
    rst_n = 1'b1;
end

always @* begin
    s_valid = 1'b0;
    s_data  = {MAX_LANES*PIX_W_IN{1'b0}};
    s_keep  = {MAX_LANES{1'b0}};
    s_sof   = 1'b0;
    s_eol   = 1'b0;
    s_eof   = 1'b0;

    if (rst_n) begin
        lane_count_comb = beat_lane_count(in_base_idx);
        s_valid = (lane_count_comb != 0);
        if (lane_count_comb != 0) begin
            for (task_lane_idx_comb = 0; task_lane_idx_comb < MAX_LANES; task_lane_idx_comb = task_lane_idx_comb + 1) begin
                if (task_lane_idx_comb < lane_count_comb) begin
                    s_data[task_lane_idx_comb*PIX_W_IN +: PIX_W_IN] = rgb_mem[in_base_idx + task_lane_idx_comb];
                    s_keep[task_lane_idx_comb] = 1'b1;
                end
            end
            s_sof = (in_base_idx == 0);
            s_eol = (((in_base_idx % WIDTH) + lane_count_comb) >= WIDTH);
            s_eof = ((in_base_idx + lane_count_comb) >= PIXELS);
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_base_idx <= 0;
    end else if (s_valid && s_ready) begin
        accepted_lanes = keep_count(s_keep);
        if ((in_base_idx + accepted_lanes) >= PIXELS) begin
            in_base_idx <= PIXELS;
        end else begin
            in_base_idx <= in_base_idx + accepted_lanes;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_base_idx <= 0;
        done <= 1'b0;
    end else if (m_valid && m_ready) begin
        emitted_lanes = keep_count(m_keep);
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (m_keep[lane_idx]) begin
                actual_gray = m_data[lane_idx*PIX_W_OUT +: PIX_W_OUT];
                expected_gray = rgb888_to_gray8(rgb_mem[out_base_idx + lane_idx]);
                gray_mem[out_base_idx + lane_idx] <= actual_gray;
                if (actual_gray !== expected_gray) begin
                    mismatch_count = mismatch_count + 1;
                    if (first_mismatch_idx < 0) begin
                        first_mismatch_idx = out_base_idx + lane_idx;
                    end
                end
            end
        end
        if ((out_base_idx + emitted_lanes) >= PIXELS) begin
            done <= 1'b1;
        end
        out_base_idx <= out_base_idx + emitted_lanes;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timeout_count <= 0;
    end else if (!done) begin
        timeout_count <= timeout_count + 1;
        if (timeout_count > TIMEOUT_CYCLES) begin
            $error("Simulation timeout before completing grayscale output.");
            $finish;
        end
    end
end

initial begin
    wait (done == 1'b1);
    #20;

    file_out = $fopen("face_input_1440x1920_rgb888_out.hex", "w");
    if (file_out == 0) begin
        $error("Failed to open output hex file.");
        $finish;
    end

    for (init_idx = 0; init_idx < PIXELS; init_idx = init_idx + 1) begin
        $fwrite(file_out, "%02h\n", gray_mem[init_idx]);
    end

    $fclose(file_out);
    if (mismatch_count != 0) begin
        $display("First mismatch pixel index: %0d", first_mismatch_idx);
        $fatal(1, "grayscale_stream_std mismatch_count = %0d", mismatch_count);
    end

    $display("grayscale_stream_std simulation passed with %0d pixels.", PIXELS);
    $finish;
end

endmodule
