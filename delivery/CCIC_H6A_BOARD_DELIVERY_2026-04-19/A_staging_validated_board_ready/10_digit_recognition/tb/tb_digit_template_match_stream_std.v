`timescale 1ns / 1ps

module tb_digit_template_match_stream_std;

    localparam integer NUM_DIGITS    = 3;
    localparam integer DIGIT_W       = 64;
    localparam integer DIGIT_H       = 64;
    localparam integer DIGIT_GAP     = 16;
    localparam integer SAMPLE_STRIDE = 4;
    localparam integer FRAME_WIDTH   = (NUM_DIGITS * DIGIT_W) + ((NUM_DIGITS - 1) * DIGIT_GAP);
    localparam integer FRAME_HEIGHT  = DIGIT_H;
    localparam integer ROI_X         = 0;
    localparam integer ROI_Y         = 0;

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

    wire                           o_digit_valid;
    wire [3:0]                     o_digit_id;
    wire [7:0]                     o_digit_score;
    wire                           o_digits_valid;
    wire [NUM_DIGITS*4-1:0]        o_digit_ids;
    wire [NUM_DIGITS*8-1:0]        o_digit_scores;
    wire [NUM_DIGITS-1:0]          o_digit_present;

    integer x;
    integer y;
    integer timeout_cnt;
    integer slot_id;
    integer slot_x_rel;
    integer gx;
    integer gy;
    reg [3:0] slot_digit;
    reg pix_fg;

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
        .DIGIT_W      (DIGIT_W),
        .DIGIT_H      (DIGIT_H),
        .NUM_DIGITS   (NUM_DIGITS),
        .DIGIT_GAP    (DIGIT_GAP),
        .SAMPLE_STRIDE(SAMPLE_STRIDE),
        .THRESHOLD    (8'd96),
        .MIN_FG_PIX   (9'd8)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .s_valid       (s_valid),
        .s_ready       (s_ready),
        .s_data        (s_data),
        .s_keep        (s_keep),
        .s_sof         (s_sof),
        .s_eol         (s_eol),
        .s_eof         (s_eof),
        .m_valid       (m_valid),
        .m_ready       (m_ready),
        .m_data        (m_data),
        .m_keep        (m_keep),
        .m_sof         (m_sof),
        .m_eol         (m_eol),
        .m_eof         (m_eof),
        .o_digit_valid (o_digit_valid),
        .o_digit_id    (o_digit_id),
        .o_digit_score (o_digit_score),
        .o_digits_valid(o_digits_valid),
        .o_digit_ids   (o_digit_ids),
        .o_digit_scores(o_digit_scores),
        .o_digit_present(o_digit_present)
    );

    always #5 clk = ~clk;

    function template_bit;
        input [3:0] digit;
        input integer gx_in;
        input integer gy_in;
        reg [7:0] idx;
        begin
            idx = gy_in * 16 + gx_in;
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

    task send_frame_three_slots;
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

                    slot_id = x / (DIGIT_W + DIGIT_GAP);
                    slot_x_rel = x % (DIGIT_W + DIGIT_GAP);

                    pix_fg = 1'b0;
                    if ((slot_id < NUM_DIGITS) && (slot_x_rel < DIGIT_W)) begin
                        if (((slot_x_rel % SAMPLE_STRIDE) == (SAMPLE_STRIDE / 2)) &&
                            ((y % SAMPLE_STRIDE) == (SAMPLE_STRIDE / 2))) begin
                            gx = slot_x_rel / SAMPLE_STRIDE;
                            gy = y / SAMPLE_STRIDE;
                            case (slot_id)
                                0: slot_digit = 4'd3;
                                1: slot_digit = 4'd8;
                                default: slot_digit = 4'hF; // Slot2 intentionally blank.
                            endcase
                            if (slot_digit != 4'hF) begin
                                pix_fg = template_bit(slot_digit, gx, gy);
                            end
                        end
                    end

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

    task wait_multi_result;
        begin
            timeout_cnt = 0;
            while ((o_digits_valid !== 1'b1) && (timeout_cnt < 10000)) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end

            if (o_digits_valid !== 1'b1) begin
                $display("TB_FAIL timeout waiting multi-digit output");
                $fatal;
            end

            if (o_digit_present[0] !== 1'b1) begin
                $display("TB_FAIL slot0 present mismatch");
                $fatal;
            end
            if (o_digit_ids[0 +: 4] != 4'd3) begin
                $display("TB_FAIL slot0 expected 3 got %0d", o_digit_ids[0 +: 4]);
                $fatal;
            end
            if (o_digit_present[1] !== 1'b1) begin
                $display("TB_FAIL slot1 present mismatch");
                $fatal;
            end
            if (o_digit_ids[4 +: 4] != 4'd8) begin
                $display("TB_FAIL slot1 expected 8 got %0d", o_digit_ids[4 +: 4]);
                $fatal;
            end
            if (o_digit_present[2] !== 1'b0) begin
                $display("TB_FAIL slot2 should be blank");
                $fatal;
            end
            if (o_digit_ids[8 +: 4] != 4'hF) begin
                $display("TB_FAIL slot2 blank id should be 15 got %0d", o_digit_ids[8 +: 4]);
                $fatal;
            end

            if (o_digit_valid !== 1'b1 || o_digit_id != 4'd3) begin
                $display("TB_FAIL backward-compatible slot0 output mismatch id=%0d", o_digit_id);
                $fatal;
            end
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

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        send_frame_three_slots();
        wait_multi_result();

        $display("TB_PASS multi-slot digit recognition works");
        $finish;
    end

endmodule

