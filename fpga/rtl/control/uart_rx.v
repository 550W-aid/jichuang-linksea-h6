module uart_rx #
(
    parameter integer CLK_HZ = 25_000_000,
    parameter integer BAUD   = 115200
)
(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_i,
    output reg  [7:0] data_o,
    output reg        data_valid_o
);

    localparam integer CLKS_PER_BIT = CLK_HZ / BAUD;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;

    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  rx_shift;
    reg [1:0]  state;

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_START = 2'd1;
    localparam [1:0] S_DATA  = 2'd2;
    localparam [1:0] S_STOP  = 2'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_count    <= 16'd0;
            bit_index    <= 3'd0;
            rx_shift     <= 8'd0;
            state        <= S_IDLE;
            data_o       <= 8'd0;
            data_valid_o <= 1'b0;
        end else begin
            data_valid_o <= 1'b0;

            case (state)
                S_IDLE: begin
                    clk_count <= 16'd0;
                    bit_index <= 3'd0;
                    if (!rx_i) begin
                        state <= S_START;
                    end
                end

                S_START: begin
                    if (clk_count == HALF_BIT) begin
                        clk_count <= 16'd0;
                        state     <= S_DATA;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count            <= 16'd0;
                        rx_shift[bit_index]  <= rx_i;
                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= S_STOP;
                        end else begin
                            bit_index <= bit_index + 3'd1;
                        end
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                S_STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        data_o       <= rx_shift;
                        data_valid_o <= 1'b1;
                        clk_count    <= 16'd0;
                        state        <= S_IDLE;
                    end else begin
                        clk_count <= clk_count + 16'd1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

