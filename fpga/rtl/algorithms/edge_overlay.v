module edge_overlay
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable_i,
    input  wire [15:0] edge_sel_i,
    input  wire [15:0] pixel_in,
    input  wire        valid_in,
    input  wire        sof_in,
    input  wire        eol_in,
    output reg  [15:0] pixel_out,
    output reg         valid_out,
    output reg         sof_out,
    output reg         eol_out
);

    reg [7:0] prev_y;
    reg [7:0] curr_y;
    reg [7:0] threshold;
    reg [7:0] diff_y;
    reg [7:0] r8;
    reg [7:0] g8;
    reg [7:0] b8;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_y    <= 8'd0;
            pixel_out <= 16'd0;
            valid_out <= 1'b0;
            sof_out   <= 1'b0;
            eol_out   <= 1'b0;
        end else begin
            valid_out <= valid_in;
            sof_out   <= sof_in;
            eol_out   <= eol_in;

            r8       = {pixel_in[15:11], 3'b000};
            g8       = {pixel_in[10:5],  2'b00};
            b8       = {pixel_in[4:0],   3'b000};
            curr_y   = (r8 >> 2) + (g8 >> 1) + (b8 >> 3);
            threshold = (edge_sel_i[7:0] == 8'd0) ? 8'd16 : edge_sel_i[7:0];

            if (curr_y >= prev_y) begin
                diff_y = curr_y - prev_y;
            end else begin
                diff_y = prev_y - curr_y;
            end

            if (enable_i && valid_in && (diff_y > threshold)) begin
                pixel_out <= 16'hF800;
            end else begin
                pixel_out <= pixel_in;
            end

            if (valid_in) begin
                prev_y <= curr_y;
            end

            if (sof_in || eol_in) begin
                prev_y <= 8'd0;
            end
        end
    end

endmodule

