`timescale 1ns / 1ps

module rotate_nearest_coord_mapper #(
    parameter integer IMAGE_W = 640,
    parameter integer IMAGE_H = 480
) (
    input  wire [$clog2(IMAGE_W)-1:0]         out_x,          // Requested output-frame x coordinate to remap.
    input  wire [$clog2(IMAGE_H)-1:0]         out_y,          // Requested output-frame y coordinate to remap.
    input  wire signed [15:0]                 cos_q8,         // Frame-level cosine in signed Q8 format.
    input  wire signed [15:0]                 sin_q8,         // Frame-level sine in signed Q8 format.
    output reg                                src_inside,     // High when the mapped source coordinate remains inside frame bounds.
    output reg  [$clog2(IMAGE_W)-1:0]         src_x,          // Nearest mapped source x coordinate when inside the frame.
    output reg  [$clog2(IMAGE_H)-1:0]         src_y,          // Nearest mapped source y coordinate when inside the frame.
    output reg  [$clog2(IMAGE_W*IMAGE_H)-1:0] src_linear_idx  // Flattened nearest mapped source index when inside the frame.
);

    localparam integer CENTER_X_Q8 = ((IMAGE_W - 1) * 256) / 2;
    localparam integer CENTER_Y_Q8 = ((IMAGE_H - 1) * 256) / 2;

    integer dx_q8;
    integer dy_q8;
    integer src_x_q16;
    integer src_y_q16;
    integer src_x_q8;
    integer src_y_q8;
    integer src_x_int;
    integer src_y_int;
    integer src_linear_idx_int;

    // Convert one output-frame coordinate into the nearest source-frame coordinate and flattened address.
    always @* begin
        src_inside     = 1'b0;
        src_x          = {$clog2(IMAGE_W){1'b0}};
        src_y          = {$clog2(IMAGE_H){1'b0}};
        src_linear_idx = {$clog2(IMAGE_W*IMAGE_H){1'b0}};

        dx_q8    = (out_x * 256) - CENTER_X_Q8;
        dy_q8    = (out_y * 256) - CENTER_Y_Q8;
        src_x_q16 = (cos_q8 * dx_q8) + (sin_q8 * dy_q8);
        src_y_q16 = ((-sin_q8) * dx_q8) + (cos_q8 * dy_q8);
        src_x_q8  = ((src_x_q16 >= 0) ? (src_x_q16 + 128) : (src_x_q16 - 128)) / 256 + CENTER_X_Q8;
        src_y_q8  = ((src_y_q16 >= 0) ? (src_y_q16 + 128) : (src_y_q16 - 128)) / 256 + CENTER_Y_Q8;
        src_x_int = (src_x_q8 + 128) / 256;
        src_y_int = (src_y_q8 + 128) / 256;
        src_linear_idx_int = (src_y_int * IMAGE_W) + src_x_int;

        if ((src_x_int >= 0) && (src_x_int < IMAGE_W) &&
            (src_y_int >= 0) && (src_y_int < IMAGE_H)) begin
            src_inside     = 1'b1;
            src_x          = src_x_int[$clog2(IMAGE_W)-1:0];
            src_y          = src_y_int[$clog2(IMAGE_H)-1:0];
            src_linear_idx = src_linear_idx_int[$clog2(IMAGE_W*IMAGE_H)-1:0];
        end
    end

endmodule
