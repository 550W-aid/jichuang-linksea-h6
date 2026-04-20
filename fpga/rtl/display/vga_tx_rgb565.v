module vga_tx_rgb565
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        active_i,
    input  wire [15:0] pixel_i,
    input  wire        valid_i,
    output reg  [4:0]  vga_r_o,
    output reg  [5:0]  vga_g_o,
    output reg  [4:0]  vga_b_o
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vga_r_o <= 5'd0;
            vga_g_o <= 6'd0;
            vga_b_o <= 5'd0;
        end else if (active_i && valid_i) begin
            vga_r_o <= pixel_i[15:11];
            vga_g_o <= pixel_i[10:5];
            vga_b_o <= pixel_i[4:0];
        end else begin
            vga_r_o <= 5'd0;
            vga_g_o <= 6'd0;
            vga_b_o <= 5'd0;
        end
    end

endmodule

