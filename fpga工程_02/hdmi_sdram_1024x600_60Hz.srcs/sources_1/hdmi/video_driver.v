module video_driver(
    input             pixel_clk,
    input             sys_rst_n,
    output            video_hs,
    output            video_vs,
    output            video_de,
    output [15:0]     video_rgb,
    output reg        data_req,
    input  [15:0]     pixel_data,
    output reg [10:0] pixel_xpos,
    output reg [10:0] pixel_ypos
);

// Match the board-verified 1024x600 smoke-test timing.
parameter H_SYNC  = 11'd136;
parameter H_BACK  = 11'd160;
parameter H_DISP  = 11'd1024;
parameter H_FRONT = 11'd24;
parameter H_TOTAL = 11'd1344;

parameter V_SYNC  = 11'd3;
parameter V_BACK  = 11'd21;
parameter V_DISP  = 11'd600;
parameter V_FRONT = 11'd1;
parameter V_TOTAL = 11'd625;

localparam H_START = H_SYNC;
localparam H_END   = H_SYNC + H_BACK + H_DISP;
localparam V_START = V_SYNC;
localparam V_END   = V_SYNC + V_BACK + V_DISP;

reg [10:0] cnt_h;
reg [10:0] cnt_v;

assign video_hs = (cnt_h < H_SYNC) ? 1'b0 : 1'b1;
assign video_vs = (cnt_v < V_SYNC) ? 1'b0 : 1'b1;
assign video_de = (cnt_h >= H_START + H_BACK) &&
                  (cnt_h <  H_END) &&
                  (cnt_v >= V_START + V_BACK) &&
                  (cnt_v <  V_END);
assign video_rgb = video_de ? pixel_data : 16'd0;

always @(posedge pixel_clk) begin
    pixel_xpos <= (cnt_h >= H_START + H_BACK - 2) &&
                  (cnt_h <  H_END - 2) ?
                  cnt_h - (H_START + H_BACK - 2) : 11'd0;

    pixel_ypos <= (cnt_v >= V_START + V_BACK) &&
                  (cnt_v <  V_END) ?
                  cnt_v - (V_START + V_BACK) : 11'd0;
end

always @(posedge pixel_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        data_req <= 1'b0;
    else
        data_req <= ((cnt_h >= H_START + H_BACK - 2) &&
                     (cnt_h <  H_END - 2)) &&
                    ((cnt_v >= V_START + V_BACK) &&
                     (cnt_v <  V_END));
end

always @(posedge pixel_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        cnt_h <= 11'd0;
    else
        cnt_h <= (cnt_h < H_TOTAL - 1) ? cnt_h + 1'b1 : 11'd0;
end

always @(posedge pixel_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        cnt_v <= 11'd0;
    else if (cnt_h == H_TOTAL - 1)
        cnt_v <= (cnt_v < V_TOTAL - 1) ? cnt_v + 1'b1 : 11'd0;
end

endmodule