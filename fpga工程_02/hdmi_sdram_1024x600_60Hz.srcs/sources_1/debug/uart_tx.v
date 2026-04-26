module uart_tx #
(
    parameter integer CLK_HZ = 25_000_000,
    parameter integer BAUD   = 115200
)
(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data_i,
    input  wire       data_valid_i,
    output reg        tx_o,
    output reg        busy_o
);

    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;

    reg [15:0] clk_count;
    reg [3:0]  bit_index;
    reg [9:0]  frame_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_count <= 16'd0;
            bit_index <= 4'd0;
            frame_reg <= 10'h3FF;
            tx_o      <= 1'b1;
            busy_o    <= 1'b0;
        end else begin
            if (!busy_o) begin
                tx_o <= 1'b1;
                if (data_valid_i) begin
                    busy_o    <= 1'b1;
                    frame_reg <= {1'b1, data_i, 1'b0};
                    clk_count <= 16'd0;
                    bit_index <= 4'd0;
                    tx_o      <= 1'b0;
                end
            end else begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    clk_count <= 16'd0;
                    if (bit_index == 4'd9) begin
                        busy_o    <= 1'b0;
                        bit_index <= 4'd0;
                        tx_o      <= 1'b1;
                    end else begin
                        bit_index <= bit_index + 4'd1;
                        tx_o      <= frame_reg[bit_index + 4'd1];
                    end
                end else begin
                    clk_count <= clk_count + 16'd1;
                end
            end
        end
    end

endmodule
