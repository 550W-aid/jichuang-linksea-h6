`timescale 1ns / 1ps

module ycbcr444_luma_gamma_stream_std #(
    parameter integer MAX_LANES  = 8,
    parameter [1:0]   GAMMA_MODE = 2'd0
) (
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        s_valid,
    output wire                        s_ready,
    input  wire [MAX_LANES*24-1:0]     s_data,
    input  wire [MAX_LANES-1:0]        s_keep,
    input  wire                        s_sof,
    input  wire                        s_eol,
    input  wire                        s_eof,
    input  wire signed [8:0]           brightness_offset,
    output reg                         m_valid,
    input  wire                        m_ready,
    output reg  [MAX_LANES*24-1:0]     m_data,
    output reg  [MAX_LANES-1:0]        m_keep,
    output reg                         m_sof,
    output reg                         m_eol,
    output reg                         m_eof
);

    integer lane_idx;
    wire has_active_lane;
    wire stage3_ready;
    wire stage2_ready;
    wire stage1_ready;
    wire stage0_ready;

    reg                         stage0_valid;
    reg  [MAX_LANES*24-1:0]     stage0_data;
    reg  [MAX_LANES-1:0]        stage0_keep;
    reg                         stage0_sof;
    reg                         stage0_eol;
    reg                         stage0_eof;
    reg  signed [8:0]           stage0_brightness_offset;

    reg                         stage1_valid;
    reg  [MAX_LANES*24-1:0]     stage1_data;
    reg  [MAX_LANES*8-1:0]      stage1_segment_gain;
    reg  [MAX_LANES*8-1:0]      stage1_headroom;
    reg  [MAX_LANES-1:0]        stage1_keep;
    reg                         stage1_sof;
    reg                         stage1_eol;
    reg                         stage1_eof;
    reg  signed [8:0]           stage1_brightness_offset;

    reg                         stage2_valid;
    reg  [MAX_LANES*24-1:0]     stage2_data;
    reg  [MAX_LANES*16-1:0]     stage2_boost_mul0;
    reg  [MAX_LANES*8-1:0]      stage2_segment_gain;
    reg  [MAX_LANES-1:0]        stage2_keep;
    reg                         stage2_sof;
    reg                         stage2_eol;
    reg                         stage2_eof;
    reg  signed [8:0]           stage2_brightness_offset;

    reg                         stage3_valid;
    reg  [MAX_LANES*24-1:0]     stage3_data;
    reg  [MAX_LANES*24-1:0]     stage3_boost_mul1;
    reg  [MAX_LANES-1:0]        stage3_keep;
    reg                         stage3_sof;
    reg                         stage3_eol;
    reg                         stage3_eof;
    reg  signed [8:0]           stage3_brightness_offset;

    function [7:0] gamma_luma_sqrt;
        input [7:0] value;
        begin
            case (value)
                8'd0: gamma_luma_sqrt = 8'd0;
                8'd1: gamma_luma_sqrt = 8'd16;
                8'd2: gamma_luma_sqrt = 8'd23;
                8'd3: gamma_luma_sqrt = 8'd28;
                8'd4: gamma_luma_sqrt = 8'd32;
                8'd5: gamma_luma_sqrt = 8'd36;
                8'd6: gamma_luma_sqrt = 8'd39;
                8'd7: gamma_luma_sqrt = 8'd42;
                8'd8: gamma_luma_sqrt = 8'd45;
                8'd9: gamma_luma_sqrt = 8'd48;
                8'd10: gamma_luma_sqrt = 8'd50;
                8'd11: gamma_luma_sqrt = 8'd53;
                8'd12: gamma_luma_sqrt = 8'd55;
                8'd13: gamma_luma_sqrt = 8'd58;
                8'd14: gamma_luma_sqrt = 8'd60;
                8'd15: gamma_luma_sqrt = 8'd62;
                8'd16: gamma_luma_sqrt = 8'd64;
                8'd17: gamma_luma_sqrt = 8'd66;
                8'd18: gamma_luma_sqrt = 8'd68;
                8'd19: gamma_luma_sqrt = 8'd70;
                8'd20: gamma_luma_sqrt = 8'd71;
                8'd21: gamma_luma_sqrt = 8'd73;
                8'd22: gamma_luma_sqrt = 8'd75;
                8'd23: gamma_luma_sqrt = 8'd77;
                8'd24: gamma_luma_sqrt = 8'd78;
                8'd25: gamma_luma_sqrt = 8'd80;
                8'd26: gamma_luma_sqrt = 8'd81;
                8'd27: gamma_luma_sqrt = 8'd83;
                8'd28: gamma_luma_sqrt = 8'd84;
                8'd29: gamma_luma_sqrt = 8'd86;
                8'd30: gamma_luma_sqrt = 8'd87;
                8'd31: gamma_luma_sqrt = 8'd89;
                8'd32: gamma_luma_sqrt = 8'd90;
                8'd33: gamma_luma_sqrt = 8'd92;
                8'd34: gamma_luma_sqrt = 8'd93;
                8'd35: gamma_luma_sqrt = 8'd94;
                8'd36: gamma_luma_sqrt = 8'd96;
                8'd37: gamma_luma_sqrt = 8'd97;
                8'd38: gamma_luma_sqrt = 8'd98;
                8'd39: gamma_luma_sqrt = 8'd100;
                8'd40: gamma_luma_sqrt = 8'd101;
                8'd41: gamma_luma_sqrt = 8'd102;
                8'd42: gamma_luma_sqrt = 8'd103;
                8'd43: gamma_luma_sqrt = 8'd105;
                8'd44: gamma_luma_sqrt = 8'd106;
                8'd45: gamma_luma_sqrt = 8'd107;
                8'd46: gamma_luma_sqrt = 8'd108;
                8'd47: gamma_luma_sqrt = 8'd109;
                8'd48: gamma_luma_sqrt = 8'd111;
                8'd49: gamma_luma_sqrt = 8'd112;
                8'd50: gamma_luma_sqrt = 8'd113;
                8'd51: gamma_luma_sqrt = 8'd114;
                8'd52: gamma_luma_sqrt = 8'd115;
                8'd53: gamma_luma_sqrt = 8'd116;
                8'd54: gamma_luma_sqrt = 8'd117;
                8'd55: gamma_luma_sqrt = 8'd118;
                8'd56: gamma_luma_sqrt = 8'd119;
                8'd57: gamma_luma_sqrt = 8'd121;
                8'd58: gamma_luma_sqrt = 8'd122;
                8'd59: gamma_luma_sqrt = 8'd123;
                8'd60: gamma_luma_sqrt = 8'd124;
                8'd61: gamma_luma_sqrt = 8'd125;
                8'd62: gamma_luma_sqrt = 8'd126;
                8'd63: gamma_luma_sqrt = 8'd127;
                8'd64: gamma_luma_sqrt = 8'd128;
                8'd65: gamma_luma_sqrt = 8'd129;
                8'd66: gamma_luma_sqrt = 8'd130;
                8'd67: gamma_luma_sqrt = 8'd131;
                8'd68: gamma_luma_sqrt = 8'd132;
                8'd69: gamma_luma_sqrt = 8'd133;
                8'd70: gamma_luma_sqrt = 8'd134;
                8'd71: gamma_luma_sqrt = 8'd135;
                8'd72: gamma_luma_sqrt = 8'd135;
                8'd73: gamma_luma_sqrt = 8'd136;
                8'd74: gamma_luma_sqrt = 8'd137;
                8'd75: gamma_luma_sqrt = 8'd138;
                8'd76: gamma_luma_sqrt = 8'd139;
                8'd77: gamma_luma_sqrt = 8'd140;
                8'd78: gamma_luma_sqrt = 8'd141;
                8'd79: gamma_luma_sqrt = 8'd142;
                8'd80: gamma_luma_sqrt = 8'd143;
                8'd81: gamma_luma_sqrt = 8'd144;
                8'd82: gamma_luma_sqrt = 8'd145;
                8'd83: gamma_luma_sqrt = 8'd145;
                8'd84: gamma_luma_sqrt = 8'd146;
                8'd85: gamma_luma_sqrt = 8'd147;
                8'd86: gamma_luma_sqrt = 8'd148;
                8'd87: gamma_luma_sqrt = 8'd149;
                8'd88: gamma_luma_sqrt = 8'd150;
                8'd89: gamma_luma_sqrt = 8'd151;
                8'd90: gamma_luma_sqrt = 8'd151;
                8'd91: gamma_luma_sqrt = 8'd152;
                8'd92: gamma_luma_sqrt = 8'd153;
                8'd93: gamma_luma_sqrt = 8'd154;
                8'd94: gamma_luma_sqrt = 8'd155;
                8'd95: gamma_luma_sqrt = 8'd156;
                8'd96: gamma_luma_sqrt = 8'd156;
                8'd97: gamma_luma_sqrt = 8'd157;
                8'd98: gamma_luma_sqrt = 8'd158;
                8'd99: gamma_luma_sqrt = 8'd159;
                8'd100: gamma_luma_sqrt = 8'd160;
                8'd101: gamma_luma_sqrt = 8'd160;
                8'd102: gamma_luma_sqrt = 8'd161;
                8'd103: gamma_luma_sqrt = 8'd162;
                8'd104: gamma_luma_sqrt = 8'd163;
                8'd105: gamma_luma_sqrt = 8'd164;
                8'd106: gamma_luma_sqrt = 8'd164;
                8'd107: gamma_luma_sqrt = 8'd165;
                8'd108: gamma_luma_sqrt = 8'd166;
                8'd109: gamma_luma_sqrt = 8'd167;
                8'd110: gamma_luma_sqrt = 8'd167;
                8'd111: gamma_luma_sqrt = 8'd168;
                8'd112: gamma_luma_sqrt = 8'd169;
                8'd113: gamma_luma_sqrt = 8'd170;
                8'd114: gamma_luma_sqrt = 8'd170;
                8'd115: gamma_luma_sqrt = 8'd171;
                8'd116: gamma_luma_sqrt = 8'd172;
                8'd117: gamma_luma_sqrt = 8'd173;
                8'd118: gamma_luma_sqrt = 8'd173;
                8'd119: gamma_luma_sqrt = 8'd174;
                8'd120: gamma_luma_sqrt = 8'd175;
                8'd121: gamma_luma_sqrt = 8'd176;
                8'd122: gamma_luma_sqrt = 8'd176;
                8'd123: gamma_luma_sqrt = 8'd177;
                8'd124: gamma_luma_sqrt = 8'd178;
                8'd125: gamma_luma_sqrt = 8'd179;
                8'd126: gamma_luma_sqrt = 8'd179;
                8'd127: gamma_luma_sqrt = 8'd180;
                8'd128: gamma_luma_sqrt = 8'd181;
                8'd129: gamma_luma_sqrt = 8'd181;
                8'd130: gamma_luma_sqrt = 8'd182;
                8'd131: gamma_luma_sqrt = 8'd183;
                8'd132: gamma_luma_sqrt = 8'd183;
                8'd133: gamma_luma_sqrt = 8'd184;
                8'd134: gamma_luma_sqrt = 8'd185;
                8'd135: gamma_luma_sqrt = 8'd186;
                8'd136: gamma_luma_sqrt = 8'd186;
                8'd137: gamma_luma_sqrt = 8'd187;
                8'd138: gamma_luma_sqrt = 8'd188;
                8'd139: gamma_luma_sqrt = 8'd188;
                8'd140: gamma_luma_sqrt = 8'd189;
                8'd141: gamma_luma_sqrt = 8'd190;
                8'd142: gamma_luma_sqrt = 8'd190;
                8'd143: gamma_luma_sqrt = 8'd191;
                8'd144: gamma_luma_sqrt = 8'd192;
                8'd145: gamma_luma_sqrt = 8'd192;
                8'd146: gamma_luma_sqrt = 8'd193;
                8'd147: gamma_luma_sqrt = 8'd194;
                8'd148: gamma_luma_sqrt = 8'd194;
                8'd149: gamma_luma_sqrt = 8'd195;
                8'd150: gamma_luma_sqrt = 8'd196;
                8'd151: gamma_luma_sqrt = 8'd196;
                8'd152: gamma_luma_sqrt = 8'd197;
                8'd153: gamma_luma_sqrt = 8'd198;
                8'd154: gamma_luma_sqrt = 8'd198;
                8'd155: gamma_luma_sqrt = 8'd199;
                8'd156: gamma_luma_sqrt = 8'd199;
                8'd157: gamma_luma_sqrt = 8'd200;
                8'd158: gamma_luma_sqrt = 8'd201;
                8'd159: gamma_luma_sqrt = 8'd201;
                8'd160: gamma_luma_sqrt = 8'd202;
                8'd161: gamma_luma_sqrt = 8'd203;
                8'd162: gamma_luma_sqrt = 8'd203;
                8'd163: gamma_luma_sqrt = 8'd204;
                8'd164: gamma_luma_sqrt = 8'd204;
                8'd165: gamma_luma_sqrt = 8'd205;
                8'd166: gamma_luma_sqrt = 8'd206;
                8'd167: gamma_luma_sqrt = 8'd206;
                8'd168: gamma_luma_sqrt = 8'd207;
                8'd169: gamma_luma_sqrt = 8'd208;
                8'd170: gamma_luma_sqrt = 8'd208;
                8'd171: gamma_luma_sqrt = 8'd209;
                8'd172: gamma_luma_sqrt = 8'd209;
                8'd173: gamma_luma_sqrt = 8'd210;
                8'd174: gamma_luma_sqrt = 8'd211;
                8'd175: gamma_luma_sqrt = 8'd211;
                8'd176: gamma_luma_sqrt = 8'd212;
                8'd177: gamma_luma_sqrt = 8'd212;
                8'd178: gamma_luma_sqrt = 8'd213;
                8'd179: gamma_luma_sqrt = 8'd214;
                8'd180: gamma_luma_sqrt = 8'd214;
                8'd181: gamma_luma_sqrt = 8'd215;
                8'd182: gamma_luma_sqrt = 8'd215;
                8'd183: gamma_luma_sqrt = 8'd216;
                8'd184: gamma_luma_sqrt = 8'd217;
                8'd185: gamma_luma_sqrt = 8'd217;
                8'd186: gamma_luma_sqrt = 8'd218;
                8'd187: gamma_luma_sqrt = 8'd218;
                8'd188: gamma_luma_sqrt = 8'd219;
                8'd189: gamma_luma_sqrt = 8'd220;
                8'd190: gamma_luma_sqrt = 8'd220;
                8'd191: gamma_luma_sqrt = 8'd221;
                8'd192: gamma_luma_sqrt = 8'd221;
                8'd193: gamma_luma_sqrt = 8'd222;
                8'd194: gamma_luma_sqrt = 8'd222;
                8'd195: gamma_luma_sqrt = 8'd223;
                8'd196: gamma_luma_sqrt = 8'd224;
                8'd197: gamma_luma_sqrt = 8'd224;
                8'd198: gamma_luma_sqrt = 8'd225;
                8'd199: gamma_luma_sqrt = 8'd225;
                8'd200: gamma_luma_sqrt = 8'd226;
                8'd201: gamma_luma_sqrt = 8'd226;
                8'd202: gamma_luma_sqrt = 8'd227;
                8'd203: gamma_luma_sqrt = 8'd228;
                8'd204: gamma_luma_sqrt = 8'd228;
                8'd205: gamma_luma_sqrt = 8'd229;
                8'd206: gamma_luma_sqrt = 8'd229;
                8'd207: gamma_luma_sqrt = 8'd230;
                8'd208: gamma_luma_sqrt = 8'd230;
                8'd209: gamma_luma_sqrt = 8'd231;
                8'd210: gamma_luma_sqrt = 8'd231;
                8'd211: gamma_luma_sqrt = 8'd232;
                8'd212: gamma_luma_sqrt = 8'd233;
                8'd213: gamma_luma_sqrt = 8'd233;
                8'd214: gamma_luma_sqrt = 8'd234;
                8'd215: gamma_luma_sqrt = 8'd234;
                8'd216: gamma_luma_sqrt = 8'd235;
                8'd217: gamma_luma_sqrt = 8'd235;
                8'd218: gamma_luma_sqrt = 8'd236;
                8'd219: gamma_luma_sqrt = 8'd236;
                8'd220: gamma_luma_sqrt = 8'd237;
                8'd221: gamma_luma_sqrt = 8'd237;
                8'd222: gamma_luma_sqrt = 8'd238;
                8'd223: gamma_luma_sqrt = 8'd238;
                8'd224: gamma_luma_sqrt = 8'd239;
                8'd225: gamma_luma_sqrt = 8'd240;
                8'd226: gamma_luma_sqrt = 8'd240;
                8'd227: gamma_luma_sqrt = 8'd241;
                8'd228: gamma_luma_sqrt = 8'd241;
                8'd229: gamma_luma_sqrt = 8'd242;
                8'd230: gamma_luma_sqrt = 8'd242;
                8'd231: gamma_luma_sqrt = 8'd243;
                8'd232: gamma_luma_sqrt = 8'd243;
                8'd233: gamma_luma_sqrt = 8'd244;
                8'd234: gamma_luma_sqrt = 8'd244;
                8'd235: gamma_luma_sqrt = 8'd245;
                8'd236: gamma_luma_sqrt = 8'd245;
                8'd237: gamma_luma_sqrt = 8'd246;
                8'd238: gamma_luma_sqrt = 8'd246;
                8'd239: gamma_luma_sqrt = 8'd247;
                8'd240: gamma_luma_sqrt = 8'd247;
                8'd241: gamma_luma_sqrt = 8'd248;
                8'd242: gamma_luma_sqrt = 8'd248;
                8'd243: gamma_luma_sqrt = 8'd249;
                8'd244: gamma_luma_sqrt = 8'd249;
                8'd245: gamma_luma_sqrt = 8'd250;
                8'd246: gamma_luma_sqrt = 8'd250;
                8'd247: gamma_luma_sqrt = 8'd251;
                8'd248: gamma_luma_sqrt = 8'd251;
                8'd249: gamma_luma_sqrt = 8'd252;
                8'd250: gamma_luma_sqrt = 8'd252;
                8'd251: gamma_luma_sqrt = 8'd253;
                8'd252: gamma_luma_sqrt = 8'd253;
                8'd253: gamma_luma_sqrt = 8'd254;
                8'd254: gamma_luma_sqrt = 8'd254;
                default: gamma_luma_sqrt = 8'd255;
            endcase
        end
    endfunction

    function [7:0] gamma_luma;
        input [7:0] value;
        begin
            case (GAMMA_MODE)
                2'd0: gamma_luma = value;
                // Mode 1 is reserved for the low-light pipeline used in TOP1.
                // Keep luma unchanged here and perform segmented adaptive lifting
                // in the next stage so highlights are not globally over-brightened.
                2'd1: gamma_luma = value;
                2'd2: gamma_luma = (value * value) >> 8;
                default: begin
                    if (value < 8'd96) begin
                        gamma_luma = value >> 1;
                    end else if (value < 8'd192) begin
                        gamma_luma = 8'd48 + ((value - 8'd96) >> 1);
                    end else begin
                        gamma_luma = 8'd96 + (((value - 8'd192) * 3) >> 2);
                    end
                end
            endcase
        end
    endfunction

    function [7:0] apply_brightness_offset;
        input [7:0] base_y;
        input signed [8:0] offset;
        reg signed [9:0] adjusted_y;
        begin
            adjusted_y = $signed({1'b0, base_y}) + offset;
            if (adjusted_y < 0) begin
                apply_brightness_offset = 8'd0;
            end else if (adjusted_y > 10'sd255) begin
                apply_brightness_offset = 8'hFF;
            end else begin
                apply_brightness_offset = adjusted_y[7:0];
            end
        end
    endfunction

    function [7:0] dark_region_gain;
        input [7:0] base_y;
        begin
            if (base_y < 8'd48) begin
                dark_region_gain = 8'd255;
            end else if (base_y < 8'd96) begin
                dark_region_gain = 8'd192;
            end else if (base_y < 8'd144) begin
                dark_region_gain = 8'd96;
            end else if (base_y < 8'd192) begin
                dark_region_gain = 8'd32;
            end else begin
                dark_region_gain = 8'd0;
            end
        end
    endfunction

    function [7:0] finalize_darkness_enhance;
        input [7:0]        base_y;
        input signed [8:0] offset;
        input [23:0]       boost_mul1;
        reg [8:0]          boosted_y;
        begin
            if (offset <= 9'sd0) begin
                finalize_darkness_enhance = apply_brightness_offset(base_y, offset);
            end else begin
                boosted_y = {1'b0, base_y} + ((boost_mul1 + 24'd32768) >> 16);

                if (boosted_y > 9'd255) begin
                    finalize_darkness_enhance = 8'hFF;
                end else begin
                    finalize_darkness_enhance = boosted_y[7:0];
                end
            end
        end
    endfunction

    assign has_active_lane = |s_keep;
    assign stage3_ready = (~m_valid) | m_ready;
    assign stage2_ready = (~stage3_valid) | stage3_ready;
    assign stage1_ready = (~stage2_valid) | stage2_ready;
    assign stage0_ready = (~stage1_valid) | stage1_ready;
    assign s_ready = stage0_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage0_valid <= 1'b0;
            stage0_data  <= {MAX_LANES*24{1'b0}};
            stage0_keep  <= {MAX_LANES{1'b0}};
            stage0_sof   <= 1'b0;
            stage0_eol   <= 1'b0;
            stage0_eof   <= 1'b0;
            stage0_brightness_offset <= 9'sd0;
            stage1_valid <= 1'b0;
            stage1_data  <= {MAX_LANES*24{1'b0}};
            stage1_segment_gain <= {MAX_LANES*8{1'b0}};
            stage1_headroom <= {MAX_LANES*8{1'b0}};
            stage1_keep  <= {MAX_LANES{1'b0}};
            stage1_sof   <= 1'b0;
            stage1_eol   <= 1'b0;
            stage1_eof   <= 1'b0;
            stage1_brightness_offset <= 9'sd0;
            stage2_valid <= 1'b0;
            stage2_data  <= {MAX_LANES*24{1'b0}};
            stage2_boost_mul0 <= {MAX_LANES*16{1'b0}};
            stage2_segment_gain <= {MAX_LANES*8{1'b0}};
            stage2_keep  <= {MAX_LANES{1'b0}};
            stage2_sof   <= 1'b0;
            stage2_eol   <= 1'b0;
            stage2_eof   <= 1'b0;
            stage2_brightness_offset <= 9'sd0;
            stage3_valid <= 1'b0;
            stage3_data  <= {MAX_LANES*24{1'b0}};
            stage3_boost_mul1 <= {MAX_LANES*24{1'b0}};
            stage3_keep  <= {MAX_LANES{1'b0}};
            stage3_sof   <= 1'b0;
            stage3_eol   <= 1'b0;
            stage3_eof   <= 1'b0;
            stage3_brightness_offset <= 9'sd0;
            m_valid <= 1'b0;
            m_data  <= {MAX_LANES*24{1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else begin
            if (stage3_ready) begin
                m_valid <= stage3_valid;
                if (stage3_valid) begin
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (stage3_keep[lane_idx]) begin
                            m_data[lane_idx*24 +: 24] <= {
                                finalize_darkness_enhance(
                                    stage3_data[lane_idx*24 + 16 +: 8],
                                    stage3_brightness_offset,
                                    stage3_boost_mul1[lane_idx*24 +: 24]
                                ),
                                stage3_data[lane_idx*24 + 8 +: 8],
                                stage3_data[lane_idx*24 +: 8]
                            };
                        end else begin
                            m_data[lane_idx*24 +: 24] <= 24'd0;
                        end
                    end
                    m_keep <= stage3_keep;
                    m_sof  <= stage3_sof;
                    m_eol  <= stage3_eol;
                    m_eof  <= stage3_eof;
                end else begin
                    m_data <= {MAX_LANES*24{1'b0}};
                    m_keep <= {MAX_LANES{1'b0}};
                    m_sof  <= 1'b0;
                    m_eol  <= 1'b0;
                    m_eof  <= 1'b0;
                end
            end

            if (stage2_ready) begin
                stage3_valid <= stage2_valid;
                if (stage2_valid) begin
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (stage2_keep[lane_idx]) begin
                            stage3_boost_mul1[lane_idx*24 +: 24] <=
                                stage2_boost_mul0[lane_idx*16 +: 16] *
                                stage2_segment_gain[lane_idx*8 +: 8];
                            stage3_data[lane_idx*24 +: 24] <= stage2_data[lane_idx*24 +: 24];
                        end else begin
                            stage3_boost_mul1[lane_idx*24 +: 24] <= 24'd0;
                            stage3_data[lane_idx*24 +: 24] <= 24'd0;
                        end
                    end
                    stage3_keep <= stage2_keep;
                    stage3_sof  <= stage2_sof;
                    stage3_eol  <= stage2_eol;
                    stage3_eof  <= stage2_eof;
                    stage3_brightness_offset <= stage2_brightness_offset;
                end else begin
                    stage3_boost_mul1 <= {MAX_LANES*24{1'b0}};
                    stage3_data <= {MAX_LANES*24{1'b0}};
                    stage3_keep <= {MAX_LANES{1'b0}};
                    stage3_sof  <= 1'b0;
                    stage3_eol  <= 1'b0;
                    stage3_eof  <= 1'b0;
                    stage3_brightness_offset <= 9'sd0;
                end
            end

            if (stage1_ready) begin
                stage2_valid <= stage1_valid;
                if (stage1_valid) begin
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (stage1_keep[lane_idx]) begin
                            stage2_boost_mul0[lane_idx*16 +: 16] <=
                                stage1_headroom[lane_idx*8 +: 8] *
                                stage1_brightness_offset[7:0];
                            stage2_segment_gain[lane_idx*8 +: 8] <= stage1_segment_gain[lane_idx*8 +: 8];
                            stage2_data[lane_idx*24 +: 24] <= stage1_data[lane_idx*24 +: 24];
                        end else begin
                            stage2_boost_mul0[lane_idx*16 +: 16] <= 16'd0;
                            stage2_segment_gain[lane_idx*8 +: 8] <= 8'd0;
                            stage2_data[lane_idx*24 +: 24] <= 24'd0;
                        end
                    end
                    stage2_keep <= stage1_keep;
                    stage2_sof  <= stage1_sof;
                    stage2_eol  <= stage1_eol;
                    stage2_eof  <= stage1_eof;
                    stage2_brightness_offset <= stage1_brightness_offset;
                end else begin
                    stage2_boost_mul0 <= {MAX_LANES*16{1'b0}};
                    stage2_segment_gain <= {MAX_LANES*8{1'b0}};
                    stage2_data <= {MAX_LANES*24{1'b0}};
                    stage2_keep <= {MAX_LANES{1'b0}};
                    stage2_sof  <= 1'b0;
                    stage2_eol  <= 1'b0;
                    stage2_eof  <= 1'b0;
                    stage2_brightness_offset <= 9'sd0;
                end
            end

            if (stage0_ready) begin
                stage1_valid <= stage0_valid;
                if (stage0_valid) begin
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (stage0_keep[lane_idx]) begin
                            stage1_data[lane_idx*24 +: 24] <= stage0_data[lane_idx*24 +: 24];
                            stage1_segment_gain[lane_idx*8 +: 8] <= dark_region_gain(stage0_data[lane_idx*24 + 16 +: 8]);
                            stage1_headroom[lane_idx*8 +: 8] <= 8'hFF - stage0_data[lane_idx*24 + 16 +: 8];
                        end else begin
                            stage1_data[lane_idx*24 +: 24] <= 24'd0;
                            stage1_segment_gain[lane_idx*8 +: 8] <= 8'd0;
                            stage1_headroom[lane_idx*8 +: 8] <= 8'd0;
                        end
                    end
                    stage1_keep <= stage0_keep;
                    stage1_sof  <= stage0_sof;
                    stage1_eol  <= stage0_eol;
                    stage1_eof  <= stage0_eof;
                    stage1_brightness_offset <= stage0_brightness_offset;
                end else begin
                    stage1_data <= {MAX_LANES*24{1'b0}};
                    stage1_segment_gain <= {MAX_LANES*8{1'b0}};
                    stage1_headroom <= {MAX_LANES*8{1'b0}};
                    stage1_keep <= {MAX_LANES{1'b0}};
                    stage1_sof  <= 1'b0;
                    stage1_eol  <= 1'b0;
                    stage1_eof  <= 1'b0;
                    stage1_brightness_offset <= 9'sd0;
                end
            end

            if (s_ready) begin
                stage0_valid <= s_valid && has_active_lane;
                if (s_valid && has_active_lane) begin
                    stage0_brightness_offset <= brightness_offset;
                    stage0_keep <= s_keep;
                    stage0_sof  <= s_sof;
                    stage0_eol  <= s_eol;
                    stage0_eof  <= s_eof;
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (s_keep[lane_idx]) begin
                            stage0_data[lane_idx*24 +: 24] <= {
                                gamma_luma(s_data[lane_idx*24 + 16 +: 8]),
                                s_data[lane_idx*24 + 8 +: 8],
                                s_data[lane_idx*24 +: 8]
                            };
                        end else begin
                            stage0_data[lane_idx*24 +: 24] <= 24'd0;
                        end
                    end
                end else begin
                    stage0_data <= {MAX_LANES*24{1'b0}};
                    stage0_keep <= {MAX_LANES{1'b0}};
                    stage0_sof  <= 1'b0;
                    stage0_eol  <= 1'b0;
                    stage0_eof  <= 1'b0;
                    stage0_brightness_offset <= 9'sd0;
                end
            end
        end
    end

endmodule
