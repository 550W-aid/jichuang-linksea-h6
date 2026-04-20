module test_pattern_source
(
    input  wire [10:0] x_i,
    input  wire [10:0] y_i,
    input  wire        active_i,
    input  wire        sof_i,
    input  wire        eol_i,
    output reg  [15:0] pixel_o,
    output reg         valid_o,
    output reg         sof_o,
    output reg         eol_o
);

    always @* begin
        valid_o = active_i;
        sof_o   = sof_i;
        eol_o   = eol_i;

        if (!active_i) begin
            pixel_o = 16'h0000;
        end else if (x_i < 11'd80) begin
            pixel_o = 16'hF800;
        end else if (x_i < 11'd160) begin
            pixel_o = 16'h07E0;
        end else if (x_i < 11'd240) begin
            pixel_o = 16'h001F;
        end else if (x_i < 11'd320) begin
            pixel_o = 16'hFFE0;
        end else if (x_i < 11'd400) begin
            pixel_o = 16'h07FF;
        end else if (x_i < 11'd480) begin
            pixel_o = 16'hF81F;
        end else if (x_i < 11'd560) begin
            pixel_o = 16'hFFFF;
        end else begin
            pixel_o = {y_i[4:0], x_i[5:0], y_i[4:0]};
        end
    end

endmodule

