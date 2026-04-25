`timescale 1ns / 1ps

module tb_rotate_nearest_stream_mem_seam;

localparam integer MAX_LANES = 1;
localparam integer PIXEL_W   = 8;
localparam integer FRAME_W   = 4;
localparam integer FRAME_H   = 3;
localparam integer PIXELS    = FRAME_W * FRAME_H;
localparam integer ADDR_W    = $clog2(PIXELS);

reg                         clk;
reg                         rst_n;
reg                         s_valid;
wire                        s_ready;
reg  [MAX_LANES*PIXEL_W-1:0] s_data;
reg  [MAX_LANES-1:0]        s_keep;
reg                         s_sof;
reg                         s_eol;
reg                         s_eof;
reg                         cfg_valid;
wire                        cfg_ready;
reg  signed [8:0]           cfg_angle_deg;
wire signed [8:0]           active_angle_deg;
wire                        m_valid;
reg                         m_ready;
wire [MAX_LANES*PIXEL_W-1:0] m_data;
wire [MAX_LANES-1:0]        m_keep;
wire                        m_sof;
wire                        m_eol;
wire                        m_eof;
wire                        fb_wr_valid;
reg                         fb_wr_ready;
wire [MAX_LANES*ADDR_W-1:0] fb_wr_addr;
wire [MAX_LANES*PIXEL_W-1:0] fb_wr_data;
wire [MAX_LANES-1:0]        fb_wr_keep;
wire                        fb_wr_sof;
wire                        fb_wr_eol;
wire                        fb_wr_eof;
wire                        fb_rd_cmd_valid;
reg                         fb_rd_cmd_ready;
wire [MAX_LANES*ADDR_W-1:0] fb_rd_cmd_addr;
wire [MAX_LANES-1:0]        fb_rd_cmd_keep;
reg                         fb_rd_rsp_valid;
wire                        fb_rd_rsp_ready;
reg  [MAX_LANES*PIXEL_W-1:0] fb_rd_rsp_data;

reg  [PIXEL_W-1:0] frame_mem [0:PIXELS-1];
reg                rd_pending;
reg  [ADDR_W-1:0]  rd_addr_pending;
integer            out_count;
integer            frame_idx;
integer            idx;

task queue_angle;
    input signed [8:0] angle_deg;
    begin
        @(negedge clk);
        cfg_valid     = 1'b1;
        cfg_angle_deg = angle_deg;
        @(negedge clk);
        cfg_valid     = 1'b0;
        cfg_angle_deg = 9'sd0;
    end
endtask

task send_frame_identity;
    input integer base_pixel;
    integer y;
    integer x;
    integer pixel_idx;
    begin
        pixel_idx = 0;
        for (y = 0; y < FRAME_H; y = y + 1) begin
            for (x = 0; x < FRAME_W; x = x + 1) begin
                @(negedge clk);
                s_valid = 1'b1;
                s_data  = base_pixel + pixel_idx;
                s_keep  = 1'b1;
                s_sof   = (x == 0) && (y == 0);
                s_eol   = (x == (FRAME_W - 1));
                s_eof   = (x == (FRAME_W - 1)) && (y == (FRAME_H - 1));
                while (!s_ready) begin
                    @(negedge clk);
                end
                pixel_idx = pixel_idx + 1;
            end
        end
        @(negedge clk);
        s_valid = 1'b0;
        s_data  = {PIXEL_W{1'b0}};
        s_keep  = 1'b0;
        s_sof   = 1'b0;
        s_eol   = 1'b0;
        s_eof   = 1'b0;
    end
endtask

rotate_nearest_stream_mem_seam #(
    .MAX_LANES(MAX_LANES),
    .PIXEL_W  (PIXEL_W),
    .FRAME_W  (FRAME_W),
    .FRAME_H  (FRAME_H),
    .FB_ADDR_W(ADDR_W)
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
    .cfg_angle_deg  (cfg_angle_deg),
    .active_angle_deg(active_angle_deg),
    .m_valid        (m_valid),
    .m_ready        (m_ready),
    .m_data         (m_data),
    .m_keep         (m_keep),
    .m_sof          (m_sof),
    .m_eol          (m_eol),
    .m_eof          (m_eof),
    .fb_wr_valid    (fb_wr_valid),
    .fb_wr_ready    (fb_wr_ready),
    .fb_wr_addr     (fb_wr_addr),
    .fb_wr_data     (fb_wr_data),
    .fb_wr_keep     (fb_wr_keep),
    .fb_wr_sof      (fb_wr_sof),
    .fb_wr_eol      (fb_wr_eol),
    .fb_wr_eof      (fb_wr_eof),
    .fb_rd_cmd_valid(fb_rd_cmd_valid),
    .fb_rd_cmd_ready(fb_rd_cmd_ready),
    .fb_rd_cmd_addr (fb_rd_cmd_addr),
    .fb_rd_cmd_keep (fb_rd_cmd_keep),
    .fb_rd_rsp_valid(fb_rd_rsp_valid),
    .fb_rd_rsp_ready(fb_rd_rsp_ready),
    .fb_rd_rsp_data (fb_rd_rsp_data)
);

always #5 clk = ~clk;

always @(posedge clk) begin
    if (fb_wr_valid && fb_wr_ready && fb_wr_keep[0]) begin
        frame_mem[fb_wr_addr[ADDR_W-1:0]] <= fb_wr_data[PIXEL_W-1:0];
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_pending    <= 1'b0;
        rd_addr_pending <= {ADDR_W{1'b0}};
        fb_rd_rsp_valid <= 1'b0;
        fb_rd_rsp_data  <= {MAX_LANES*PIXEL_W{1'b0}};
    end else begin
        fb_rd_rsp_valid <= 1'b0;
        if (fb_rd_cmd_valid && fb_rd_cmd_ready && fb_rd_cmd_keep[0]) begin
            rd_pending     <= 1'b1;
            rd_addr_pending <= fb_rd_cmd_addr[ADDR_W-1:0];
        end else begin
            rd_pending <= 1'b0;
        end

        if (rd_pending && fb_rd_rsp_ready) begin
            fb_rd_rsp_valid <= 1'b1;
            fb_rd_rsp_data[PIXEL_W-1:0] <= frame_mem[rd_addr_pending];
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_count  <= 0;
        frame_idx  <= 0;
    end else if (m_valid && m_ready) begin
        out_count <= out_count + 1;
        if (frame_idx == 0) begin
            if (m_data[PIXEL_W-1:0] !== out_count[PIXEL_W-1:0]) begin
                $fatal(1, "Frame0 identity output mismatch at %0d: got=%0d", out_count, m_data[PIXEL_W-1:0]);
            end
        end
        if (m_sof && out_count != 0 && frame_idx == 0) begin
            $fatal(1, "Unexpected SOF placement in frame0.");
        end
        if (m_eof) begin
            frame_idx <= frame_idx + 1;
            out_count <= 0;
        end
    end
end

initial begin
    clk            = 1'b0;
    rst_n          = 1'b0;
    s_valid        = 1'b0;
    s_data         = {MAX_LANES*PIXEL_W{1'b0}};
    s_keep         = {MAX_LANES{1'b0}};
    s_sof          = 1'b0;
    s_eol          = 1'b0;
    s_eof          = 1'b0;
    cfg_valid      = 1'b0;
    cfg_angle_deg  = 9'sd0;
    m_ready        = 1'b1;
    fb_wr_ready    = 1'b1;
    fb_rd_cmd_ready = 1'b1;
    fb_rd_rsp_valid = 1'b0;
    fb_rd_rsp_data  = {MAX_LANES*PIXEL_W{1'b0}};
    rd_pending     = 1'b0;
    rd_addr_pending = {ADDR_W{1'b0}};
    out_count      = 0;
    frame_idx      = 0;

    for (idx = 0; idx < PIXELS; idx = idx + 1) begin
        frame_mem[idx] = {PIXEL_W{1'b0}};
    end

    repeat (4) @(posedge clk);
    rst_n = 1'b1;

    send_frame_identity(0);
    wait (frame_idx == 1);

    queue_angle(9'sd90);
    send_frame_identity(16);
    @(posedge clk);
    if (active_angle_deg !== 9'sd90) begin
        $fatal(1, "Queued angle did not commit on next frame start.");
    end

    wait (frame_idx == 2);
    $display("tb_rotate_nearest_stream_mem_seam passed.");
    $finish;
end

initial begin
    #20000;
    $fatal(1, "Timed out waiting for rotate_nearest_stream_mem_seam.");
end

endmodule
