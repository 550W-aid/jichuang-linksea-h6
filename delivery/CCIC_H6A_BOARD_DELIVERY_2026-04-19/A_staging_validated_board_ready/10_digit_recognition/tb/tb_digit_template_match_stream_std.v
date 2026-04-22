`timescale 1ns / 1ps

module tb_digit_template_match_stream_std;

    localparam integer FRAME_WIDTH   = 64;
    localparam integer FRAME_HEIGHT  = 64;
    localparam integer ROI_X         = 0;
    localparam integer ROI_Y         = 0;
    localparam integer ROI_W         = 64;
    localparam integer ROI_H         = 64;
    localparam integer SAMPLE_STRIDE = 4;

    reg         clk;
    reg         rst_n;
    reg         s_valid;
    wire        s_ready;
    reg  [23:0] s_data;
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
    wire        o_digit_valid;
    wire [3:0]  o_digit_id;
    wire [7:0]  o_digit_score;

    integer x;
    integer y;
    integer timeout_cnt;
    integer hit_count;

    localparam [255:0] TEMPLATE_0 = 256'h00001ff81ff860066006600660060000000060066006600660061ff81ff80000;
    localparam [255:0] TEMPLATE_1 = 256'h0000000000000006000600060006000000000006000600060006000000000000;
    localparam [255:0] TEMPLATE_2 = 256'h00001ff81ff800060006000600061ff81ff860006000600060001ff81ff80000;
    localparam [255:0] TEMPLATE_3 = 256'h00001ff81ff800060006000600061ff81ff800060006000600061ff81ff80000;
    localparam [255:0] TEMPLATE_4 = 256'h00000000000060066006600660061ff81ff80006000600060006000000000000;
    localparam [255:0] TEMPLATE_5 = 256'h00001ff81ff860006000600060001ff81ff800060006000600061ff81ff80000;
    localparam [255:0] TEMPLATE_6 = 256'h00001ff81ff860006000600060001ff81ff860066006600660061ff81ff80000;
    localparam [255:0] TEMPLATE_7 = 256'h00001ff81ff80006000600060006000000000006000600060006000000000000;
    localparam [255:0] TEMPLATE_8 = 256'h00001ff81ff860066006600660061ff81ff860066006600660061ff81ff80000;
    localparam [255:0] TEMPLATE_9 = 256'h00001ff81ff860066006600660061ff81ff800060006000600061ff81ff80000;

    digit_template_match_stream_std #(
        .FRAME_WIDTH  (FRAME_WIDTH),
        .FRAME_HEIGHT (FRAME_HEIGHT),
        .ROI_X        (ROI_X),
        .ROI_Y        (ROI_Y),
        .ROI_W        (ROI_W),
        .ROI_H        (ROI_H),
        .SAMPLE_STRIDE(SAMPLE_STRIDE),
        .THRESHOLD    (8'd96)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .s_valid     (s_valid),
        .s_ready     (s_ready),
        .s_data      (s_data),
        .s_keep      (s_keep),
        .s_sof       (s_sof),
        .s_eol       (s_eol),
        .s_eof       (s_eof),
        .m_valid     (m_valid),
        .m_ready     (m_ready),
        .m_data      (m_data),
        .m_keep      (m_keep),
        .m_sof       (m_sof),
        .m_eol       (m_eol),
        .m_eof       (m_eof),
        .o_digit_valid(o_digit_valid),
        .o_digit_id  (o_digit_id),
        .o_digit_score(o_digit_score)
    );

    always #5 clk = ~clk;

    function template_bit;
        input [3:0] digit;
        input integer gx;
        input integer gy;
        reg [7:0] idx;
        begin
            idx = gy * 16 + gx;
            case (digit)
                4'd0: template_bit = TEMPLATE_0[8'd255 - idx];
                4'd1: template_bit = TEMPLATE_1[8'd255 - idx];
                4'd2: template_bit = TEMPLATE_2[8'd255 - idx];
                4'd3: template_bit = TEMPLATE_3[8'd255 - idx];
                4'd4: template_bit = TEMPLATE_4[8'd255 - idx];
                4'd5: template_bit = TEMPLATE_5[8'd255 - idx];
                4'd6: template_bit = TEMPLATE_6[8'd255 - idx];
                4'd7: template_bit = TEMPLATE_7[8'd255 - idx];
                4'd8: template_bit = TEMPLATE_8[8'd255 - idx];
                default: template_bit = TEMPLATE_9[8'd255 - idx];
            endcase
        end
    endfunction

    task send_frame_with_digit;
        input [3:0] digit;
        reg pix_fg;
        integer gx;
        integer gy;
        begin
            for (y = 0; y < FRAME_HEIGHT; y = y + 1) begin
                for (x = 0; x < FRAME_WIDTH; x = x + 1) begin
                    while (!s_ready) begin
                        @(posedge clk);
                    end

                    s_valid <= 1'b1;
                    s_keep  <= 1'b1;
                    s_sof   <= (x == 0 && y == 0);
                    s_eol   <= (x == FRAME_WIDTH - 1);
                    s_eof   <= (x == FRAME_WIDTH - 1 && y == FRAME_HEIGHT - 1);

                    if (((x % SAMPLE_STRIDE) == (SAMPLE_STRIDE / 2)) &&
                        ((y % SAMPLE_STRIDE) == (SAMPLE_STRIDE / 2))) begin
                        gx = x / SAMPLE_STRIDE;
                        gy = y / SAMPLE_STRIDE;
                        pix_fg = template_bit(digit, gx, gy);
                    end else begin
                        pix_fg = 1'b0;
                    end

                    // Foreground digit is dark, background is white.
                    s_data <= pix_fg ? 24'h000000 : 24'hFFFFFF;
                    @(posedge clk);
                end
            end

            s_valid <= 1'b0;
            s_sof   <= 1'b0;
            s_eol   <= 1'b0;
            s_eof   <= 1'b0;
            s_keep  <= 1'b0;
            s_data  <= 24'd0;
        end
    endtask

    task wait_result;
        input [3:0] expected;
        begin
            timeout_cnt = 0;
            while ((o_digit_valid !== 1'b1) && (timeout_cnt < 5000)) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end

            if (o_digit_valid !== 1'b1) begin
                $display("TB_FAIL timeout waiting recognition output");
                $fatal;
            end

            if (o_digit_id != expected) begin
                $display("TB_FAIL expected=%0d got=%0d score=%0d", expected, o_digit_id, o_digit_score);
                $fatal;
            end

            hit_count = hit_count + 1;
            @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        s_valid = 1'b0;
        s_data = 24'd0;
        s_keep = 1'b0;
        s_sof = 1'b0;
        s_eol = 1'b0;
        s_eof = 1'b0;
        m_ready = 1'b1;
        timeout_cnt = 0;
        hit_count = 0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        send_frame_with_digit(4'd3);
        wait_result(4'd3);
        send_frame_with_digit(4'd8);
        wait_result(4'd8);

        $display("TB_PASS digit template matching works for frame-wise recognition");
        $finish;
    end

endmodule
