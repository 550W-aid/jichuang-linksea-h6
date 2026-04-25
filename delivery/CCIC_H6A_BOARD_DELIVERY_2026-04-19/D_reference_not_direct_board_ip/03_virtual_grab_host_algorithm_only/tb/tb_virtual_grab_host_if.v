`timescale 1ns / 1ps

module tb_virtual_grab_host_if;

    localparam integer X_WIDTH = 12;
    localparam integer Y_WIDTH = 12;
    localparam integer AREA_WIDTH = 16;

    reg clk;
    reg rst_n;

    reg rx_valid;
    reg [7:0] rx_data;
    wire tx_valid;
    wire [7:0] tx_data;
    wire tx_last;
    reg tx_ready;

    reg red_valid;
    reg [X_WIDTH-1:0] red_x;
    reg [Y_WIDTH-1:0] red_y;
    reg origin_valid;
    reg [X_WIDTH-1:0] origin_x;
    reg [Y_WIDTH-1:0] origin_y;
    reg green_valid;
    reg [X_WIDTH-1:0] green_x;
    reg [Y_WIDTH-1:0] green_y;
    reg hand_update;
    reg hand_valid;
    reg [X_WIDTH-1:0] hand_x;
    reg [Y_WIDTH-1:0] hand_y;
    reg [AREA_WIDTH-1:0] hand_area;
    reg grab_btn_raw;
    reg release_btn_raw;

    wire streaming_enable;
    wire calibrated_valid;

    reg [7:0] tx_frame [0:31];
    integer tx_count;
    reg tx_capturing;
    reg tx_frame_done;
    integer idx;

    virtual_grab_host_if #(
        .X_WIDTH          (X_WIDTH),
        .Y_WIDTH          (Y_WIDTH),
        .AREA_WIDTH       (AREA_WIDTH),
        .BTN_STABLE_CYCLES(2)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .rx_valid        (rx_valid),
        .rx_data         (rx_data),
        .tx_valid        (tx_valid),
        .tx_data         (tx_data),
        .tx_last         (tx_last),
        .tx_ready        (tx_ready),
        .red_valid       (red_valid),
        .red_x           (red_x),
        .red_y           (red_y),
        .origin_valid    (origin_valid),
        .origin_x        (origin_x),
        .origin_y        (origin_y),
        .green_valid     (green_valid),
        .green_x         (green_x),
        .green_y         (green_y),
        .hand_update     (hand_update),
        .hand_valid      (hand_valid),
        .hand_x          (hand_x),
        .hand_y          (hand_y),
        .hand_area       (hand_area),
        .grab_btn_raw    (grab_btn_raw),
        .release_btn_raw (release_btn_raw),
        .streaming_enable(streaming_enable),
        .calibrated_valid(calibrated_valid)
    );

    always #5 clk = ~clk;

    task send_byte;
        input [7:0] value;
        begin
            @(negedge clk);
            rx_valid = 1'b1;
            rx_data = value;
            @(negedge clk);
            rx_valid = 1'b0;
            rx_data = 8'h00;
        end
    endtask

    task send_command;
        input [7:0] msg_type;
        begin
            send_byte(8'h55);
            send_byte(8'hAA);
            send_byte(msg_type);
            send_byte(8'h00);
            send_byte(msg_type);
        end
    endtask

    task pulse_hand_update;
        begin
            @(negedge clk);
            hand_update = 1'b1;
            @(negedge clk);
            hand_update = 1'b0;
        end
    endtask

    task wait_frame_done;
        begin
            wait (tx_frame_done == 1'b1);
            @(posedge clk);
            tx_frame_done = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        rx_valid = 1'b0;
        rx_data = 8'h00;
        tx_ready = 1'b1;
        red_valid = 1'b1;
        red_x = 12'd321;
        red_y = 12'd234;
        origin_valid = 1'b1;
        origin_x = 12'd640;
        origin_y = 12'd360;
        green_valid = 1'b1;
        green_x = 12'd700;
        green_y = 12'd360;
        hand_update = 1'b0;
        hand_valid = 1'b1;
        hand_x = 12'd100;
        hand_y = 12'd120;
        hand_area = 16'd88;
        grab_btn_raw = 1'b0;
        release_btn_raw = 1'b0;
        tx_count = 0;
        tx_capturing = 1'b0;
        tx_frame_done = 1'b0;

        repeat (4) @(negedge clk);
        rst_n = 1'b1;

        send_command(8'h10);
        wait_frame_done();
        if (!calibrated_valid) begin
            $fatal(1, "calibration flag was not set after CALIBRATE_REQ");
        end
        if (tx_count != 20) begin
            $fatal(1, "unexpected calibrate frame length %0d", tx_count);
        end
        if (tx_frame[0] != 8'h55 || tx_frame[1] != 8'hAA || tx_frame[2] != 8'h20 || tx_frame[3] != 8'd15) begin
            $fatal(1, "unexpected calibrate header");
        end

        send_command(8'h11);
        wait_frame_done();
        if (!streaming_enable) begin
            $fatal(1, "streaming_enable was not set after START_REQ");
        end
        if (tx_frame[2] != 8'h22 || tx_frame[3] != 8'd1 || tx_frame[4] != 8'h02) begin
            $fatal(1, "unexpected status response after START_REQ");
        end

        grab_btn_raw = 1'b1;
        repeat (4) @(negedge clk);
        grab_btn_raw = 1'b0;
        hand_x = 12'd444;
        hand_y = 12'd222;
        hand_area = 16'd99;
        pulse_hand_update();
        wait_frame_done();
        if (tx_frame[2] != 8'h21 || tx_frame[3] != 8'd11) begin
            $fatal(1, "unexpected hand report header");
        end
        if (tx_frame[4] != 8'h00 || tx_frame[5] != 8'h01 || tx_frame[6] != 8'h01) begin
            $fatal(1, "unexpected frame id or hand_valid in report");
        end
        if (tx_frame[7] != 8'h01 || tx_frame[8] != 8'hBC || tx_frame[9] != 8'h00 || tx_frame[10] != 8'hDE) begin
            $fatal(1, "unexpected hand coordinates in report");
        end
        if (tx_frame[11] != 8'h00 || tx_frame[12] != 8'h63 || tx_frame[13] != 8'h01 || tx_frame[14] != 8'h00) begin
            $fatal(1, "unexpected hand area or button event payload");
        end

        send_command(8'h12);
        wait_frame_done();
        if (streaming_enable) begin
            $fatal(1, "streaming_enable was not cleared after STOP_REQ");
        end
        if (tx_frame[2] != 8'h22 || tx_frame[4] != 8'h01) begin
            $fatal(1, "unexpected status response after STOP_REQ");
        end

        hand_x = 12'd500;
        hand_y = 12'd333;
        pulse_hand_update();
        repeat (8) @(posedge clk);
        if (tx_frame_done) begin
            $fatal(1, "unexpected hand report while streaming disabled");
        end

        $display("tb_virtual_grab_host_if passed.");
        $finish;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_count <= 0;
            tx_capturing <= 1'b0;
            tx_frame_done <= 1'b0;
            for (idx = 0; idx < 32; idx = idx + 1) begin
                tx_frame[idx] <= 8'h00;
            end
        end else begin
            tx_frame_done <= 1'b0;

            if (tx_valid && tx_ready) begin
                if (!tx_capturing) begin
                    tx_frame[0] <= tx_data;
                    tx_count <= 1;

                    if (tx_last) begin
                        tx_capturing <= 1'b0;
                        tx_frame_done <= 1'b1;
                    end else begin
                        tx_capturing <= 1'b1;
                    end
                end else begin
                    tx_frame[tx_count] <= tx_data;
                    tx_count <= tx_count + 1;

                    if (tx_last) begin
                        tx_capturing <= 1'b0;
                        tx_frame_done <= 1'b1;
                    end
                end
            end
        end
    end

endmodule
