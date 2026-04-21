`timescale 1ns / 1ps

module tb_gray_window_gaussian_std;

localparam integer MAX_LANES      = 1;
localparam integer PIX_W_IN       = 24;
localparam integer PIX_W_GRAY     = 8;
localparam integer PIX_W_WINDOW   = 72;
localparam integer WIDTH          = 1440;
localparam integer HEIGHT         = 1920;
localparam integer PIXELS         = WIDTH * HEIGHT;
localparam integer CLK_HALF       = 5;
localparam integer TIMEOUT_CYCLES = 6000000;

integer timeout_count;
integer in_idx;
integer final_idx;
integer file_gray;
integer file_window;
integer file_final;

reg clk;
reg rst_n;
reg done;
reg final_ready;

reg                            s_valid;
wire                           s_ready;
reg  [PIX_W_IN-1:0]            s_data;
reg  [MAX_LANES-1:0]           s_keep;
reg                            s_sof;
reg                            s_eol;
reg                            s_eof;

wire                           gray_valid;
wire                           gray_ready;
wire [PIX_W_GRAY-1:0]          gray_data;
wire [MAX_LANES-1:0]           gray_keep;
wire                           gray_sof;
wire                           gray_eol;
wire                           gray_eof;

wire                           window_valid;
wire                           window_ready;
wire [PIX_W_WINDOW-1:0]        window_data;
wire [MAX_LANES-1:0]           window_keep;
wire                           window_sof;
wire                           window_eol;
wire                           window_eof;

wire                           final_valid;
wire [PIX_W_GRAY-1:0]          final_data;
wire [MAX_LANES-1:0]           final_keep;
wire                           final_sof;
wire                           final_eol;
wire                           final_eof;

reg  [23:0] rgb_mem [0:PIXELS-1];

grayscale_stream_std #(
    .MAX_LANES(MAX_LANES),
    .PIX_W_IN (PIX_W_IN),
    .PIX_W_OUT(PIX_W_GRAY)
) u_gray (
    .clk    (clk),
    .rst_n  (rst_n),
    .s_valid(s_valid),
    .s_ready(s_ready),
    .s_data (s_data),
    .s_keep (s_keep),
    .s_sof  (s_sof),
    .s_eol  (s_eol),
    .s_eof  (s_eof),
    .m_valid(gray_valid),
    .m_ready(gray_ready),
    .m_data (gray_data),
    .m_keep (gray_keep),
    .m_sof  (gray_sof),
    .m_eol  (gray_eol),
    .m_eof  (gray_eof)
);

window3x3_stream_std #(
    .MAX_LANES (MAX_LANES),
    .DATA_W    (PIX_W_GRAY),
    .IMG_WIDTH (WIDTH),
    .IMG_HEIGHT(HEIGHT)
) u_window (
    .clk    (clk),
    .rst_n  (rst_n),
    .s_valid(gray_valid),
    .s_ready(gray_ready),
    .s_data (gray_data),
    .s_keep (gray_keep),
    .s_sof  (gray_sof),
    .s_eol  (gray_eol),
    .s_eof  (gray_eof),
    .m_valid(window_valid),
    .m_ready(window_ready),
    .m_data (window_data),
    .m_keep (window_keep),
    .m_sof  (window_sof),
    .m_eol  (window_eol),
    .m_eof  (window_eof)
);

gaussian3x3_stream_std #(
    .MAX_LANES(MAX_LANES),
    .DATA_W   (PIX_W_GRAY)
) u_gaussian (
    .clk    (clk),
    .rst_n  (rst_n),
    .s_valid(window_valid),
    .s_ready(window_ready),
    .s_data (window_data),
    .s_keep (window_keep),
    .s_sof  (window_sof),
    .s_eol  (window_eol),
    .s_eof  (window_eof),
    .m_valid(final_valid),
    .m_ready(final_ready),
    .m_data (final_data),
    .m_keep (final_keep),
    .m_sof  (final_sof),
    .m_eol  (final_eol),
    .m_eof  (final_eof)
);

initial begin
    clk = 1'b0;
    forever #CLK_HALF clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    done = 1'b0;
    final_ready = 1'b1;
    timeout_count = 0;
    in_idx = 0;
    final_idx = 0;

    $readmemh("face_input_1440x1920_rgb888.hex", rgb_mem);

    file_gray = $fopen("sim_gray_window_gaussian_gray.hex", "w");
    file_window = $fopen("sim_gray_window_gaussian_window.hex", "w");
    file_final = $fopen("sim_gray_window_gaussian_final.hex", "w");
    if ((file_gray == 0) || (file_window == 0) || (file_final == 0)) begin
        $error("tb_gray_window_gaussian_std failed to open output files.");
        $finish;
    end

    #50;
    rst_n = 1'b1;
end

always @* begin
    s_valid = 1'b0;
    s_data  = {PIX_W_IN{1'b0}};
    s_keep  = {MAX_LANES{1'b0}};
    s_sof   = 1'b0;
    s_eol   = 1'b0;
    s_eof   = 1'b0;

    if (rst_n && (in_idx < PIXELS)) begin
        s_valid = 1'b1;
        s_data  = rgb_mem[in_idx];
        s_keep  = {{(MAX_LANES-1){1'b0}}, 1'b1};
        s_sof   = (in_idx == 0);
        s_eol   = ((in_idx % WIDTH) == (WIDTH - 1));
        s_eof   = (in_idx == (PIXELS - 1));
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_idx <= 0;
    end else if (s_valid && s_ready) begin
        in_idx <= in_idx + 1;
    end
end

always @(posedge clk) begin
    if (gray_valid && gray_ready) begin
        $fwrite(file_gray, "%02h\n", gray_data);
    end
    if (window_valid && window_ready) begin
        $fwrite(file_window, "%018h\n", window_data);
    end
    if (final_valid && final_ready) begin
        $fwrite(file_final, "%02h\n", final_data);
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        final_idx <= 0;
        done <= 1'b0;
    end else if (final_valid && final_ready) begin
        if (final_idx == (PIXELS - 1)) begin
            done <= 1'b1;
        end
        final_idx <= final_idx + 1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timeout_count <= 0;
    end else if (!done) begin
        timeout_count <= timeout_count + 1;
        if (timeout_count > TIMEOUT_CYCLES) begin
            $error("tb_gray_window_gaussian_std timeout.");
            $finish;
        end
    end
end

initial begin
    wait (done == 1'b1);
    #20;
    $fclose(file_gray);
    $fclose(file_window);
    $fclose(file_final);
    $display("tb_gray_window_gaussian_std finished with %0d pixels.", PIXELS);
    $finish;
end

endmodule
