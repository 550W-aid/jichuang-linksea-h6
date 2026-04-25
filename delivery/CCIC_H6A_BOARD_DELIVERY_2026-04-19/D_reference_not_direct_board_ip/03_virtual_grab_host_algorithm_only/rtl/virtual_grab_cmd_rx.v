`timescale 1ns / 1ps

module virtual_grab_cmd_rx (
    input  wire       clk,               // Processing clock.
    input  wire       rst_n,             // Active-low reset.
    input  wire       rx_valid,          // Input byte valid strobe.
    input  wire [7:0] rx_data,           // Input byte value.
    output reg        cmd_calibrate,     // One-cycle pulse for CALIBRATE_REQ.
    output reg        cmd_start,         // One-cycle pulse for START_REQ.
    output reg        cmd_stop,          // One-cycle pulse for STOP_REQ.
    output reg        packet_error_pulse // One-cycle pulse for malformed packets.
);

    localparam [2:0] RX_WAIT_HEADER0 = 3'd0;
    localparam [2:0] RX_WAIT_HEADER1 = 3'd1;
    localparam [2:0] RX_WAIT_TYPE    = 3'd2;
    localparam [2:0] RX_WAIT_LENGTH  = 3'd3;
    localparam [2:0] RX_WAIT_PAYLOAD = 3'd4;
    localparam [2:0] RX_WAIT_CHECK   = 3'd5;

    localparam [7:0] MSG_CALIBRATE_REQ = 8'h10;
    localparam [7:0] MSG_START_REQ     = 8'h11;
    localparam [7:0] MSG_STOP_REQ      = 8'h12;

    reg [2:0] rx_state_reg;
    reg [7:0] msg_type_reg;
    reg [7:0] length_reg;
    reg [7:0] payload_count_reg;
    reg [7:0] checksum_reg;

    // Parse the fixed packet format and emit command pulses only for valid packets.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state_reg        <= RX_WAIT_HEADER0;
            msg_type_reg        <= 8'h00;
            length_reg          <= 8'h00;
            payload_count_reg   <= 8'h00;
            checksum_reg        <= 8'h00;
            cmd_calibrate       <= 1'b0;
            cmd_start           <= 1'b0;
            cmd_stop            <= 1'b0;
            packet_error_pulse  <= 1'b0;
        end else begin
            cmd_calibrate      <= 1'b0;
            cmd_start          <= 1'b0;
            cmd_stop           <= 1'b0;
            packet_error_pulse <= 1'b0;

            if (rx_valid) begin
                case (rx_state_reg)
                    RX_WAIT_HEADER0: begin
                        if (rx_data == 8'h55) begin
                            rx_state_reg <= RX_WAIT_HEADER1;
                        end
                    end

                    RX_WAIT_HEADER1: begin
                        if (rx_data == 8'hAA) begin
                            rx_state_reg <= RX_WAIT_TYPE;
                        end else if (rx_data == 8'h55) begin
                            rx_state_reg <= RX_WAIT_HEADER1;
                            packet_error_pulse <= 1'b1;
                        end else begin
                            rx_state_reg <= RX_WAIT_HEADER0;
                            packet_error_pulse <= 1'b1;
                        end
                    end

                    RX_WAIT_TYPE: begin
                        msg_type_reg  <= rx_data;
                        checksum_reg  <= rx_data;
                        rx_state_reg  <= RX_WAIT_LENGTH;
                    end

                    RX_WAIT_LENGTH: begin
                        length_reg        <= rx_data;
                        payload_count_reg <= 8'h00;
                        checksum_reg      <= checksum_reg + rx_data;

                        if (rx_data == 8'h00) begin
                            rx_state_reg <= RX_WAIT_CHECK;
                        end else begin
                            rx_state_reg <= RX_WAIT_PAYLOAD;
                        end
                    end

                    RX_WAIT_PAYLOAD: begin
                        checksum_reg      <= checksum_reg + rx_data;
                        payload_count_reg <= payload_count_reg + 8'h01;

                        if (payload_count_reg + 8'h01 >= length_reg) begin
                            rx_state_reg <= RX_WAIT_CHECK;
                        end
                    end

                    RX_WAIT_CHECK: begin
                        if (rx_data == checksum_reg) begin
                            if (length_reg == 8'h00) begin
                                case (msg_type_reg)
                                    MSG_CALIBRATE_REQ: cmd_calibrate <= 1'b1;
                                    MSG_START_REQ:     cmd_start <= 1'b1;
                                    MSG_STOP_REQ:      cmd_stop <= 1'b1;
                                    default:           packet_error_pulse <= 1'b1;
                                endcase
                            end else begin
                                packet_error_pulse <= 1'b1;
                            end
                        end else begin
                            packet_error_pulse <= 1'b1;
                        end

                        rx_state_reg <= RX_WAIT_HEADER0;
                    end

                    default: begin
                        rx_state_reg       <= RX_WAIT_HEADER0;
                        packet_error_pulse <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule
