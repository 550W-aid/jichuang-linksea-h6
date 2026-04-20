`include "fpga/rtl/common/video_regs.vh"

module ov5640_reg_if #
(
    parameter integer CLK_HZ               = 50_000_000,
    parameter integer SCCB_HZ              = 100_000,
    parameter [6:0]   SENSOR_ADDR          = 7'h3C,
    parameter integer POWERUP_DELAY_CYCLES = 100_000,
    parameter integer RESET_RELEASE_CYCLES = 100_000
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        cmd_strobe_i,
    input  wire [15:0] cmd_i,
    input  wire [15:0] reg_addr_i,
    input  wire [15:0] wr_data_i,
    output reg  [15:0] rd_data_o,
    output wire [15:0] status_o,
    output reg  [15:0] frame_counter_o,
    output reg  [15:0] line_counter_o,
    output reg  [15:0] last_pixel_o,
    output reg  [15:0] error_count_o,
    input  wire [15:0] pixel_i,
    input  wire        valid_i,
    input  wire        sof_i,
    input  wire        eol_i,
    output reg         cam_reset_o,
    output reg         cam_pwdn_o,
    output wire        init_done_o,
    output wire        sccb_scl_o,
    output wire        sccb_sda_oe_o,
    input  wire        sccb_sda_i
);

    localparam integer STARTUP_TOTAL_CYCLES = POWERUP_DELAY_CYCLES + RESET_RELEASE_CYCLES;
    localparam integer WAIT_CYCLES_PER_MS   = ((CLK_HZ / 1000) > 0) ? (CLK_HZ / 1000) : 1;
    localparam [7:0]   INIT_TABLE_LAST      = 8'd245;

    reg        busy_r;
    reg        done_r;
    reg        ack_ok_r;
    reg        nack_r;
    reg        timeout_r;
    reg        init_done_r;
    reg        sensor_present_r;
    reg        data_active_r;
    reg        init_busy_r;
    reg        init_wait_r;
    reg        op_is_host_r;
    reg [7:0]  init_index_r;
    reg [31:0] startup_count;
    reg [31:0] init_wait_count_r;
    reg [15:0] current_line_count;
    reg [15:0] op_reg_addr_r;
    reg [7:0]  op_wr_data_r;
    reg [7:0]  id_high_r;
    reg [7:0]  id_low_r;
    reg        id_high_valid_r;
    reg        id_low_valid_r;
    reg        master_start_r;
    reg        master_read_r;
    reg [31:0] init_entry_word_r;
    reg [31:0] init_next_entry_word_r;

    wire [7:0] master_rd_data;
    wire       master_done;
    wire       master_ack_ok;
    wire       master_nack;
    wire       master_timeout;

    function [31:0] init_entry;
        input [7:0] index;
        begin
            case (index)
                // Ported and adapted from 正点原子 OV5640 RGB565 configuration.
                // Keep the richer sensor tuning, while preserving our UART-driven
                // register readback path and eLinx-friendly DVP/VGA pipeline.
                8'd0:    init_entry = {8'd5, 16'h3008, 8'h82};
                8'd1:    init_entry = {8'd0, 16'h3008, 8'h02};
                8'd2:    init_entry = {8'd0, 16'h3103, 8'h02};
                8'd3:    init_entry = {8'd0, 16'h3017, 8'hff};
                8'd4:    init_entry = {8'd0, 16'h3018, 8'hff};
                8'd5:    init_entry = {8'd0, 16'h3037, 8'h13};
                8'd6:    init_entry = {8'd0, 16'h3108, 8'h01};
                8'd7:    init_entry = {8'd0, 16'h3630, 8'h36};
                8'd8:    init_entry = {8'd0, 16'h3631, 8'h0e};
                8'd9:    init_entry = {8'd0, 16'h3632, 8'he2};
                8'd10:   init_entry = {8'd0, 16'h3633, 8'h12};
                8'd11:   init_entry = {8'd0, 16'h3621, 8'he0};
                8'd12:   init_entry = {8'd0, 16'h3704, 8'ha0};
                8'd13:   init_entry = {8'd0, 16'h3703, 8'h5a};
                8'd14:   init_entry = {8'd0, 16'h3715, 8'h78};
                8'd15:   init_entry = {8'd0, 16'h3717, 8'h01};
                8'd16:   init_entry = {8'd0, 16'h370b, 8'h60};
                8'd17:   init_entry = {8'd0, 16'h3705, 8'h1a};
                8'd18:   init_entry = {8'd0, 16'h3905, 8'h02};
                8'd19:   init_entry = {8'd0, 16'h3906, 8'h10};
                8'd20:   init_entry = {8'd0, 16'h3901, 8'h0a};
                8'd21:   init_entry = {8'd0, 16'h3731, 8'h12};
                8'd22:   init_entry = {8'd0, 16'h3600, 8'h08};
                8'd23:   init_entry = {8'd0, 16'h3601, 8'h33};
                8'd24:   init_entry = {8'd0, 16'h302d, 8'h60};
                8'd25:   init_entry = {8'd0, 16'h3620, 8'h52};
                8'd26:   init_entry = {8'd0, 16'h371b, 8'h20};
                8'd27:   init_entry = {8'd0, 16'h471c, 8'h50};
                8'd28:   init_entry = {8'd0, 16'h3a13, 8'h43};
                8'd29:   init_entry = {8'd0, 16'h3a18, 8'h00};
                8'd30:   init_entry = {8'd0, 16'h3a19, 8'hf8};
                8'd31:   init_entry = {8'd0, 16'h3635, 8'h13};
                8'd32:   init_entry = {8'd0, 16'h3636, 8'h03};
                8'd33:   init_entry = {8'd0, 16'h3634, 8'h40};
                8'd34:   init_entry = {8'd0, 16'h3622, 8'h01};
                8'd35:   init_entry = {8'd0, 16'h3c01, 8'h34};
                8'd36:   init_entry = {8'd0, 16'h3c04, 8'h28};
                8'd37:   init_entry = {8'd0, 16'h3c05, 8'h98};
                8'd38:   init_entry = {8'd0, 16'h3c06, 8'h00};
                8'd39:   init_entry = {8'd0, 16'h3c07, 8'h08};
                8'd40:   init_entry = {8'd0, 16'h3c08, 8'h00};
                8'd41:   init_entry = {8'd0, 16'h3c09, 8'h1c};
                8'd42:   init_entry = {8'd0, 16'h3c0a, 8'h9c};
                8'd43:   init_entry = {8'd0, 16'h3c0b, 8'h40};
                8'd44:   init_entry = {8'd0, 16'h3810, 8'h00};
                8'd45:   init_entry = {8'd0, 16'h3811, 8'h10};
                8'd46:   init_entry = {8'd0, 16'h3812, 8'h00};
                8'd47:   init_entry = {8'd0, 16'h3708, 8'h64};
                8'd48:   init_entry = {8'd0, 16'h4001, 8'h02};
                8'd49:   init_entry = {8'd0, 16'h4005, 8'h1a};
                8'd50:   init_entry = {8'd0, 16'h3000, 8'h00};
                8'd51:   init_entry = {8'd0, 16'h3004, 8'hff};
                8'd52:   init_entry = {8'd0, 16'h4300, 8'h61};
                8'd53:   init_entry = {8'd0, 16'h501f, 8'h01};
                8'd54:   init_entry = {8'd0, 16'h440e, 8'h00};
                8'd55:   init_entry = {8'd0, 16'h5000, 8'ha7};
                8'd56:   init_entry = {8'd0, 16'h3a0f, 8'h30};
                8'd57:   init_entry = {8'd0, 16'h3a10, 8'h28};
                8'd58:   init_entry = {8'd0, 16'h3a1b, 8'h30};
                8'd59:   init_entry = {8'd0, 16'h3a1e, 8'h26};
                8'd60:   init_entry = {8'd0, 16'h3a11, 8'h60};
                8'd61:   init_entry = {8'd0, 16'h3a1f, 8'h14};
                8'd62:   init_entry = {8'd0, 16'h5800, 8'h23};
                8'd63:   init_entry = {8'd0, 16'h5801, 8'h14};
                8'd64:   init_entry = {8'd0, 16'h5802, 8'h0f};
                8'd65:   init_entry = {8'd0, 16'h5803, 8'h0f};
                8'd66:   init_entry = {8'd0, 16'h5804, 8'h12};
                8'd67:   init_entry = {8'd0, 16'h5805, 8'h26};
                8'd68:   init_entry = {8'd0, 16'h5806, 8'h0c};
                8'd69:   init_entry = {8'd0, 16'h5807, 8'h08};
                8'd70:   init_entry = {8'd0, 16'h5808, 8'h05};
                8'd71:   init_entry = {8'd0, 16'h5809, 8'h05};
                8'd72:   init_entry = {8'd0, 16'h580a, 8'h08};
                8'd73:   init_entry = {8'd0, 16'h580b, 8'h0d};
                8'd74:   init_entry = {8'd0, 16'h580c, 8'h08};
                8'd75:   init_entry = {8'd0, 16'h580d, 8'h03};
                8'd76:   init_entry = {8'd0, 16'h580e, 8'h00};
                8'd77:   init_entry = {8'd0, 16'h580f, 8'h00};
                8'd78:   init_entry = {8'd0, 16'h5810, 8'h03};
                8'd79:   init_entry = {8'd0, 16'h5811, 8'h09};
                8'd80:   init_entry = {8'd0, 16'h5812, 8'h07};
                8'd81:   init_entry = {8'd0, 16'h5813, 8'h03};
                8'd82:   init_entry = {8'd0, 16'h5814, 8'h00};
                8'd83:   init_entry = {8'd0, 16'h5815, 8'h01};
                8'd84:   init_entry = {8'd0, 16'h5816, 8'h03};
                8'd85:   init_entry = {8'd0, 16'h5817, 8'h08};
                8'd86:   init_entry = {8'd0, 16'h5818, 8'h0d};
                8'd87:   init_entry = {8'd0, 16'h5819, 8'h08};
                8'd88:   init_entry = {8'd0, 16'h581a, 8'h05};
                8'd89:   init_entry = {8'd0, 16'h581b, 8'h06};
                8'd90:   init_entry = {8'd0, 16'h581c, 8'h08};
                8'd91:   init_entry = {8'd0, 16'h581d, 8'h0e};
                8'd92:   init_entry = {8'd0, 16'h581e, 8'h29};
                8'd93:   init_entry = {8'd0, 16'h581f, 8'h17};
                8'd94:   init_entry = {8'd0, 16'h5820, 8'h11};
                8'd95:   init_entry = {8'd0, 16'h5821, 8'h11};
                8'd96:   init_entry = {8'd0, 16'h5822, 8'h15};
                8'd97:   init_entry = {8'd0, 16'h5823, 8'h28};
                8'd98:   init_entry = {8'd0, 16'h5824, 8'h46};
                8'd99:   init_entry = {8'd0, 16'h5825, 8'h26};
                8'd100:  init_entry = {8'd0, 16'h5826, 8'h08};
                8'd101:  init_entry = {8'd0, 16'h5827, 8'h26};
                8'd102:  init_entry = {8'd0, 16'h5828, 8'h64};
                8'd103:  init_entry = {8'd0, 16'h5829, 8'h26};
                8'd104:  init_entry = {8'd0, 16'h582a, 8'h24};
                8'd105:  init_entry = {8'd0, 16'h582b, 8'h22};
                8'd106:  init_entry = {8'd0, 16'h582c, 8'h24};
                8'd107:  init_entry = {8'd0, 16'h582d, 8'h24};
                8'd108:  init_entry = {8'd0, 16'h582e, 8'h06};
                8'd109:  init_entry = {8'd0, 16'h582f, 8'h22};
                8'd110:  init_entry = {8'd0, 16'h5830, 8'h40};
                8'd111:  init_entry = {8'd0, 16'h5831, 8'h42};
                8'd112:  init_entry = {8'd0, 16'h5832, 8'h24};
                8'd113:  init_entry = {8'd0, 16'h5833, 8'h26};
                8'd114:  init_entry = {8'd0, 16'h5834, 8'h24};
                8'd115:  init_entry = {8'd0, 16'h5835, 8'h22};
                8'd116:  init_entry = {8'd0, 16'h5836, 8'h22};
                8'd117:  init_entry = {8'd0, 16'h5837, 8'h26};
                8'd118:  init_entry = {8'd0, 16'h5838, 8'h44};
                8'd119:  init_entry = {8'd0, 16'h5839, 8'h24};
                8'd120:  init_entry = {8'd0, 16'h583a, 8'h26};
                8'd121:  init_entry = {8'd0, 16'h583b, 8'h28};
                8'd122:  init_entry = {8'd0, 16'h583c, 8'h42};
                8'd123:  init_entry = {8'd0, 16'h583d, 8'hce};
                8'd124:  init_entry = {8'd0, 16'h5180, 8'hff};
                8'd125:  init_entry = {8'd0, 16'h5181, 8'hf2};
                8'd126:  init_entry = {8'd0, 16'h5182, 8'h00};
                8'd127:  init_entry = {8'd0, 16'h5183, 8'h14};
                8'd128:  init_entry = {8'd0, 16'h5184, 8'h25};
                8'd129:  init_entry = {8'd0, 16'h5185, 8'h24};
                8'd130:  init_entry = {8'd0, 16'h5186, 8'h09};
                8'd131:  init_entry = {8'd0, 16'h5187, 8'h09};
                8'd132:  init_entry = {8'd0, 16'h5188, 8'h09};
                8'd133:  init_entry = {8'd0, 16'h5189, 8'h75};
                8'd134:  init_entry = {8'd0, 16'h518a, 8'h54};
                8'd135:  init_entry = {8'd0, 16'h518b, 8'he0};
                8'd136:  init_entry = {8'd0, 16'h518c, 8'hb2};
                8'd137:  init_entry = {8'd0, 16'h518d, 8'h42};
                8'd138:  init_entry = {8'd0, 16'h518e, 8'h3d};
                8'd139:  init_entry = {8'd0, 16'h518f, 8'h56};
                8'd140:  init_entry = {8'd0, 16'h5190, 8'h46};
                8'd141:  init_entry = {8'd0, 16'h5191, 8'hf8};
                8'd142:  init_entry = {8'd0, 16'h5192, 8'h04};
                8'd143:  init_entry = {8'd0, 16'h5193, 8'h70};
                8'd144:  init_entry = {8'd0, 16'h5194, 8'hf0};
                8'd145:  init_entry = {8'd0, 16'h5195, 8'hf0};
                8'd146:  init_entry = {8'd0, 16'h5196, 8'h03};
                8'd147:  init_entry = {8'd0, 16'h5197, 8'h01};
                8'd148:  init_entry = {8'd0, 16'h5198, 8'h04};
                8'd149:  init_entry = {8'd0, 16'h5199, 8'h12};
                8'd150:  init_entry = {8'd0, 16'h519a, 8'h04};
                8'd151:  init_entry = {8'd0, 16'h519b, 8'h00};
                8'd152:  init_entry = {8'd0, 16'h519c, 8'h06};
                8'd153:  init_entry = {8'd0, 16'h519d, 8'h82};
                8'd154:  init_entry = {8'd0, 16'h519e, 8'h38};
                8'd155:  init_entry = {8'd0, 16'h5480, 8'h01};
                8'd156:  init_entry = {8'd0, 16'h5481, 8'h08};
                8'd157:  init_entry = {8'd0, 16'h5482, 8'h14};
                8'd158:  init_entry = {8'd0, 16'h5483, 8'h28};
                8'd159:  init_entry = {8'd0, 16'h5484, 8'h51};
                8'd160:  init_entry = {8'd0, 16'h5485, 8'h65};
                8'd161:  init_entry = {8'd0, 16'h5486, 8'h71};
                8'd162:  init_entry = {8'd0, 16'h5487, 8'h7d};
                8'd163:  init_entry = {8'd0, 16'h5488, 8'h87};
                8'd164:  init_entry = {8'd0, 16'h5489, 8'h91};
                8'd165:  init_entry = {8'd0, 16'h548a, 8'h9a};
                8'd166:  init_entry = {8'd0, 16'h548b, 8'haa};
                8'd167:  init_entry = {8'd0, 16'h548c, 8'hb8};
                8'd168:  init_entry = {8'd0, 16'h548d, 8'hcd};
                8'd169:  init_entry = {8'd0, 16'h548e, 8'hdd};
                8'd170:  init_entry = {8'd0, 16'h548f, 8'hea};
                8'd171:  init_entry = {8'd0, 16'h5490, 8'h1d};
                8'd172:  init_entry = {8'd0, 16'h5381, 8'h1e};
                8'd173:  init_entry = {8'd0, 16'h5382, 8'h5b};
                8'd174:  init_entry = {8'd0, 16'h5383, 8'h08};
                8'd175:  init_entry = {8'd0, 16'h5384, 8'h0a};
                8'd176:  init_entry = {8'd0, 16'h5385, 8'h7e};
                8'd177:  init_entry = {8'd0, 16'h5386, 8'h88};
                8'd178:  init_entry = {8'd0, 16'h5387, 8'h7c};
                8'd179:  init_entry = {8'd0, 16'h5388, 8'h6c};
                8'd180:  init_entry = {8'd0, 16'h5389, 8'h10};
                8'd181:  init_entry = {8'd0, 16'h538a, 8'h01};
                8'd182:  init_entry = {8'd0, 16'h538b, 8'h98};
                8'd183:  init_entry = {8'd0, 16'h5580, 8'h06};
                8'd184:  init_entry = {8'd0, 16'h5583, 8'h40};
                8'd185:  init_entry = {8'd0, 16'h5584, 8'h10};
                8'd186:  init_entry = {8'd0, 16'h5589, 8'h10};
                8'd187:  init_entry = {8'd0, 16'h558a, 8'h00};
                8'd188:  init_entry = {8'd0, 16'h558b, 8'hf8};
                8'd189:  init_entry = {8'd0, 16'h501d, 8'h40};
                8'd190:  init_entry = {8'd0, 16'h5300, 8'h08};
                8'd191:  init_entry = {8'd0, 16'h5301, 8'h30};
                8'd192:  init_entry = {8'd0, 16'h5302, 8'h10};
                8'd193:  init_entry = {8'd0, 16'h5303, 8'h00};
                8'd194:  init_entry = {8'd0, 16'h5304, 8'h08};
                8'd195:  init_entry = {8'd0, 16'h5305, 8'h30};
                8'd196:  init_entry = {8'd0, 16'h5306, 8'h08};
                8'd197:  init_entry = {8'd0, 16'h5307, 8'h16};
                8'd198:  init_entry = {8'd0, 16'h5309, 8'h08};
                8'd199:  init_entry = {8'd0, 16'h530a, 8'h30};
                8'd200:  init_entry = {8'd0, 16'h530b, 8'h04};
                8'd201:  init_entry = {8'd0, 16'h530c, 8'h06};
                8'd202:  init_entry = {8'd0, 16'h5025, 8'h00};
                8'd203:  init_entry = {8'd0, 16'h3035, 8'h11};
                8'd204:  init_entry = {8'd0, 16'h3036, 8'h3c};
                8'd205:  init_entry = {8'd0, 16'h3c07, 8'h08};
                8'd206:  init_entry = {8'd0, 16'h3820, 8'h46};
                8'd207:  init_entry = {8'd0, 16'h3821, 8'h01};
                8'd208:  init_entry = {8'd0, 16'h3814, 8'h31};
                8'd209:  init_entry = {8'd0, 16'h3815, 8'h31};
                8'd210:  init_entry = {8'd0, 16'h3800, 8'h00};
                8'd211:  init_entry = {8'd0, 16'h3801, 8'h00};
                8'd212:  init_entry = {8'd0, 16'h3802, 8'h00};
                8'd213:  init_entry = {8'd0, 16'h3803, 8'h04};
                8'd214:  init_entry = {8'd0, 16'h3804, 8'h0a};
                8'd215:  init_entry = {8'd0, 16'h3805, 8'h3f};
                8'd216:  init_entry = {8'd0, 16'h3806, 8'h07};
                8'd217:  init_entry = {8'd0, 16'h3807, 8'h9b};
                8'd218:  init_entry = {8'd0, 16'h3808, 8'h02};
                8'd219:  init_entry = {8'd0, 16'h3809, 8'h80};
                8'd220:  init_entry = {8'd0, 16'h380a, 8'h01};
                8'd221:  init_entry = {8'd0, 16'h380b, 8'he0};
                // Align the sensor total timing to standard 640x480@60 style
                // blanking so the downstream HDMI path can consume the DVP
                // stream with a much shallower buffer.
                8'd222:  init_entry = {8'd0, 16'h380c, 8'h07};
                8'd223:  init_entry = {8'd0, 16'h380d, 8'h40};
                8'd224:  init_entry = {8'd0, 16'h380e, 8'h03};
                8'd225:  init_entry = {8'd0, 16'h380f, 8'hd8};
                8'd226:  init_entry = {8'd0, 16'h3813, 8'h06};
                8'd227:  init_entry = {8'd0, 16'h3618, 8'h00};
                8'd228:  init_entry = {8'd0, 16'h3612, 8'h29};
                8'd229:  init_entry = {8'd0, 16'h3709, 8'h52};
                8'd230:  init_entry = {8'd0, 16'h370c, 8'h03};
                8'd231:  init_entry = {8'd0, 16'h3a02, 8'h17};
                8'd232:  init_entry = {8'd0, 16'h3a03, 8'h10};
                8'd233:  init_entry = {8'd0, 16'h3a14, 8'h17};
                8'd234:  init_entry = {8'd0, 16'h3a15, 8'h10};
                8'd235:  init_entry = {8'd0, 16'h4004, 8'h02};
                8'd236:  init_entry = {8'd0, 16'h4713, 8'h03};
                8'd237:  init_entry = {8'd0, 16'h4407, 8'h04};
                8'd238:  init_entry = {8'd0, 16'h460c, 8'h22};
                8'd239:  init_entry = {8'd0, 16'h4837, 8'h22};
                8'd240:  init_entry = {8'd0, 16'h3824, 8'h02};
                8'd241:  init_entry = {8'd0, 16'h5001, 8'ha3};
                8'd242:  init_entry = {8'd0, 16'h4740, 8'h22};
                8'd243:  init_entry = {8'd10, 16'h3503, 8'h00};
                8'd244:  init_entry = {8'd0, 16'h503d, 8'h00};
                8'd245:  init_entry = {8'd0, 16'h4741, 8'h00};
                default: init_entry = 32'h00000000;
            endcase
        end
    endfunction

    always @* begin
        init_entry_word_r      = init_entry(init_index_r);
        init_next_entry_word_r = init_entry(init_index_r + 8'd1);
    end

    assign init_done_o = init_done_r;
    assign status_o = {
        8'd0,
        data_active_r,
        sensor_present_r,
        init_done_r,
        timeout_r,
        nack_r,
        ack_ok_r,
        done_r,
        busy_r
    };

    sccb_master #(
        .CLK_HZ(CLK_HZ),
        .BUS_HZ(SCCB_HZ),
        .SENSOR_ADDR(SENSOR_ADDR)
    ) u_sccb_master (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(master_start_r),
        .read_i(master_read_r),
        .reg_addr_i(op_reg_addr_r),
        .wr_data_i(op_wr_data_r),
        .rd_data_o(master_rd_data),
        .busy_o(),
        .done_o(master_done),
        .ack_ok_o(master_ack_ok),
        .nack_o(master_nack),
        .timeout_o(master_timeout),
        .sccb_scl_o(sccb_scl_o),
        .sccb_sda_oe_o(sccb_sda_oe_o),
        .sccb_sda_i(sccb_sda_i)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_data_o          <= 16'd0;
            frame_counter_o    <= 16'd0;
            line_counter_o     <= 16'd0;
            last_pixel_o       <= 16'd0;
            error_count_o      <= 16'd0;
            busy_r             <= 1'b0;
            done_r             <= 1'b0;
            ack_ok_r           <= 1'b0;
            nack_r             <= 1'b0;
            timeout_r          <= 1'b0;
            init_done_r        <= 1'b0;
            sensor_present_r   <= 1'b0;
            data_active_r      <= 1'b0;
            init_busy_r        <= 1'b0;
            init_wait_r        <= 1'b0;
            op_is_host_r       <= 1'b0;
            init_index_r       <= 8'd0;
            startup_count      <= 32'd0;
            init_wait_count_r  <= 32'd0;
            current_line_count <= 16'd0;
            op_reg_addr_r      <= 16'd0;
            op_wr_data_r       <= 8'd0;
            id_high_r          <= 8'd0;
            id_low_r           <= 8'd0;
            id_high_valid_r    <= 1'b0;
            id_low_valid_r     <= 1'b0;
            master_start_r     <= 1'b0;
            master_read_r      <= 1'b0;
            cam_reset_o        <= 1'b0;
            cam_pwdn_o         <= 1'b1;
        end else begin
            master_start_r <= 1'b0;

            if (valid_i) begin
                data_active_r <= 1'b1;
                last_pixel_o  <= pixel_i;
            end

            if (eol_i) begin
                current_line_count <= current_line_count + 16'd1;
                line_counter_o     <= current_line_count + 16'd1;
            end

            if (sof_i) begin
                frame_counter_o    <= frame_counter_o + 16'd1;
                current_line_count <= 16'd0;
            end

            if (!init_done_r && !init_busy_r && !init_wait_r) begin
                if (startup_count < POWERUP_DELAY_CYCLES[15:0]) begin
                    startup_count <= startup_count + 32'd1;
                    cam_pwdn_o    <= 1'b1;
                    cam_reset_o   <= 1'b0;
                end else if (startup_count < STARTUP_TOTAL_CYCLES) begin
                    startup_count <= startup_count + 32'd1;
                    cam_pwdn_o    <= 1'b0;
                    cam_reset_o   <= 1'b0;
                end else begin
                    cam_pwdn_o <= 1'b0;
                    cam_reset_o <= 1'b1;
                    if (!busy_r) begin
                        busy_r         <= 1'b1;
                        init_busy_r    <= 1'b1;
                        op_is_host_r   <= 1'b0;
                        master_read_r  <= 1'b0;
                        op_reg_addr_r  <= init_entry_word_r[23:8];
                        op_wr_data_r   <= init_entry_word_r[7:0];
                        master_start_r <= 1'b1;
                        init_index_r   <= 8'd0;
                    end
                end
            end

            if (init_wait_r) begin
                if (init_wait_count_r == 32'd0) begin
                    busy_r          <= 1'b1;
                    init_busy_r     <= 1'b1;
                    op_is_host_r    <= 1'b0;
                    master_read_r   <= 1'b0;
                    op_reg_addr_r   <= init_entry_word_r[23:8];
                    op_wr_data_r    <= init_entry_word_r[7:0];
                    master_start_r  <= 1'b1;
                    init_wait_r     <= 1'b0;
                end else begin
                    init_wait_count_r <= init_wait_count_r - 32'd1;
                end
            end

            if (cmd_strobe_i) begin
                if (cmd_i == `CAM_CMD_CLEAR) begin
                    done_r    <= 1'b0;
                    ack_ok_r  <= 1'b0;
                    nack_r    <= 1'b0;
                    timeout_r <= 1'b0;
                end else if (!busy_r && init_done_r &&
                             (cmd_i == `CAM_CMD_READ || cmd_i == `CAM_CMD_WRITE)) begin
                    busy_r         <= 1'b1;
                    op_is_host_r   <= 1'b1;
                    master_read_r  <= (cmd_i == `CAM_CMD_READ);
                    op_reg_addr_r  <= reg_addr_i;
                    op_wr_data_r   <= wr_data_i[7:0];
                    master_start_r <= 1'b1;
                    done_r         <= 1'b0;
                    ack_ok_r       <= 1'b0;
                    nack_r         <= 1'b0;
                    timeout_r      <= 1'b0;
                end
            end

            if (master_done) begin
                if (op_is_host_r) begin
                    busy_r    <= 1'b0;
                    done_r    <= 1'b1;
                    ack_ok_r  <= master_ack_ok;
                    nack_r    <= master_nack;
                    timeout_r <= master_timeout;

                    if (master_ack_ok && master_read_r) begin
                        rd_data_o <= {8'd0, master_rd_data};
                        if (op_reg_addr_r == `OV5640_CHIP_ID_HIGH_REG) begin
                            id_high_r       <= master_rd_data;
                            id_high_valid_r <= 1'b1;
                        end
                        if (op_reg_addr_r == `OV5640_CHIP_ID_LOW_REG) begin
                            id_low_r       <= master_rd_data;
                            id_low_valid_r <= 1'b1;
                        end
                    end

                    if (master_nack || master_timeout) begin
                        error_count_o <= error_count_o + 16'd1;
                    end
                end else begin
                    if (master_ack_ok) begin
                        if (init_index_r == INIT_TABLE_LAST) begin
                            busy_r      <= 1'b0;
                            init_busy_r <= 1'b0;
                            init_done_r <= 1'b1;
                        end else if (init_entry_word_r[31:24] != 8'd0) begin
                            init_busy_r       <= 1'b0;
                            init_wait_r       <= 1'b1;
                            busy_r            <= 1'b1;
                            init_wait_count_r <= init_entry_word_r[31:24] * WAIT_CYCLES_PER_MS;
                            init_index_r      <= init_index_r + 8'd1;
                        end else begin
                            op_is_host_r   <= 1'b0;
                            master_read_r  <= 1'b0;
                            op_reg_addr_r  <= init_next_entry_word_r[23:8];
                            op_wr_data_r   <= init_next_entry_word_r[7:0];
                            master_start_r <= 1'b1;
                            init_index_r   <= init_index_r + 8'd1;
                        end
                    end else begin
                        busy_r        <= 1'b0;
                        init_busy_r   <= 1'b0;
                        nack_r        <= master_nack;
                        timeout_r     <= master_timeout;
                        error_count_o <= error_count_o + 16'd1;
                    end
                end
            end

            if (id_high_valid_r && id_low_valid_r) begin
                sensor_present_r <= (id_high_r == `OV5640_CHIP_ID_HIGH_VALUE) &&
                                    (id_low_r == `OV5640_CHIP_ID_LOW_VALUE);
            end
        end
    end

endmodule
