`timescale 1ns / 1ps

module tb_virtual_grab_detect_top;

    reg         clk;
    reg         rst;
    reg         sof;
    reg         eof;
    reg         pixel_valid;
    reg  [11:0] pixel_x;
    reg  [11:0] pixel_y;
    reg  [7:0]  pixel_r;
    reg  [7:0]  pixel_g;
    reg  [7:0]  pixel_b;

    wire [11:0] origin_x;
    wire [11:0] origin_y;
    wire        green_valid;
    wire [11:0] green_x;
    wire [11:0] green_y;
    wire        red_valid;
    wire [11:0] red_x;
    wire [11:0] red_y;
    wire        blue_valid;
    wire [11:0] blue_x;
    wire [11:0] blue_y;

    virtual_grab_detect_top #(
        .IMAGE_WIDTH(640),
        .IMAGE_HEIGHT(480)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sof(sof),
        .eof(eof),
        .pixel_valid(pixel_valid),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_r(pixel_r),
        .pixel_g(pixel_g),
        .pixel_b(pixel_b),
        .origin_x(origin_x),
        .origin_y(origin_y),
        .green_valid(green_valid),
        .green_x(green_x),
        .green_y(green_y),
        .red_valid(red_valid),
        .red_x(red_x),
        .red_y(red_y),
        .blue_valid(blue_valid),
        .blue_x(blue_x),
        .blue_y(blue_y)
    );

    always #5 clk = ~clk;

    task send_pixel;
        input [11:0] x;
        input [11:0] y;
        input [7:0] r;
        input [7:0] g;
        input [7:0] b;
        begin
            pixel_valid = 1'b1;
            pixel_x = x;
            pixel_y = y;
            pixel_r = r;
            pixel_g = g;
            pixel_b = b;
            #10;
        end
    endtask

    task send_block;
        input [11:0] start_x;
        input [11:0] start_y;
        input integer width;
        input integer height;
        input [7:0] r;
        input [7:0] g;
        input [7:0] b;
        integer ix;
        integer iy;
        begin
            for (iy = 0; iy < height; iy = iy + 1) begin
                for (ix = 0; ix < width; ix = ix + 1) begin
                    send_pixel(start_x + ix[11:0], start_y + iy[11:0], r, g, b);
                end
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        sof = 1'b0;
        eof = 1'b0;
        pixel_valid = 1'b0;
        pixel_x = 12'd0;
        pixel_y = 12'd0;
        pixel_r = 8'd0;
        pixel_g = 8'd0;
        pixel_b = 8'd0;

        #30;
        rst = 1'b0;

        sof = 1'b1;
        #10;
        sof = 1'b0;

        send_block(12'd80, 12'd60, 20, 12, 8'd235, 8'd235, 8'd235);
        send_block(12'd100, 12'd120, 4, 4, 8'd220, 8'd20, 8'd20);
        send_block(12'd88, 12'd64, 4, 4, 8'd20, 8'd210, 8'd20);
        send_block(12'd72, 12'd68, 4, 4, 8'd20, 8'd40, 8'd220);

        pixel_valid = 1'b0;
        eof = 1'b1;
        #10;
        eof = 1'b0;

        #40;
        $display("origin=(%0d,%0d)", origin_x, origin_y);
        $display(
            "white valid=%0d bbox=(%0d,%0d)-(%0d,%0d)",
            dut.white_valid,
            dut.white_min_x,
            dut.white_min_y,
            dut.white_max_x,
            dut.white_max_y
        );
        $display("green valid=%0d center=(%0d,%0d)", green_valid, green_x, green_y);
        $display("red valid=%0d center=(%0d,%0d)", red_valid, red_x, red_y);
        $display("blue valid=%0d center=(%0d,%0d)", blue_valid, blue_x, blue_y);
        if ((origin_x != 12'd89) || (origin_y != 12'd65)) begin
            $fatal(1, "expected origin at white cloth center, got (%0d,%0d)", origin_x, origin_y);
        end
        if (!green_valid || !red_valid || !blue_valid) begin
            $fatal(1, "expected all three color blobs to be valid");
        end
        $finish;
    end

endmodule
