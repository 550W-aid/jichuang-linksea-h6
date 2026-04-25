`timescale 1ns / 1ps

module virtual_grab_packet_tx #(
    parameter integer X_WIDTH    = 12,
    parameter integer Y_WIDTH    = 12,
    parameter integer AREA_WIDTH = 16
) (
    input  wire                   clk,            // Processing clock.
    input  wire                   rst_n,          // Active-low reset.
    input  wire                   start,          // One-cycle pulse to launch a packet.
    input  wire [1:0]             packet_kind,    // Encoded packet selector.
    input  wire                   tx_ready,       // Downstream byte-ready handshake.
    input  wire                   calib_valid,    // Latched calibration valid bit.
    input  wire [X_WIDTH-1:0]     red_x,          // Latched red target X coordinate.
    input  wire [Y_WIDTH-1:0]     red_y,          // Latched red target Y coordinate.
    input  wire                   origin_valid,   // Latched origin valid bit.
    input  wire [X_WIDTH-1:0]     origin_x,       // Latched origin X coordinate.
    input  wire [Y_WIDTH-1:0]     origin_y,       // Latched origin Y coordinate.
    input  wire                   green_valid,    // Latched green reference valid bit.
    input  wire [X_WIDTH-1:0]     green_x,        // Latched green reference X coordinate.
    input  wire [Y_WIDTH-1:0]     green_y,        // Latched green reference Y coordinate.
    input  wire [15:0]            frame_id,       // Latched frame identifier.
    input  wire                   hand_valid,     // Latched hand valid bit.
    input  wire [X_WIDTH-1:0]     hand_x,         // Latched hand X coordinate.
    input  wire [Y_WIDTH-1:0]     hand_y,         // Latched hand Y coordinate.
    input  wire [AREA_WIDTH-1:0]  hand_area,      // Latched hand area statistic.
    input  wire                   grab_event,     // Latched grab button event flag.
    input  wire                   release_event,  // Latched release button event flag.
    input  wire [7:0]             run_state,      // Latched status payload.
    output wire                   busy,           // High while a packet is being serialized.
    output wire                   tx_valid,       // Output byte valid.
    output wire [7:0]             tx_data,        // Output byte value.
    output wire                   tx_last         // High on the final byte of the packet.
);

    localparam [1:0] PACKET_KIND_CALIB  = 2'd0;
    localparam [1:0] PACKET_KIND_HAND   = 2'd1;
    localparam [1:0] PACKET_KIND_STATUS = 2'd2;

    localparam [7:0] MSG_CALIBRATE_RSP = 8'h20;
    localparam [7:0] MSG_HAND_REPORT   = 8'h21;
    localparam [7:0] MSG_STATUS_RSP    = 8'h22;

    reg packet_active_reg;
    reg [1:0] kind_reg;
    reg [7:0] byte_index_reg;
    reg [7:0] payload_length_reg;
    reg [7:0] msg_type_reg;
    reg [7:0] checksum_reg;

    reg calib_valid_reg;
    reg [X_WIDTH-1:0] red_x_reg;
    reg [Y_WIDTH-1:0] red_y_reg;
    reg origin_valid_reg;
    reg [X_WIDTH-1:0] origin_x_reg;
    reg [Y_WIDTH-1:0] origin_y_reg;
    reg green_valid_reg;
    reg [X_WIDTH-1:0] green_x_reg;
    reg [Y_WIDTH-1:0] green_y_reg;
    reg [15:0] frame_id_reg;
    reg hand_valid_reg;
    reg [X_WIDTH-1:0] hand_x_reg;
    reg [Y_WIDTH-1:0] hand_y_reg;
    reg [AREA_WIDTH-1:0] hand_area_reg;
    reg grab_event_reg;
    reg release_event_reg;
    reg [7:0] run_state_reg;

    wire [7:0] payload_index_wire;
    wire [7:0] payload_byte_wire;
    wire [7:0] current_byte_wire;
    wire [7:0] packet_last_index_wire;
    wire       tx_fire_wire;

    // Return the payload byte for a calibration response packet.
    function [7:0] calib_payload_byte;
        input [7:0] index_value;
        begin
            case (index_value)
                8'd0:  calib_payload_byte = {7'd0, calib_valid_reg};
                8'd1:  calib_payload_byte = {4'd0, red_x_reg[11:8]};
                8'd2:  calib_payload_byte = red_x_reg[7:0];
                8'd3:  calib_payload_byte = {4'd0, red_y_reg[11:8]};
                8'd4:  calib_payload_byte = red_y_reg[7:0];
                8'd5:  calib_payload_byte = {7'd0, origin_valid_reg};
                8'd6:  calib_payload_byte = {4'd0, origin_x_reg[11:8]};
                8'd7:  calib_payload_byte = origin_x_reg[7:0];
                8'd8:  calib_payload_byte = {4'd0, origin_y_reg[11:8]};
                8'd9:  calib_payload_byte = origin_y_reg[7:0];
                8'd10: calib_payload_byte = {7'd0, green_valid_reg};
                8'd11: calib_payload_byte = {4'd0, green_x_reg[11:8]};
                8'd12: calib_payload_byte = green_x_reg[7:0];
                8'd13: calib_payload_byte = {4'd0, green_y_reg[11:8]};
                8'd14: calib_payload_byte = green_y_reg[7:0];
                default: calib_payload_byte = 8'h00;
            endcase
        end
    endfunction

    // Return the payload byte for a hand report packet.
    function [7:0] hand_payload_byte;
        input [7:0] index_value;
        begin
            case (index_value)
                8'd0:  hand_payload_byte = frame_id_reg[15:8];
                8'd1:  hand_payload_byte = frame_id_reg[7:0];
                8'd2:  hand_payload_byte = {7'd0, hand_valid_reg};
                8'd3:  hand_payload_byte = {4'd0, hand_x_reg[11:8]};
                8'd4:  hand_payload_byte = hand_x_reg[7:0];
                8'd5:  hand_payload_byte = {4'd0, hand_y_reg[11:8]};
                8'd6:  hand_payload_byte = hand_y_reg[7:0];
                8'd7:  hand_payload_byte = hand_area_reg[15:8];
                8'd8:  hand_payload_byte = hand_area_reg[7:0];
                8'd9:  hand_payload_byte = {7'd0, grab_event_reg};
                8'd10: hand_payload_byte = {7'd0, release_event_reg};
                default: hand_payload_byte = 8'h00;
            endcase
        end
    endfunction

    // Return the payload byte for a status response packet.
    function [7:0] status_payload_byte;
        input [7:0] index_value;
        begin
            case (index_value)
                8'd0:  status_payload_byte = run_state_reg;
                default: status_payload_byte = 8'h00;
            endcase
        end
    endfunction

    assign busy = packet_active_reg;
    assign tx_valid = packet_active_reg;
    assign payload_index_wire = byte_index_reg - 8'd4;
    assign tx_fire_wire = tx_valid && tx_ready;
    assign packet_last_index_wire = payload_length_reg + 8'd4;
    assign tx_last = packet_active_reg && (byte_index_reg == packet_last_index_wire);

    assign payload_byte_wire =
        (kind_reg == PACKET_KIND_CALIB)  ? calib_payload_byte(payload_index_wire) :
        (kind_reg == PACKET_KIND_HAND)   ? hand_payload_byte(payload_index_wire) :
                                           status_payload_byte(payload_index_wire);

    assign current_byte_wire =
        (byte_index_reg == 8'd0) ? 8'h55 :
        (byte_index_reg == 8'd1) ? 8'hAA :
        (byte_index_reg == 8'd2) ? msg_type_reg :
        (byte_index_reg == 8'd3) ? payload_length_reg :
        (byte_index_reg < packet_last_index_wire) ? payload_byte_wire :
        checksum_reg;

    assign tx_data = current_byte_wire;

    // Latch the selected packet snapshot, then serialize one byte per ready handshake.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_active_reg <= 1'b0;
            kind_reg          <= PACKET_KIND_CALIB;
            byte_index_reg    <= 8'h00;
            payload_length_reg<= 8'h00;
            msg_type_reg      <= 8'h00;
            checksum_reg      <= 8'h00;
            calib_valid_reg   <= 1'b0;
            red_x_reg         <= {X_WIDTH{1'b0}};
            red_y_reg         <= {Y_WIDTH{1'b0}};
            origin_valid_reg  <= 1'b0;
            origin_x_reg      <= {X_WIDTH{1'b0}};
            origin_y_reg      <= {Y_WIDTH{1'b0}};
            green_valid_reg   <= 1'b0;
            green_x_reg       <= {X_WIDTH{1'b0}};
            green_y_reg       <= {Y_WIDTH{1'b0}};
            frame_id_reg      <= 16'h0000;
            hand_valid_reg    <= 1'b0;
            hand_x_reg        <= {X_WIDTH{1'b0}};
            hand_y_reg        <= {Y_WIDTH{1'b0}};
            hand_area_reg     <= {AREA_WIDTH{1'b0}};
            grab_event_reg    <= 1'b0;
            release_event_reg <= 1'b0;
            run_state_reg     <= 8'h00;
        end else begin
            if (start && !packet_active_reg) begin
                packet_active_reg <= 1'b1;
                kind_reg          <= packet_kind;
                byte_index_reg    <= 8'h00;
                calib_valid_reg   <= calib_valid;
                red_x_reg         <= red_x;
                red_y_reg         <= red_y;
                origin_valid_reg  <= origin_valid;
                origin_x_reg      <= origin_x;
                origin_y_reg      <= origin_y;
                green_valid_reg   <= green_valid;
                green_x_reg       <= green_x;
                green_y_reg       <= green_y;
                frame_id_reg      <= frame_id;
                hand_valid_reg    <= hand_valid;
                hand_x_reg        <= hand_x;
                hand_y_reg        <= hand_y;
                hand_area_reg     <= hand_area;
                grab_event_reg    <= grab_event;
                release_event_reg <= release_event;
                run_state_reg     <= run_state;

                case (packet_kind)
                    PACKET_KIND_CALIB: begin
                        payload_length_reg <= 8'd15;
                        msg_type_reg       <= MSG_CALIBRATE_RSP;
                        checksum_reg       <= MSG_CALIBRATE_RSP + 8'd15;
                    end

                    PACKET_KIND_HAND: begin
                        payload_length_reg <= 8'd11;
                        msg_type_reg       <= MSG_HAND_REPORT;
                        checksum_reg       <= MSG_HAND_REPORT + 8'd11;
                    end

                    default: begin
                        payload_length_reg <= 8'd1;
                        msg_type_reg       <= MSG_STATUS_RSP;
                        checksum_reg       <= MSG_STATUS_RSP + 8'd1;
                    end
                endcase
            end else if (tx_fire_wire && packet_active_reg) begin
                if (byte_index_reg >= 8'd4 && byte_index_reg < packet_last_index_wire) begin
                    checksum_reg <= checksum_reg + payload_byte_wire;
                end

                if (byte_index_reg == packet_last_index_wire) begin
                    packet_active_reg <= 1'b0;
                    byte_index_reg    <= 8'h00;
                end else begin
                    byte_index_reg <= byte_index_reg + 8'h01;
                end
            end
        end
    end

endmodule
