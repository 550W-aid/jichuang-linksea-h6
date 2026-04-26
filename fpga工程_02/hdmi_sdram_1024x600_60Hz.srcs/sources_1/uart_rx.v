module uart_rx #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 115200
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_i,
    output reg [7:0]  data_o,
    output reg        data_valid_o
);

    localparam integer CLKS_PER_BIT      = (CLK_HZ + (BAUD / 2)) / BAUD;
    localparam integer HALF_CLKS_PER_BIT = (CLKS_PER_BIT > 1) ? (CLKS_PER_BIT / 2) : 1;

    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_START = 2'd1;
    localparam [1:0] ST_DATA  = 2'd2;
    localparam [1:0] ST_STOP  = 2'd3;

    reg [1:0]  state_r;
    reg [1:0]  rx_sync_r;
    reg [15:0] clk_cnt_r;
    reg [2:0]  bit_idx_r;
    reg [7:0]  shift_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync_r <= 2'b11;
        end else begin
            rx_sync_r <= {rx_sync_r[0], rx_i};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_r      <= ST_IDLE;
            clk_cnt_r    <= 16'd0;
            bit_idx_r    <= 3'd0;
            shift_r      <= 8'd0;
            data_o       <= 8'd0;
            data_valid_o <= 1'b0;
        end else begin
            data_valid_o <= 1'b0;

            case (state_r)
                ST_IDLE: begin
                    clk_cnt_r <= 16'd0;
                    bit_idx_r <= 3'd0;
                    if (!rx_sync_r[1]) begin
                        state_r   <= ST_START;
                        clk_cnt_r <= HALF_CLKS_PER_BIT - 1;
                    end
                end

                ST_START: begin
                    if (clk_cnt_r != 16'd0) begin
                        clk_cnt_r <= clk_cnt_r - 16'd1;
                    end else if (!rx_sync_r[1]) begin
                        state_r   <= ST_DATA;
                        clk_cnt_r <= CLKS_PER_BIT - 1;
                        bit_idx_r <= 3'd0;
                    end else begin
                        state_r <= ST_IDLE;
                    end
                end

                ST_DATA: begin
                    if (clk_cnt_r != 16'd0) begin
                        clk_cnt_r <= clk_cnt_r - 16'd1;
                    end else begin
                        shift_r[bit_idx_r] <= rx_sync_r[1];
                        clk_cnt_r <= CLKS_PER_BIT - 1;
                        if (bit_idx_r == 3'd7) begin
                            state_r <= ST_STOP;
                        end else begin
                            bit_idx_r <= bit_idx_r + 3'd1;
                        end
                    end
                end

                ST_STOP: begin
                    if (clk_cnt_r != 16'd0) begin
                        clk_cnt_r <= clk_cnt_r - 16'd1;
                    end else begin
                        state_r <= ST_IDLE;
                        if (rx_sync_r[1]) begin
                            data_o       <= shift_r;
                            data_valid_o <= 1'b1;
                        end
                    end
                end

                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
