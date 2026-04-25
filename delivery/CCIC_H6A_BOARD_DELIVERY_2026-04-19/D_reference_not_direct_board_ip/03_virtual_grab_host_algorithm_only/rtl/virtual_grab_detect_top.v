`timescale 1ns / 1ps

module virtual_grab_detect_top #(
    parameter IMAGE_WIDTH  = 1920,
    parameter IMAGE_HEIGHT = 1080,
    parameter X_WIDTH      = 12,
    parameter Y_WIDTH      = 12
) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 sof,
    input  wire                 eof,
    input  wire                 pixel_valid,
    input  wire [X_WIDTH-1:0]   pixel_x,
    input  wire [Y_WIDTH-1:0]   pixel_y,
    input  wire [7:0]           pixel_r,
    input  wire [7:0]           pixel_g,
    input  wire [7:0]           pixel_b,
    output wire [X_WIDTH-1:0]   origin_x,
    output wire [Y_WIDTH-1:0]   origin_y,
    output wire                 green_valid,
    output wire [X_WIDTH-1:0]   green_x,
    output wire [Y_WIDTH-1:0]   green_y,
    output wire                 red_valid,
    output wire [X_WIDTH-1:0]   red_x,
    output wire [Y_WIDTH-1:0]   red_y,
    output wire                 blue_valid,
    output wire [X_WIDTH-1:0]   blue_x,
    output wire [Y_WIDTH-1:0]   blue_y
);

    wire is_red;
    wire is_green;
    wire is_blue;
    wire is_white;

    rgb_color_classifier u_classifier (
        .pixel_r(pixel_r),
        .pixel_g(pixel_g),
        .pixel_b(pixel_b),
        .is_red(is_red),
        .is_green(is_green),
        .is_blue(is_blue),
        .is_white(is_white)
    );

    wire white_valid;
    wire [X_WIDTH-1:0] white_center_x;
    wire [Y_WIDTH-1:0] white_center_y;
    wire [23:0] unused_white_count;
    wire [X_WIDTH-1:0] white_min_x;
    wire [X_WIDTH-1:0] white_max_x;
    wire [Y_WIDTH-1:0] white_min_y;
    wire [Y_WIDTH-1:0] white_max_y;
    wire [23:0] unused_green_count;
    wire [23:0] unused_red_count;
    wire [23:0] unused_blue_count;
    wire [X_WIDTH-1:0] unused_green_min_x;
    wire [X_WIDTH-1:0] unused_green_max_x;
    wire [Y_WIDTH-1:0] unused_green_min_y;
    wire [Y_WIDTH-1:0] unused_green_max_y;
    wire [X_WIDTH-1:0] unused_red_min_x;
    wire [X_WIDTH-1:0] unused_red_max_x;
    wire [Y_WIDTH-1:0] unused_red_min_y;
    wire [Y_WIDTH-1:0] unused_red_max_y;
    wire [X_WIDTH-1:0] unused_blue_min_x;
    wire [X_WIDTH-1:0] unused_blue_max_x;
    wire [Y_WIDTH-1:0] unused_blue_min_y;
    wire [Y_WIDTH-1:0] unused_blue_max_y;
    wire [X_WIDTH:0] origin_x_sum;
    wire [Y_WIDTH:0] origin_y_sum;

    assign origin_x_sum = {1'b0, white_min_x} + {1'b0, white_max_x};
    assign origin_y_sum = {1'b0, white_min_y} + {1'b0, white_max_y};
    assign origin_x = white_valid ? origin_x_sum[X_WIDTH:1] : (IMAGE_WIDTH / 2);
    assign origin_y = white_valid ? origin_y_sum[Y_WIDTH:1] : (IMAGE_HEIGHT / 2);

    blob_stats #(
        .X_WIDTH(X_WIDTH),
        .Y_WIDTH(Y_WIDTH)
    ) u_white_stats (
        .clk(clk),
        .rst(rst),
        .sof(sof),
        .eof(eof),
        .pixel_valid(pixel_valid),
        .pixel_match(is_white),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .blob_valid(white_valid),
        .center_x(white_center_x),
        .center_y(white_center_y),
        .pixel_count(unused_white_count),
        .min_x(white_min_x),
        .max_x(white_max_x),
        .min_y(white_min_y),
        .max_y(white_max_y)
    );

    blob_stats u_green_stats (
        .clk(clk),
        .rst(rst),
        .sof(sof),
        .eof(eof),
        .pixel_valid(pixel_valid),
        .pixel_match(is_green),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .blob_valid(green_valid),
        .center_x(green_x),
        .center_y(green_y),
        .pixel_count(unused_green_count),
        .min_x(unused_green_min_x),
        .max_x(unused_green_max_x),
        .min_y(unused_green_min_y),
        .max_y(unused_green_max_y)
    );

    blob_stats u_red_stats (
        .clk(clk),
        .rst(rst),
        .sof(sof),
        .eof(eof),
        .pixel_valid(pixel_valid),
        .pixel_match(is_red),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .blob_valid(red_valid),
        .center_x(red_x),
        .center_y(red_y),
        .pixel_count(unused_red_count),
        .min_x(unused_red_min_x),
        .max_x(unused_red_max_x),
        .min_y(unused_red_min_y),
        .max_y(unused_red_max_y)
    );

    blob_stats u_blue_stats (
        .clk(clk),
        .rst(rst),
        .sof(sof),
        .eof(eof),
        .pixel_valid(pixel_valid),
        .pixel_match(is_blue),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .blob_valid(blue_valid),
        .center_x(blue_x),
        .center_y(blue_y),
        .pixel_count(unused_blue_count),
        .min_x(unused_blue_min_x),
        .max_x(unused_blue_max_x),
        .min_y(unused_blue_min_y),
        .max_y(unused_blue_max_y)
    );

endmodule
