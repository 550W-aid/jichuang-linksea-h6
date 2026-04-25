`timescale 1ns / 1ps

module rgb_color_classifier (
    input  wire [7:0] pixel_r,
    input  wire [7:0] pixel_g,
    input  wire [7:0] pixel_b,
    output wire       is_red,
    output wire       is_green,
    output wire       is_blue,
    output wire       is_white
);

    wire [8:0] diff_rg;
    wire [8:0] diff_rb;
    wire [8:0] diff_gb;

    assign diff_rg = (pixel_r >= pixel_g) ? ({1'b0, pixel_r} - {1'b0, pixel_g}) : ({1'b0, pixel_g} - {1'b0, pixel_r});
    assign diff_rb = (pixel_r >= pixel_b) ? ({1'b0, pixel_r} - {1'b0, pixel_b}) : ({1'b0, pixel_b} - {1'b0, pixel_r});
    assign diff_gb = (pixel_g >= pixel_b) ? ({1'b0, pixel_g} - {1'b0, pixel_b}) : ({1'b0, pixel_b} - {1'b0, pixel_g});

    assign is_red =
        (pixel_r >= 8'd160) &&
        (pixel_g <= 8'd120) &&
        (pixel_b <= 8'd120) &&
        (pixel_r >= pixel_g + 8'd30) &&
        (pixel_r >= pixel_b + 8'd30);

    assign is_green =
        (pixel_g >= 8'd150) &&
        (pixel_r <= 8'd140) &&
        (pixel_b <= 8'd140) &&
        (pixel_g >= pixel_r + 8'd20) &&
        (pixel_g >= pixel_b + 8'd20);

    assign is_blue =
        (pixel_b >= 8'd150) &&
        (pixel_r <= 8'd140) &&
        (pixel_g <= 8'd160) &&
        (pixel_b >= pixel_r + 8'd20) &&
        (pixel_b >= pixel_g + 8'd10);

    assign is_white =
        (pixel_r >= 8'd200) &&
        (pixel_g >= 8'd200) &&
        (pixel_b >= 8'd200) &&
        (diff_rg <= 9'd20) &&
        (diff_rb <= 9'd20) &&
        (diff_gb <= 9'd20);

endmodule
