module lowlight_enhance
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable_i,
    input  wire [15:0] brightness_gain_i,
    input  wire [15:0] gamma_sel_i,
    input  wire [15:0] pixel_in,
    input  wire        valid_in,
    input  wire        sof_in,
    input  wire        eol_in,
    output reg  [15:0] pixel_out,
    output reg         valid_out,
    output reg         sof_out,
    output reg         eol_out
);

    reg [7:0]  r8;
    reg [7:0]  g8;
    reg [7:0]  b8;
    reg [7:0]  y8;
    reg [7:0]  boost8;
    reg [7:0]  r8_adj;
    reg [7:0]  g8_adj;
    reg [7:0]  b8_adj;
    reg [15:0] gain_used;
    reg [15:0] y_scaled;
    reg [15:0] tone_map;
    reg [15:0] tone_delta;

    function [7:0] sat8;
        input [15:0] value;
        begin
            if (value[15:8] != 8'd0) begin
                sat8 = 8'hFF;
            end else begin
                sat8 = value[7:0];
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 16'd0;
            valid_out <= 1'b0;
            sof_out   <= 1'b0;
            eol_out   <= 1'b0;
        end else begin
            valid_out <= valid_in;
            sof_out   <= sof_in;
            eol_out   <= eol_in;

            r8 = {pixel_in[15:11], 3'b000};
            g8 = {pixel_in[10:5],  2'b00};
            b8 = {pixel_in[4:0],   3'b000};
            y8 = (r8 >> 2) + (g8 >> 1) + (b8 >> 3);

            gain_used = (brightness_gain_i < 16'h0010) ? 16'h0010 : brightness_gain_i;
            y_scaled  = (y8 * gain_used) >> 4;
            if (y_scaled > 16'd255) begin
                y_scaled = 16'd255;
            end

            case (gamma_sel_i[1:0])
                2'd0: tone_map = y_scaled;
                2'd1: tone_map = y_scaled + ((16'd255 - y_scaled) >> 3);
                2'd2: tone_map = y_scaled + ((16'd255 - y_scaled) >> 2);
                default: tone_map = y_scaled + ((16'd255 - y_scaled) >> 1);
            endcase

            if (tone_map > 16'd255) begin
                tone_map = 16'd255;
            end

            if (tone_map > y8) begin
                tone_delta = tone_map - y8;
            end else begin
                tone_delta = 16'd0;
            end

            boost8 = sat8(tone_delta);
            r8_adj = sat8(r8 + boost8);
            g8_adj = sat8(g8 + boost8);
            b8_adj = sat8(b8 + boost8);

            if (enable_i) begin
                pixel_out <= {r8_adj[7:3], g8_adj[7:2], b8_adj[7:3]};
            end else begin
                pixel_out <= pixel_in;
            end
        end
    end

endmodule

