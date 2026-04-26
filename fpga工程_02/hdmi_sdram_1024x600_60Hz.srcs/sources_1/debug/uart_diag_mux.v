module uart_diag_mux #
(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 9600,
    parameter integer CHAR_GAP_CYCLES = 50_000
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        hdmi_init_done_i,
    input  wire        cam_init_done_i,
    input  wire        cam_data_active_i,
    input  wire        display_camera_i,
    input  wire        fb_frame_ready_i,
    input  wire        sdram_init_done_i,
    input  wire        sdram_rd_empty_i,
    input  wire [9:0]  sdram_rd_usedw_i,
    input  wire [9:0]  sdram_wr_usedw_i,
    input  wire [15:0] sdram_underflow_count_i,
    input  wire [15:0] frame_counter_i,
    input  wire [15:0] line_counter_i,
    input  wire [15:0] error_count_i,
    input  wire [15:0] debug_line_pixels_i,
    input  wire [15:0] debug_frame_lines_i,
    input  wire [15:0] cam_last_pixel_i,
    input  wire [19:0] cam_dbg_frame_pixels_i,
    input  wire [15:0] cam_dbg_frame_lines_i,
    input  wire [15:0] cam_dbg_line_pixels_i,
    input  wire [7:0]  cam_raw_hi_i,
    input  wire [7:0]  cam_raw_lo_i,
    input  wire [15:0] fb_last_pixel_i,
    input  wire [15:0] display_pixel_i,
    input  wire [15:0] cam_dbg_addr_i,
    input  wire [7:0]  cam_dbg_data_i,
    input  wire        cam_dbg_ack_i,
    input  wire        cam_busy_i,
    input  wire        cam_done_i,
    input  wire        cam_ack_ok_i,
    input  wire        cam_nack_i,
    input  wire        cam_timeout_i,
    input  wire [2:0]  cam_dbg_state_i,
    input  wire [3:0]  cam_dbg_index_i,
    input  wire [7:0]  zoom_level_i,
    input  wire [7:0]  pan_x_i,
    input  wire [7:0]  pan_y_i,
    input  wire        low_light_enable_i,
    input  wire [8:0]  low_light_offset_i,
    output wire        uart_tx_o
);

    localparam integer REPORT_DIV_MAX = CLK_HZ - 1;
    localparam integer STATUS_LEN     = 114;
    localparam integer DEBUG_LEN      = 15;

    reg [25:0] report_div_r;
    reg        report_active_r;
    reg        report_mode_r;
    reg [6:0]  report_index_r;
    reg [15:0] char_gap_r;
    reg [7:0]  uart_data_r;
    reg        uart_valid_r;

    wire       uart_busy_w;
    wire [6:0] report_len_w;
    wire [15:0] low_light_offset_ext_w;

    assign low_light_offset_ext_w = {{7{low_light_offset_i[8]}}, low_light_offset_i};

    function [7:0] hex_ascii;
        input [3:0] nibble;
        begin
            if (nibble < 4'd10) begin
                hex_ascii = 8'h30 + nibble;
            end else begin
                hex_ascii = 8'h41 + (nibble - 4'd10);
            end
        end
    endfunction

    function [7:0] report_byte;
        input       mode;
        input [6:0] index;
        begin
            if (!mode) begin
                case (index)
                    6'd0:  report_byte = "<";
                    6'd1:  report_byte = "H";
                    6'd2:  report_byte = hdmi_init_done_i ? "1" : "0";
                    6'd3:  report_byte = "C";
                    6'd4:  report_byte = cam_init_done_i ? "1" : "0";
                    6'd5:  report_byte = "A";
                    6'd6:  report_byte = cam_data_active_i ? "1" : "0";
                    6'd7:  report_byte = "F";
                    6'd8:  report_byte = display_camera_i ? "1" : "0";
                    6'd9:  report_byte = "R";
                    6'd10: report_byte = fb_frame_ready_i ? "1" : "0";
                    6'd11: report_byte = "P";
                    6'd12: report_byte = hex_ascii(frame_counter_i[7:4]);
                    6'd13: report_byte = hex_ascii(frame_counter_i[3:0]);
                    6'd14: report_byte = "W";
                    6'd15: report_byte = hex_ascii(debug_line_pixels_i[15:12]);
                    6'd16: report_byte = hex_ascii(debug_line_pixels_i[11:8]);
                    6'd17: report_byte = hex_ascii(debug_line_pixels_i[7:4]);
                    6'd18: report_byte = hex_ascii(debug_line_pixels_i[3:0]);
                    6'd19: report_byte = "Y";
                    6'd20: report_byte = hex_ascii(debug_frame_lines_i[15:12]);
                    6'd21: report_byte = hex_ascii(debug_frame_lines_i[11:8]);
                    6'd22: report_byte = hex_ascii(debug_frame_lines_i[7:4]);
                    6'd23: report_byte = hex_ascii(debug_frame_lines_i[3:0]);
                    6'd24: report_byte = "E";
                    6'd25: report_byte = hex_ascii(error_count_i[7:4]);
                    6'd26: report_byte = hex_ascii(error_count_i[3:0]);
                    6'd27: report_byte = "B";
                    6'd28: report_byte = cam_busy_i ? "1" : "0";
                    6'd29: report_byte = "D";
                    6'd30: report_byte = cam_done_i ? "1" : "0";
                    6'd31: report_byte = "K";
                    6'd32: report_byte = cam_ack_ok_i ? "1" : "0";
                    6'd33: report_byte = "N";
                    6'd34: report_byte = cam_nack_i ? "1" : "0";
                    6'd35: report_byte = "T";
                    6'd36: report_byte = cam_timeout_i ? "1" : "0";
                    6'd37: report_byte = "S";
                    6'd38: report_byte = hex_ascii({1'b0, cam_dbg_state_i});
                    6'd39: report_byte = "I";
                    6'd40: report_byte = hex_ascii(cam_dbg_index_i);
                    6'd41: report_byte = "L";
                    6'd42: report_byte = hex_ascii(cam_last_pixel_i[15:12]);
                    6'd43: report_byte = hex_ascii(cam_last_pixel_i[11:8]);
                    6'd44: report_byte = hex_ascii(cam_last_pixel_i[7:4]);
                    6'd45: report_byte = hex_ascii(cam_last_pixel_i[3:0]);
                    6'd46: report_byte = "U";
                    6'd47: report_byte = hex_ascii(cam_raw_hi_i[7:4]);
                    6'd48: report_byte = hex_ascii(cam_raw_hi_i[3:0]);
                    6'd49: report_byte = "V";
                    6'd50: report_byte = hex_ascii(cam_raw_lo_i[7:4]);
                    6'd51: report_byte = hex_ascii(cam_raw_lo_i[3:0]);
                    6'd52: report_byte = "Q";
                    6'd53: report_byte = hex_ascii(fb_last_pixel_i[15:12]);
                    6'd54: report_byte = hex_ascii(fb_last_pixel_i[11:8]);
                    6'd55: report_byte = hex_ascii(fb_last_pixel_i[7:4]);
                    6'd56: report_byte = hex_ascii(fb_last_pixel_i[3:0]);
                    6'd57: report_byte = "Z";
                    6'd58: report_byte = hex_ascii(display_pixel_i[15:12]);
                    6'd59: report_byte = hex_ascii(display_pixel_i[11:8]);
                    6'd60: report_byte = hex_ascii(display_pixel_i[7:4]);
                    6'd61: report_byte = hex_ascii(display_pixel_i[3:0]);
                    6'd62: report_byte = "M";
                    6'd63: report_byte = sdram_init_done_i ? "1" : "0";
                    7'd64: report_byte = "X";
                    7'd65: report_byte = sdram_rd_empty_i ? "1" : "0";
                    7'd66: report_byte = "O";
                    7'd67: report_byte = hex_ascii({2'b00, sdram_rd_usedw_i[9:8]});
                    7'd68: report_byte = hex_ascii(sdram_rd_usedw_i[7:4]);
                    7'd69: report_byte = hex_ascii(sdram_rd_usedw_i[3:0]);
                    7'd70: report_byte = "w";
                    7'd71: report_byte = hex_ascii({2'b00, sdram_wr_usedw_i[9:8]});
                    7'd72: report_byte = hex_ascii(sdram_wr_usedw_i[7:4]);
                    7'd73: report_byte = hex_ascii(sdram_wr_usedw_i[3:0]);
                    7'd74: report_byte = "u";
                    7'd75: report_byte = hex_ascii(sdram_underflow_count_i[15:12]);
                    7'd76: report_byte = hex_ascii(sdram_underflow_count_i[11:8]);
                    7'd77: report_byte = hex_ascii(sdram_underflow_count_i[7:4]);
                    7'd78: report_byte = hex_ascii(sdram_underflow_count_i[3:0]);
                    7'd79: report_byte = "j";
                    7'd80: report_byte = hex_ascii(cam_dbg_line_pixels_i[15:12]);
                    7'd81: report_byte = hex_ascii(cam_dbg_line_pixels_i[11:8]);
                    7'd82: report_byte = hex_ascii(cam_dbg_line_pixels_i[7:4]);
                    7'd83: report_byte = hex_ascii(cam_dbg_line_pixels_i[3:0]);
                    7'd84: report_byte = "k";
                    7'd85: report_byte = hex_ascii(cam_dbg_frame_lines_i[15:12]);
                    7'd86: report_byte = hex_ascii(cam_dbg_frame_lines_i[11:8]);
                    7'd87: report_byte = hex_ascii(cam_dbg_frame_lines_i[7:4]);
                    7'd88: report_byte = hex_ascii(cam_dbg_frame_lines_i[3:0]);
                    7'd89: report_byte = "p";
                    7'd90: report_byte = hex_ascii(cam_dbg_frame_pixels_i[19:16]);
                    7'd91: report_byte = hex_ascii(cam_dbg_frame_pixels_i[15:12]);
                    7'd92: report_byte = hex_ascii(cam_dbg_frame_pixels_i[11:8]);
                    7'd93: report_byte = hex_ascii(cam_dbg_frame_pixels_i[7:4]);
                    7'd94: report_byte = hex_ascii(cam_dbg_frame_pixels_i[3:0]);
                    7'd95: report_byte = "r";
                    7'd96: report_byte = hex_ascii(zoom_level_i[7:4]);
                    7'd97: report_byte = hex_ascii(zoom_level_i[3:0]);
                    7'd98: report_byte = "h";
                    7'd99: report_byte = low_light_enable_i ? "1" : "0";
                    7'd100: report_byte = "l";
                    7'd101: report_byte = hex_ascii(low_light_offset_ext_w[15:12]);
                    7'd102: report_byte = hex_ascii(low_light_offset_ext_w[11:8]);
                    7'd103: report_byte = hex_ascii(low_light_offset_ext_w[7:4]);
                    7'd104: report_byte = hex_ascii(low_light_offset_ext_w[3:0]);
                    7'd105: report_byte = "x";
                    7'd106: report_byte = hex_ascii(pan_x_i[7:4]);
                    7'd107: report_byte = hex_ascii(pan_x_i[3:0]);
                    7'd108: report_byte = "y";
                    7'd109: report_byte = hex_ascii(pan_y_i[7:4]);
                    7'd110: report_byte = hex_ascii(pan_y_i[3:0]);
                    7'd111: report_byte = ">";
                    7'd112: report_byte = 8'h0D;
                    7'd113: report_byte = 8'h0A;
                    default: report_byte = 8'h20;
                endcase
            end else begin
                case (index)
                    6'd0:  report_byte = "<";
                    6'd1:  report_byte = "G";
                    6'd2:  report_byte = hex_ascii(cam_dbg_addr_i[15:12]);
                    6'd3:  report_byte = hex_ascii(cam_dbg_addr_i[11:8]);
                    6'd4:  report_byte = hex_ascii(cam_dbg_addr_i[7:4]);
                    6'd5:  report_byte = hex_ascii(cam_dbg_addr_i[3:0]);
                    6'd6:  report_byte = "V";
                    6'd7:  report_byte = hex_ascii(cam_dbg_data_i[7:4]);
                    6'd8:  report_byte = hex_ascii(cam_dbg_data_i[3:0]);
                    6'd9:  report_byte = "K";
                    6'd10: report_byte = cam_dbg_ack_i ? "1" : "0";
                    6'd11: report_byte = ">";
                    6'd12: report_byte = 8'h0D;
                    6'd13: report_byte = 8'h0A;
                    default: report_byte = 8'h20;
                endcase
            end
        end
    endfunction

    assign report_len_w = report_mode_r ? DEBUG_LEN[6:0] : STATUS_LEN[6:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            report_div_r    <= 26'd0;
            report_active_r <= 1'b0;
            report_mode_r   <= 1'b0;
            report_index_r  <= 6'd0;
            char_gap_r      <= 16'd0;
            uart_data_r     <= 8'h00;
            uart_valid_r    <= 1'b0;
        end else begin
            uart_valid_r <= 1'b0;

            if (!report_active_r) begin
                if (report_div_r == REPORT_DIV_MAX) begin
                    report_div_r    <= 26'd0;
                    report_active_r <= 1'b1;
                    report_index_r  <= 6'd0;
                    char_gap_r      <= 16'd0;
                end else begin
                    report_div_r <= report_div_r + 26'd1;
                end
            end

            if (report_active_r && !uart_busy_w) begin
                if (char_gap_r != 16'd0) begin
                    char_gap_r <= char_gap_r - 16'd1;
                end else begin
                    uart_data_r  <= report_byte(report_mode_r, report_index_r);
                    uart_valid_r <= 1'b1;
                    if (report_index_r == report_len_w - 1'b1) begin
                        report_active_r <= 1'b0;
                        report_mode_r   <= ~report_mode_r;
                        report_index_r  <= 6'd0;
                        char_gap_r      <= 16'd0;
                    end else begin
                        report_index_r <= report_index_r + 6'd1;
                        char_gap_r     <= CHAR_GAP_CYCLES[15:0];
                    end
                end
            end
        end
    end

    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .data_i(uart_data_r),
        .data_valid_i(uart_valid_r),
        .tx_o(uart_tx_o),
        .busy_o(uart_busy_w)
    );

endmodule
