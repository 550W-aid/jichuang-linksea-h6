`timescale 1ns / 1ps

module virtual_grab_host_bridge_top #(
    parameter integer IMAGE_WIDTH        = 1920,
    parameter integer IMAGE_HEIGHT       = 1080,
    parameter integer X_WIDTH            = 12,
    parameter integer Y_WIDTH            = 12,
    parameter integer AREA_WIDTH         = 16,
    parameter integer BTN_STABLE_CYCLES  = 4
) (
    input  wire                   clk,              // Processing clock.
    input  wire                   rst_n,            // Active-low reset.
    input  wire                   sof,              // Start-of-frame pulse for the pixel stream.
    input  wire                   eof,              // End-of-frame pulse for the pixel stream.
    input  wire                   pixel_valid,      // Pixel-valid strobe for the pixel stream.
    input  wire [X_WIDTH-1:0]     pixel_x,          // Current pixel X coordinate.
    input  wire [Y_WIDTH-1:0]     pixel_y,          // Current pixel Y coordinate.
    input  wire [7:0]             pixel_r,          // Current pixel red component.
    input  wire [7:0]             pixel_g,          // Current pixel green component.
    input  wire [7:0]             pixel_b,          // Current pixel blue component.
    input  wire                   rx_valid,         // Input command byte valid strobe.
    input  wire [7:0]             rx_data,          // Input command byte value.
    output wire                   tx_valid,         // Output packet byte valid strobe.
    output wire [7:0]             tx_data,          // Output packet byte value.
    output wire                   tx_last,          // Output packet end marker.
    input  wire                   tx_ready,         // Downstream byte-ready handshake.
    input  wire                   grab_btn_raw,     // Hidden raw grab button input.
    input  wire                   release_btn_raw,  // Hidden raw release button input.
    output wire                   streaming_enable, // High while periodic hand reporting is enabled.
    output wire                   calibrated_valid  // High after a successful calibration snapshot.
);

    wire origin_valid;
    wire [X_WIDTH-1:0] origin_x;
    wire [Y_WIDTH-1:0] origin_y;
    wire green_valid;
    wire [X_WIDTH-1:0] green_x;
    wire [Y_WIDTH-1:0] green_y;
    wire red_valid;
    wire [X_WIDTH-1:0] red_x;
    wire [Y_WIDTH-1:0] red_y;
    wire blue_valid;
    wire [X_WIDTH-1:0] blue_x;
    wire [Y_WIDTH-1:0] blue_y;

    reg frame_done_d1_reg;
    wire frame_commit_pulse;

    virtual_grab_detect_top #(
        .IMAGE_WIDTH (IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .X_WIDTH     (X_WIDTH),
        .Y_WIDTH     (Y_WIDTH)
    ) u_detect_top (
        .clk        (clk),
        .rst        (~rst_n),
        .sof        (sof),
        .eof        (eof),
        .pixel_valid(pixel_valid),
        .pixel_x    (pixel_x),
        .pixel_y    (pixel_y),
        .pixel_r    (pixel_r),
        .pixel_g    (pixel_g),
        .pixel_b    (pixel_b),
        .origin_x   (origin_x),
        .origin_y   (origin_y),
        .green_valid(green_valid),
        .green_x    (green_x),
        .green_y    (green_y),
        .red_valid  (red_valid),
        .red_x      (red_x),
        .red_y      (red_y),
        .blue_valid (blue_valid),
        .blue_x     (blue_x),
        .blue_y     (blue_y)
    );

    assign origin_valid = 1'b1;
    assign frame_commit_pulse = frame_done_d1_reg;

    // Delay the raw frame-end pulse so the host interface samples the detector outputs
    // after the blob statistics have committed the new frame result.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_done_d1_reg <= 1'b0;
        end else begin
            frame_done_d1_reg <= pixel_valid && eof;
        end
    end

    virtual_grab_host_if #(
        .X_WIDTH          (X_WIDTH),
        .Y_WIDTH          (Y_WIDTH),
        .AREA_WIDTH       (AREA_WIDTH),
        .BTN_STABLE_CYCLES(BTN_STABLE_CYCLES)
    ) u_host_if (
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
        .hand_update     (frame_commit_pulse),
        .hand_valid      (blue_valid),
        .hand_x          (blue_x),
        .hand_y          (blue_y),
        .hand_area       ({AREA_WIDTH{1'b0}}),
        .grab_btn_raw    (grab_btn_raw),
        .release_btn_raw (release_btn_raw),
        .streaming_enable(streaming_enable),
        .calibrated_valid(calibrated_valid)
    );

endmodule
