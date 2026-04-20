module hist_eq_stub
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

    /*
     * TODO:
     * Replace this pass-through stage with a histogram-statistics + LUT remap path.
     * The final implementation will likely need frame- or tile-level statistics memory.
     */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out <= 16'd0;
            valid_out <= 1'b0;
            sof_out   <= 1'b0;
            eol_out   <= 1'b0;
        end else begin
            pixel_out <= pixel_in;
            valid_out <= valid_in;
            sof_out   <= sof_in;
            eol_out   <= eol_in;
        end
    end

endmodule

