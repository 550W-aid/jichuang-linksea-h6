`include "fpga/rtl/common/video_regs.vh"

module ctrl_regs
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wr_en,
    input  wire [7:0]  addr,
    input  wire [15:0] wr_data,
    output reg  [15:0] rd_data,
    input  wire [15:0] status_in,
    input  wire [15:0] fps_counter_in,
    input  wire [15:0] heartbeat_in,
    output reg  [15:0] mode,
    output reg  [15:0] algo_enable,
    output reg  [15:0] brightness_gain,
    output reg  [15:0] gamma_sel,
    output reg  [15:0] scale_sel,
    output reg  [15:0] rotate_sel,
    output reg  [15:0] edge_sel,
    output reg  [15:0] osd_sel
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode            <= `MODE_BYPASS;
            algo_enable     <= 16'h0000;
            brightness_gain <= 16'h0010;
            gamma_sel       <= 16'h0001;
            scale_sel       <= 16'h0000;
            rotate_sel      <= 16'h0000;
            edge_sel        <= 16'h0001;
            osd_sel         <= 16'h0001;
        end else if (wr_en) begin
            case (addr)
                `REG_MODE:            mode            <= wr_data;
                `REG_ALGO_ENABLE:     algo_enable     <= wr_data;
                `REG_BRIGHTNESS_GAIN: brightness_gain <= wr_data;
                `REG_GAMMA_SEL:       gamma_sel       <= wr_data;
                `REG_SCALE_SEL:       scale_sel       <= wr_data;
                `REG_ROTATE_SEL:      rotate_sel      <= wr_data;
                `REG_EDGE_SEL:        edge_sel        <= wr_data;
                `REG_OSD_SEL:         osd_sel         <= wr_data;
                default: begin
                end
            endcase
        end
    end

    always @* begin
        case (addr)
            `REG_MODE:            rd_data = mode;
            `REG_ALGO_ENABLE:     rd_data = algo_enable;
            `REG_BRIGHTNESS_GAIN: rd_data = brightness_gain;
            `REG_GAMMA_SEL:       rd_data = gamma_sel;
            `REG_SCALE_SEL:       rd_data = scale_sel;
            `REG_ROTATE_SEL:      rd_data = rotate_sel;
            `REG_EDGE_SEL:        rd_data = edge_sel;
            `REG_OSD_SEL:         rd_data = osd_sel;
            `REG_STATUS:          rd_data = status_in;
            `REG_FPS_COUNTER:     rd_data = fps_counter_in;
            `REG_HEARTBEAT:       rd_data = heartbeat_in;
            default:              rd_data = 16'hDEAD;
        endcase
    end

endmodule
