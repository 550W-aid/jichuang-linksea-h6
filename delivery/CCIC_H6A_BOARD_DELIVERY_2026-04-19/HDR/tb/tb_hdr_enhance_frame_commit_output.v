`timescale 1ns / 1ps

module tb_hdr_enhance_frame_commit_output;

    localparam integer MAX_LANES = 1;

    reg                     clk;
    reg                     rst_n;
    reg                     s_valid;
    wire                    s_ready;
    reg  [MAX_LANES*24-1:0] s_data;
    reg  [MAX_LANES-1:0]    s_keep;
    reg                     s_sof;
    reg                     s_eol;
    reg                     s_eof;
    reg                     cfg_valid;
    wire                    cfg_ready;
    reg  [1:0]              cfg_shadow_level;
    reg  [1:0]              cfg_highlight_level;
    wire [1:0]              active_shadow_level;
    wire [1:0]              active_highlight_level;
    wire                    m_valid;
    reg                     m_ready;
    wire [MAX_LANES*24-1:0] m_data;
    wire [MAX_LANES-1:0]    m_keep;
    wire                    m_sof;
    wire                    m_eol;
    wire                    m_eof;

    integer                 timeout_cnt;
    integer                 out_frame_idx;
    reg  [23:0]             frame0_dark_out;
    reg  [23:0]             frame0_bright_out;
    reg  [23:0]             frame1_dark_out;
    reg  [23:0]             frame1_bright_out;

    hdr_enhance_rgb888_stream_std #(
        .MAX_LANES(MAX_LANES)
    ) dut (
        .clk                   (clk),
        .rst_n                 (rst_n),
        .s_valid               (s_valid),
        .s_ready               (s_ready),
        .s_data                (s_data),
        .s_keep                (s_keep),
        .s_sof                 (s_sof),
        .s_eol                 (s_eol),
        .s_eof                 (s_eof),
        .cfg_valid             (cfg_valid),
        .cfg_ready             (cfg_ready),
        .cfg_shadow_level      (cfg_shadow_level),
        .cfg_highlight_level   (cfg_highlight_level),
        .active_shadow_level   (active_shadow_level),
        .active_highlight_level(active_highlight_level),
        .m_valid               (m_valid),
        .m_ready               (m_ready),
        .m_data                (m_data),
        .m_keep                (m_keep),
        .m_sof                 (m_sof),
        .m_eol                 (m_eol),
        .m_eof                 (m_eof)
    );

    always #5 clk = ~clk;

    task send_pixel;
        input [23:0] rgb;
        input        sof;
        input        eof;
        begin
            s_data  <= rgb;
            s_keep  <= 1'b1;
            s_sof   <= sof;
            s_eol   <= 1'b1;
            s_eof   <= eof;
            s_valid <= 1'b1;
            while (!s_ready) begin
                @(posedge clk);
            end
            @(posedge clk);
            s_valid <= 1'b0;
            s_sof   <= 1'b0;
            s_eof   <= 1'b0;
        end
    endtask

    task send_cfg;
        input [1:0] shadow_level;
        input [1:0] highlight_level;
        begin
            cfg_shadow_level    <= shadow_level;
            cfg_highlight_level <= highlight_level;
            cfg_valid           <= 1'b1;
            @(posedge clk);
            cfg_valid           <= 1'b0;
        end
    endtask

    always @(posedge clk) begin
        if (!rst_n) begin
            out_frame_idx     <= -1;
            frame0_dark_out   <= 24'd0;
            frame0_bright_out <= 24'd0;
            frame1_dark_out   <= 24'd0;
            frame1_bright_out <= 24'd0;
        end else if (m_valid && m_ready && m_keep[0]) begin
            if (m_sof) begin
                out_frame_idx <= out_frame_idx + 1;
                if (out_frame_idx + 1 == 0) begin
                    frame0_dark_out <= m_data[23:0];
                end else if (out_frame_idx + 1 == 1) begin
                    frame1_dark_out <= m_data[23:0];
                end
            end

            if (m_eof) begin
                if (out_frame_idx == 0) begin
                    frame0_bright_out <= m_data[23:0];
                end else if (out_frame_idx == 1) begin
                    frame1_bright_out <= m_data[23:0];
                end
            end
        end
    end

    initial begin
        clk                 = 1'b0;
        rst_n               = 1'b0;
        s_valid             = 1'b0;
        s_data              = 24'd0;
        s_keep              = 1'b0;
        s_sof               = 1'b0;
        s_eol               = 1'b0;
        s_eof               = 1'b0;
        cfg_valid           = 1'b0;
        cfg_shadow_level    = 2'd0;
        cfg_highlight_level = 2'd0;
        m_ready             = 1'b1;
        timeout_cnt         = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        send_cfg(2'd0, 2'd0);
        send_pixel(24'h202020, 1'b1, 1'b0);
        send_pixel(24'hE0E0E0, 1'b0, 1'b1);

        send_cfg(2'd3, 2'd3);
        send_pixel(24'h202020, 1'b1, 1'b0);
        send_pixel(24'hE0E0E0, 1'b0, 1'b1);

        while (out_frame_idx < 1 && timeout_cnt < 300) begin
            @(posedge clk);
            timeout_cnt = timeout_cnt + 1;
        end

        if (out_frame_idx < 1) begin
            $display("TB_FAIL timeout waiting for output frames");
            $fatal;
        end

        if (frame1_dark_out[23:16] <= frame0_dark_out[23:16]) begin
            $display("TB_FAIL shadow lift did not increase dark luma");
            $display("frame0_dark_out=%h frame1_dark_out=%h", frame0_dark_out, frame1_dark_out);
            $fatal;
        end

        if (frame1_bright_out[23:16] >= frame0_bright_out[23:16]) begin
            $display("TB_FAIL highlight compression did not reduce bright luma");
            $display("frame0_bright_out=%h frame1_bright_out=%h", frame0_bright_out, frame1_bright_out);
            $fatal;
        end

        $display("TB_PASS hdr frame-latched tone-mapping behavior is correct");
        $finish;
    end

endmodule

