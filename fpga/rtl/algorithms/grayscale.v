module grayscale
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable_i,
    input  wire [15:0] pixel_in,
    input  wire        valid_in,
    input  wire        sof_in,
    input  wire        eol_in,
    output reg  [15:0] pixel_out,
    output reg         valid_out,
    output reg         sof_out,
    output reg         eol_out
);

    reg [7:0] r8;
    reg [7:0] g8;
    reg [7:0] b8;
    reg [7:0] y8;

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
            y8 = ((r8 >> 2) + (g8 >> 1) + (b8 >> 3));

            if (enable_i) begin
                pixel_out <= {y8[7:3], y8[7:2], y8[7:3]};
            end else begin
                pixel_out <= pixel_in;
            end
        end
    end

endmodule

