`include "fpga/rtl/common/video_regs.vh"

module camera_ctrl_regs
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [7:0]  addr,
    input  wire [15:0] wr_data,
    output reg  [15:0] rd_data,
    output reg         cam_cmd_strobe_o,
    output reg  [15:0] cam_cmd_o,
    output reg  [15:0] cam_reg_addr_o,
    output reg  [15:0] cam_wr_data_o,
    input  wire [15:0] cam_rd_data_i,
    input  wire [15:0] cam_status_i,
    input  wire [15:0] cam_frame_counter_i,
    input  wire [15:0] cam_line_counter_i,
    input  wire [15:0] cam_last_pixel_i,
    input  wire [15:0] cam_error_count_i
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cam_cmd_strobe_o <= 1'b0;
            cam_cmd_o        <= 16'd0;
            cam_reg_addr_o   <= 16'd0;
            cam_wr_data_o    <= 16'd0;
        end else begin
            cam_cmd_strobe_o <= 1'b0;
            if (wr_en) begin
                case (addr)
                    `REG_CAM_CMD: begin
                        cam_cmd_o        <= wr_data;
                        cam_cmd_strobe_o <= 1'b1;
                    end

                    `REG_CAM_REG_ADDR: begin
                        cam_reg_addr_o <= wr_data;
                    end

                    `REG_CAM_WR_DATA: begin
                        cam_wr_data_o <= wr_data;
                    end

                    default: begin
                    end
                endcase
            end
        end
    end

    always @* begin
        case (addr)
            `REG_CAM_CMD:         rd_data = cam_cmd_o;
            `REG_CAM_REG_ADDR:    rd_data = cam_reg_addr_o;
            `REG_CAM_WR_DATA:     rd_data = cam_wr_data_o;
            `REG_CAM_RD_DATA:     rd_data = cam_rd_data_i;
            `REG_CAM_STATUS:      rd_data = cam_status_i;
            `REG_CAM_FRAME_COUNT: rd_data = cam_frame_counter_i;
            `REG_CAM_LINE_COUNT:  rd_data = cam_line_counter_i;
            `REG_CAM_LAST_PIXEL:  rd_data = cam_last_pixel_i;
            `REG_CAM_ERROR_COUNT: rd_data = cam_error_count_i;
            default:              rd_data = 16'hDEAD;
        endcase
    end

endmodule
