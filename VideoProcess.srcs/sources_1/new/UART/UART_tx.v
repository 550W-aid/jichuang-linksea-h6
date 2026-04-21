module uart_tx(
    input        sys_clk,
    input        sys_rst_n,
    input        uart_en,
    input  [7:0] uart_din,
    output       uart_tx_busy,
    output reg   uart_txd
);

parameter CLK_FREQ = 50000000;
parameter UART_BPS = 115200;

localparam integer BPS_CNT = CLK_FREQ / UART_BPS;
localparam [3:0]   FRAME_BITS = 4'd10;  // 1 start + 8 data + 1 stop

reg        uart_en_d0;
reg        uart_en_d1;
reg        tx_busy_r;
reg [15:0] baud_cnt;
reg [3:0]  bit_cnt;
reg [7:0]  tx_shift;

wire start_pulse;

assign start_pulse  = uart_en_d0 & ~uart_en_d1;
assign uart_tx_busy = tx_busy_r;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        uart_en_d0 <= 1'b0;
        uart_en_d1 <= 1'b0;
    end
    else begin
        uart_en_d0 <= uart_en;
        uart_en_d1 <= uart_en_d0;
    end
end

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
        tx_busy_r <= 1'b0;
        baud_cnt  <= 16'd0;
        bit_cnt   <= 4'd0;
        tx_shift  <= 8'd0;
        uart_txd  <= 1'b1;
    end
    else if (!tx_busy_r) begin
        uart_txd <= 1'b1;
        baud_cnt <= 16'd0;
        bit_cnt  <= 4'd0;

        if (start_pulse) begin
            tx_busy_r <= 1'b1;
            tx_shift  <= uart_din;
            uart_txd  <= 1'b0;
        end
    end
    else begin
        if (baud_cnt == BPS_CNT - 1) begin
            baud_cnt <= 16'd0;
            bit_cnt  <= bit_cnt + 1'b1;

            case (bit_cnt)
                4'd0: uart_txd <= tx_shift[0];
                4'd1: uart_txd <= tx_shift[1];
                4'd2: uart_txd <= tx_shift[2];
                4'd3: uart_txd <= tx_shift[3];
                4'd4: uart_txd <= tx_shift[4];
                4'd5: uart_txd <= tx_shift[5];
                4'd6: uart_txd <= tx_shift[6];
                4'd7: uart_txd <= tx_shift[7];
                4'd8: uart_txd <= 1'b1;
                4'd9: begin
                    uart_txd  <= 1'b1;
                    tx_busy_r <= 1'b0;
                end
                default: begin
                    uart_txd  <= 1'b1;
                    tx_busy_r <= 1'b0;
                end
            endcase
        end
        else begin
            baud_cnt <= baud_cnt + 1'b1;
        end
    end
end

endmodule
