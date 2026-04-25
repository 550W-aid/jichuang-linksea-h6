`timescale 1ns / 1ps

module virtual_grab_host_if #(
    parameter integer X_WIDTH           = 12,
    parameter integer Y_WIDTH           = 12,
    parameter integer AREA_WIDTH        = 16,
    parameter integer BTN_STABLE_CYCLES = 4
) (
    input  wire                   clk,              // Processing clock.
    input  wire                   rst_n,            // Active-low reset.
    input  wire                   rx_valid,         // Input command byte valid strobe.
    input  wire [7:0]             rx_data,          // Input command byte value.
    output wire                   tx_valid,         // Output packet byte valid strobe.
    output wire [7:0]             tx_data,          // Output packet byte value.
    output wire                   tx_last,          // Output packet end marker.
    input  wire                   tx_ready,         // Downstream byte-ready handshake.
    input  wire                   red_valid,        // Current red target valid bit.
    input  wire [X_WIDTH-1:0]     red_x,            // Current red target X coordinate.
    input  wire [Y_WIDTH-1:0]     red_y,            // Current red target Y coordinate.
    input  wire                   origin_valid,     // Current white origin valid bit.
    input  wire [X_WIDTH-1:0]     origin_x,         // Current white origin X coordinate.
    input  wire [Y_WIDTH-1:0]     origin_y,         // Current white origin Y coordinate.
    input  wire                   green_valid,      // Current green reference valid bit.
    input  wire [X_WIDTH-1:0]     green_x,          // Current green reference X coordinate.
    input  wire [Y_WIDTH-1:0]     green_y,          // Current green reference Y coordinate.
    input  wire                   hand_update,      // One-cycle pulse when fresh hand data is ready.
    input  wire                   hand_valid,       // Current hand valid bit.
    input  wire [X_WIDTH-1:0]     hand_x,           // Current hand X coordinate.
    input  wire [Y_WIDTH-1:0]     hand_y,           // Current hand Y coordinate.
    input  wire [AREA_WIDTH-1:0]  hand_area,        // Current hand area statistic.
    input  wire                   grab_btn_raw,     // Hidden raw grab button input.
    input  wire                   release_btn_raw,  // Hidden raw release button input.
    output wire                   streaming_enable, // High while periodic hand reporting is enabled.
    output wire                   calibrated_valid  // High after a successful calibration snapshot.
);

    localparam [1:0] PACKET_KIND_CALIB  = 2'd0;
    localparam [1:0] PACKET_KIND_HAND   = 2'd1;
    localparam [1:0] PACKET_KIND_STATUS = 2'd2;

    localparam [7:0] RUN_STATE_IDLE       = 8'h00;
    localparam [7:0] RUN_STATE_CALIBRATED = 8'h01;
    localparam [7:0] RUN_STATE_STREAMING  = 8'h02;

    wire cmd_calibrate_wire;
    wire cmd_start_wire;
    wire cmd_stop_wire;
    wire cmd_error_wire;
    wire grab_btn_event_wire;
    wire release_btn_event_wire;
    wire tx_busy_wire;

    reg streaming_enable_reg;
    reg calibrated_valid_reg;
    reg [15:0] frame_id_reg;
    reg grab_event_pending_reg;
    reg release_event_pending_reg;

    reg pending_calib_rsp_reg;
    reg pending_status_rsp_reg;
    reg pending_hand_rsp_reg;

    reg calib_valid_rsp_reg;
    reg [X_WIDTH-1:0] red_x_rsp_reg;
    reg [Y_WIDTH-1:0] red_y_rsp_reg;
    reg origin_valid_rsp_reg;
    reg [X_WIDTH-1:0] origin_x_rsp_reg;
    reg [Y_WIDTH-1:0] origin_y_rsp_reg;
    reg green_valid_rsp_reg;
    reg [X_WIDTH-1:0] green_x_rsp_reg;
    reg [Y_WIDTH-1:0] green_y_rsp_reg;

    reg [7:0] status_rsp_reg;

    reg [15:0] hand_frame_id_rsp_reg;
    reg hand_valid_rsp_reg;
    reg [X_WIDTH-1:0] hand_x_rsp_reg;
    reg [Y_WIDTH-1:0] hand_y_rsp_reg;
    reg [AREA_WIDTH-1:0] hand_area_rsp_reg;
    reg hand_grab_event_rsp_reg;
    reg hand_release_event_rsp_reg;

    wire start_calib_rsp_wire;
    wire start_status_rsp_wire;
    wire start_hand_rsp_wire;
    wire tx_start_wire;
    wire [1:0] tx_packet_kind_wire;
    wire capture_grab_event_wire;
    wire capture_release_event_wire;

    assign streaming_enable = streaming_enable_reg;
    assign calibrated_valid = calibrated_valid_reg;

    assign capture_grab_event_wire = grab_event_pending_reg | grab_btn_event_wire;
    assign capture_release_event_wire = release_event_pending_reg | release_btn_event_wire;

    assign start_calib_rsp_wire = (!tx_busy_wire) && pending_calib_rsp_reg;
    assign start_status_rsp_wire = (!tx_busy_wire) && (!pending_calib_rsp_reg) && pending_status_rsp_reg;
    assign start_hand_rsp_wire = (!tx_busy_wire) && (!pending_calib_rsp_reg) && (!pending_status_rsp_reg) && pending_hand_rsp_reg;

    assign tx_start_wire = start_calib_rsp_wire | start_status_rsp_wire | start_hand_rsp_wire;
    assign tx_packet_kind_wire =
        start_calib_rsp_wire ? PACKET_KIND_CALIB :
        start_status_rsp_wire ? PACKET_KIND_STATUS :
                                PACKET_KIND_HAND;

    virtual_grab_cmd_rx u_cmd_rx (
        .clk              (clk),
        .rst_n            (rst_n),
        .rx_valid         (rx_valid),
        .rx_data          (rx_data),
        .cmd_calibrate    (cmd_calibrate_wire),
        .cmd_start        (cmd_start_wire),
        .cmd_stop         (cmd_stop_wire),
        .packet_error_pulse(cmd_error_wire)
    );

    virtual_grab_button_event #(
        .STABLE_CYCLES(BTN_STABLE_CYCLES)
    ) u_grab_btn (
        .clk        (clk),
        .rst_n      (rst_n),
        .button_raw (grab_btn_raw),
        .press_pulse(grab_btn_event_wire)
    );

    virtual_grab_button_event #(
        .STABLE_CYCLES(BTN_STABLE_CYCLES)
    ) u_release_btn (
        .clk        (clk),
        .rst_n      (rst_n),
        .button_raw (release_btn_raw),
        .press_pulse(release_btn_event_wire)
    );

    virtual_grab_packet_tx #(
        .X_WIDTH   (X_WIDTH),
        .Y_WIDTH   (Y_WIDTH),
        .AREA_WIDTH(AREA_WIDTH)
    ) u_packet_tx (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (tx_start_wire),
        .packet_kind  (tx_packet_kind_wire),
        .tx_ready     (tx_ready),
        .calib_valid  (calib_valid_rsp_reg),
        .red_x        (red_x_rsp_reg),
        .red_y        (red_y_rsp_reg),
        .origin_valid (origin_valid_rsp_reg),
        .origin_x     (origin_x_rsp_reg),
        .origin_y     (origin_y_rsp_reg),
        .green_valid  (green_valid_rsp_reg),
        .green_x      (green_x_rsp_reg),
        .green_y      (green_y_rsp_reg),
        .frame_id     (hand_frame_id_rsp_reg),
        .hand_valid   (hand_valid_rsp_reg),
        .hand_x       (hand_x_rsp_reg),
        .hand_y       (hand_y_rsp_reg),
        .hand_area    (hand_area_rsp_reg),
        .grab_event   (hand_grab_event_rsp_reg),
        .release_event(hand_release_event_rsp_reg),
        .run_state    (status_rsp_reg),
        .busy         (tx_busy_wire),
        .tx_valid     (tx_valid),
        .tx_data      (tx_data),
        .tx_last      (tx_last)
    );

    // Maintain run state, latch outgoing packet snapshots, and arbitrate packet launch order.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            streaming_enable_reg      <= 1'b0;
            calibrated_valid_reg      <= 1'b0;
            frame_id_reg              <= 16'h0000;
            grab_event_pending_reg    <= 1'b0;
            release_event_pending_reg <= 1'b0;
            pending_calib_rsp_reg     <= 1'b0;
            pending_status_rsp_reg    <= 1'b0;
            pending_hand_rsp_reg      <= 1'b0;
            calib_valid_rsp_reg       <= 1'b0;
            red_x_rsp_reg             <= {X_WIDTH{1'b0}};
            red_y_rsp_reg             <= {Y_WIDTH{1'b0}};
            origin_valid_rsp_reg      <= 1'b0;
            origin_x_rsp_reg          <= {X_WIDTH{1'b0}};
            origin_y_rsp_reg          <= {Y_WIDTH{1'b0}};
            green_valid_rsp_reg       <= 1'b0;
            green_x_rsp_reg           <= {X_WIDTH{1'b0}};
            green_y_rsp_reg           <= {Y_WIDTH{1'b0}};
            status_rsp_reg            <= RUN_STATE_IDLE;
            hand_frame_id_rsp_reg     <= 16'h0000;
            hand_valid_rsp_reg        <= 1'b0;
            hand_x_rsp_reg            <= {X_WIDTH{1'b0}};
            hand_y_rsp_reg            <= {Y_WIDTH{1'b0}};
            hand_area_rsp_reg         <= {AREA_WIDTH{1'b0}};
            hand_grab_event_rsp_reg   <= 1'b0;
            hand_release_event_rsp_reg<= 1'b0;
        end else begin
            if (grab_btn_event_wire) begin
                grab_event_pending_reg <= 1'b1;
            end

            if (release_btn_event_wire) begin
                release_event_pending_reg <= 1'b1;
            end

            if (cmd_calibrate_wire) begin
                calibrated_valid_reg <= red_valid;
                streaming_enable_reg <= 1'b0;
                pending_calib_rsp_reg <= 1'b1;
                pending_status_rsp_reg <= 1'b0;
                pending_hand_rsp_reg <= 1'b0;
                frame_id_reg <= 16'h0000;
                grab_event_pending_reg <= 1'b0;
                release_event_pending_reg <= 1'b0;

                calib_valid_rsp_reg  <= red_valid;
                red_x_rsp_reg        <= red_x;
                red_y_rsp_reg        <= red_y;
                origin_valid_rsp_reg <= origin_valid;
                origin_x_rsp_reg     <= origin_x;
                origin_y_rsp_reg     <= origin_y;
                green_valid_rsp_reg  <= green_valid;
                green_x_rsp_reg      <= green_x;
                green_y_rsp_reg      <= green_y;
            end

            if (cmd_start_wire) begin
                if (calibrated_valid_reg) begin
                    streaming_enable_reg <= 1'b1;
                    status_rsp_reg <= RUN_STATE_STREAMING;
                end else begin
                    streaming_enable_reg <= 1'b0;
                    status_rsp_reg <= RUN_STATE_IDLE;
                end
                pending_status_rsp_reg <= 1'b1;
            end

            if (cmd_stop_wire) begin
                streaming_enable_reg <= 1'b0;
                status_rsp_reg <= calibrated_valid_reg ? RUN_STATE_CALIBRATED : RUN_STATE_IDLE;
                pending_status_rsp_reg <= 1'b1;
            end

            if (cmd_error_wire) begin
                status_rsp_reg <= streaming_enable_reg ? RUN_STATE_STREAMING :
                                  calibrated_valid_reg ? RUN_STATE_CALIBRATED :
                                  RUN_STATE_IDLE;
            end

            if (hand_update && streaming_enable_reg) begin
                pending_hand_rsp_reg       <= 1'b1;
                hand_frame_id_rsp_reg      <= frame_id_reg + 16'h0001;
                hand_valid_rsp_reg         <= hand_valid;
                hand_x_rsp_reg             <= hand_x;
                hand_y_rsp_reg             <= hand_y;
                hand_area_rsp_reg          <= hand_area;
                hand_grab_event_rsp_reg    <= capture_grab_event_wire;
                hand_release_event_rsp_reg <= capture_release_event_wire;
                frame_id_reg               <= frame_id_reg + 16'h0001;
                grab_event_pending_reg     <= 1'b0;
                release_event_pending_reg  <= 1'b0;
            end

            if (start_calib_rsp_wire) begin
                pending_calib_rsp_reg <= 1'b0;
            end

            if (start_status_rsp_wire) begin
                pending_status_rsp_reg <= 1'b0;
            end

            if (start_hand_rsp_wire) begin
                pending_hand_rsp_reg <= 1'b0;
            end
        end
    end

endmodule
