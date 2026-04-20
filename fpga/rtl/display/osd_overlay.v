module osd_overlay
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] mode_i,
    input  wire [15:0] osd_sel_i,
    input  wire [15:0] fps_i,
    input  wire [10:0] x_i,
    input  wire [10:0] y_i,
    input  wire [15:0] pixel_in,
    input  wire        valid_in,
    input  wire        sof_in,
    input  wire        eol_in,
    output reg  [15:0] pixel_out,
    output reg         valid_out,
    output reg         sof_out,
    output reg         eol_out
);

    reg [15:0] bar_color;

    always @* begin
        case (mode_i[1:0])
            2'd0: bar_color = 16'h07E0;
            2'd1: bar_color = 16'hFFFF;
            2'd2: bar_color = 16'hFFE0;
            default: bar_color = 16'hF800;
        endcase
    end

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

            if (valid_in && osd_sel_i[0] && (y_i < 11'd12)) begin
                if (x_i < {5'd0, fps_i[9:0]}) begin
                    pixel_out <= 16'hFFFF;
                end else begin
                    pixel_out <= bar_color;
                end
            end else begin
                pixel_out <= pixel_in;
            end
        end
    end

endmodule

