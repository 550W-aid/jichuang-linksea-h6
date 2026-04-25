`timescale 1ns / 1ps

module rotate_nearest_linear_index_mapper #(
    parameter integer IMAGE_W = 640,
    parameter integer IMAGE_H = 480
) (
    input  wire [$clog2(IMAGE_W*IMAGE_H)-1:0] out_linear_idx, // Flattened output-frame pixel index to remap.
    input  wire signed [15:0]                 cos_q8,         // Frame-level cosine in signed Q8 format.
    input  wire signed [15:0]                 sin_q8,         // Frame-level sine in signed Q8 format.
    output wire                               src_inside,     // High when the mapped source coordinate remains inside frame bounds.
    output wire [$clog2(IMAGE_W)-1:0]         src_x,          // Nearest mapped source x coordinate when inside the frame.
    output wire [$clog2(IMAGE_H)-1:0]         src_y,          // Nearest mapped source y coordinate when inside the frame.
    output wire [$clog2(IMAGE_W*IMAGE_H)-1:0] src_linear_idx  // Flattened nearest mapped source index when inside the frame.
);

    wire [$clog2(IMAGE_W)-1:0] out_x;
    wire [$clog2(IMAGE_H)-1:0] out_y;

    assign out_x = out_linear_idx % IMAGE_W;
    assign out_y = out_linear_idx / IMAGE_W;

    rotate_nearest_coord_mapper #(
        .IMAGE_W(IMAGE_W),
        .IMAGE_H(IMAGE_H)
    ) u_coord_mapper (
        .out_x         (out_x),
        .out_y         (out_y),
        .cos_q8        (cos_q8),
        .sin_q8        (sin_q8),
        .src_inside    (src_inside),
        .src_x         (src_x),
        .src_y         (src_y),
        .src_linear_idx(src_linear_idx)
    );

endmodule
