module uart_ctrl #
(
    parameter integer CLK_HZ = 25_000_000,
    parameter integer BAUD   = 115200
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        uart_rx_i,
    output wire        uart_tx_o,
    output reg         wr_en_o,
    output reg  [7:0]  addr_o,
    output reg  [15:0] wr_data_o,
    input  wire [15:0] rd_data_i
);

    localparam [7:0] FRAME_HEAD = 8'h55;
    localparam [7:0] RESP_HEAD  = 8'hAA;
    localparam [7:0] CMD_WRITE  = 8'h01;
    localparam [7:0] CMD_READ   = 8'h02;
    localparam [7:0] CMD_PING   = 8'h03;

    localparam [7:0] STATUS_OK       = 8'h00;
    localparam [7:0] STATUS_BAD_CSUM = 8'hE0;
    localparam [7:0] STATUS_BAD_CMD  = 8'hE1;

    wire [7:0] rx_byte;
    wire       rx_valid;
    reg  [7:0] tx_byte;
    reg        tx_valid;
    wire       tx_busy;

    reg [2:0] parser_state;
    reg [7:0] cmd_reg;
    reg [7:0] addr_reg;
    reg [7:0] data_hi_reg;
    reg [7:0] data_lo_reg;
    reg [7:0] checksum_reg;

    reg [7:0] resp_bytes [0:5];
    reg [2:0] resp_index;
    reg       resp_active;
    reg       read_pending;
    reg [7:0] read_addr_pending;

    uart_rx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx_i(uart_rx_i),
        .data_o(rx_byte),
        .data_valid_o(rx_valid)
    );

    uart_tx #(
        .CLK_HZ(CLK_HZ),
        .BAUD(BAUD)
    ) u_uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .data_i(tx_byte),
        .data_valid_i(tx_valid),
        .tx_o(uart_tx_o),
        .busy_o(tx_busy)
    );

    function [7:0] calc_checksum;
        input [7:0] b0;
        input [7:0] b1;
        input [7:0] b2;
        input [7:0] b3;
        input [7:0] b4;
        begin
            calc_checksum = b0 ^ b1 ^ b2 ^ b3 ^ b4;
        end
    endfunction

    task load_response;
        input [7:0] status;
        input [7:0] addr;
        input [15:0] data_value;
        reg [7:0] csum;
        begin
            csum = calc_checksum(RESP_HEAD, status, addr, data_value[15:8], data_value[7:0]);
            resp_bytes[0] <= RESP_HEAD;
            resp_bytes[1] <= status;
            resp_bytes[2] <= addr;
            resp_bytes[3] <= data_value[15:8];
            resp_bytes[4] <= data_value[7:0];
            resp_bytes[5] <= csum;
            resp_index    <= 3'd0;
            resp_active   <= 1'b1;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parser_state <= 3'd0;
            cmd_reg      <= 8'd0;
            addr_reg     <= 8'd0;
            data_hi_reg  <= 8'd0;
            data_lo_reg  <= 8'd0;
            checksum_reg <= 8'd0;
            wr_en_o      <= 1'b0;
            addr_o       <= 8'd0;
            wr_data_o    <= 16'd0;
            tx_byte      <= 8'd0;
            tx_valid     <= 1'b0;
            resp_index   <= 3'd0;
            resp_active  <= 1'b0;
            read_pending <= 1'b0;
            read_addr_pending <= 8'd0;
        end else begin
            wr_en_o   <= 1'b0;
            tx_valid  <= 1'b0;

            if (read_pending && !resp_active) begin
                load_response(STATUS_OK, read_addr_pending, rd_data_i);
                read_pending <= 1'b0;
            end

            if (resp_active && !tx_busy) begin
                tx_byte  <= resp_bytes[resp_index];
                tx_valid <= 1'b1;
                if (resp_index == 3'd5) begin
                    resp_index  <= 3'd0;
                    resp_active <= 1'b0;
                end else begin
                    resp_index <= resp_index + 3'd1;
                end
            end

            if (rx_valid) begin
                case (parser_state)
                    3'd0: begin
                        if (rx_byte == FRAME_HEAD) begin
                            parser_state <= 3'd1;
                            checksum_reg <= rx_byte;
                        end
                    end

                    3'd1: begin
                        cmd_reg       <= rx_byte;
                        checksum_reg  <= checksum_reg ^ rx_byte;
                        parser_state  <= 3'd2;
                    end

                    3'd2: begin
                        addr_reg      <= rx_byte;
                        checksum_reg  <= checksum_reg ^ rx_byte;
                        parser_state  <= 3'd3;
                    end

                    3'd3: begin
                        data_hi_reg   <= rx_byte;
                        checksum_reg  <= checksum_reg ^ rx_byte;
                        parser_state  <= 3'd4;
                    end

                    3'd4: begin
                        data_lo_reg   <= rx_byte;
                        checksum_reg  <= checksum_reg ^ rx_byte;
                        parser_state  <= 3'd5;
                    end

                    3'd5: begin
                        parser_state <= 3'd0;
                        if ((checksum_reg ^ rx_byte) != 8'h00) begin
                            load_response(STATUS_BAD_CSUM, addr_reg, 16'h0000);
                        end else begin
                            case (cmd_reg)
                                CMD_WRITE: begin
                                    addr_o    <= addr_reg;
                                    wr_data_o <= {data_hi_reg, data_lo_reg};
                                    wr_en_o   <= 1'b1;
                                    load_response(STATUS_OK, addr_reg, {data_hi_reg, data_lo_reg});
                                end

                                CMD_READ: begin
                                    addr_o            <= addr_reg;
                                    read_addr_pending <= addr_reg;
                                    read_pending      <= 1'b1;
                                end

                                CMD_PING: begin
                                    load_response(STATUS_OK, 8'h00, 16'hCAFE);
                                end

                                default: begin
                                    load_response(STATUS_BAD_CMD, addr_reg, 16'h0000);
                                end
                            endcase
                        end
                    end

                    default: begin
                        parser_state <= 3'd0;
                    end
                endcase
            end
        end
    end

endmodule
