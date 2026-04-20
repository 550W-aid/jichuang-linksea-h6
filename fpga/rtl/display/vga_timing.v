module vga_timing #
(
    parameter integer H_ACTIVE = 640,
    parameter integer H_FP     = 16,
    parameter integer H_SYNC   = 96,
    parameter integer H_BP     = 48,
    parameter integer V_ACTIVE = 480,
    parameter integer V_FP     = 10,
    parameter integer V_SYNC   = 2,
    parameter integer V_BP     = 33
)
(
    input  wire        clk,
    input  wire        rst_n,
    output reg         hsync_o,
    output reg         vsync_o,
    output reg         active_o,
    output reg  [10:0] x_o,
    output reg  [10:0] y_o,
    output reg         sof_o,
    output reg         eol_o
);

    localparam integer H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam integer V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;

    reg [10:0] h_count;
    reg [10:0] v_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count  <= 11'd0;
            v_count  <= 11'd0;
            hsync_o  <= 1'b1;
            vsync_o  <= 1'b1;
            active_o <= 1'b0;
            x_o      <= 11'd0;
            y_o      <= 11'd0;
            sof_o    <= 1'b0;
            eol_o    <= 1'b0;
        end else begin
            sof_o <= 1'b0;
            eol_o <= 1'b0;

            if (h_count == H_TOTAL - 1) begin
                h_count <= 11'd0;
                if (v_count == V_TOTAL - 1) begin
                    v_count <= 11'd0;
                end else begin
                    v_count <= v_count + 11'd1;
                end
            end else begin
                h_count <= h_count + 11'd1;
            end

            hsync_o  <= ~((h_count >= H_ACTIVE + H_FP) && (h_count < H_ACTIVE + H_FP + H_SYNC));
            vsync_o  <= ~((v_count >= V_ACTIVE + V_FP) && (v_count < V_ACTIVE + V_FP + V_SYNC));
            active_o <= (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
            x_o      <= h_count;
            y_o      <= v_count;

            if ((h_count == 0) && (v_count == 0)) begin
                sof_o <= 1'b1;
            end

            if ((h_count == H_ACTIVE - 1) && (v_count < V_ACTIVE)) begin
                eol_o <= 1'b1;
            end
        end
    end

endmodule

