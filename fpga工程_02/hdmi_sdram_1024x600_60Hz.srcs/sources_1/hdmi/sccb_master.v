module sccb_master #
(
    parameter integer CLK_HZ                  = 50_000_000,
    parameter integer BUS_HZ                  = 100_000,
    parameter [6:0]   SENSOR_ADDR             = 7'h3C,
    parameter integer REG_ADDR_BYTES          = 2,
    parameter integer BUS_FREE_TIMEOUT_CYCLES = 100_000,
    parameter integer MAX_TRANSACTION_CYCLES  = 500_000
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start_i,
    input  wire        read_i,
    input  wire [15:0] reg_addr_i,
    input  wire [7:0]  wr_data_i,
    output reg  [7:0]  rd_data_o,
    output reg         busy_o,
    output reg         done_o,
    output reg         ack_ok_o,
    output reg         nack_o,
    output reg         timeout_o,
    output reg         sccb_scl_o,
    output reg         sccb_sda_oe_o,
    input  wire        sccb_sda_i
);

    localparam integer STEP_DIV = ((CLK_HZ / (BUS_HZ * 4)) > 0) ? (CLK_HZ / (BUS_HZ * 4)) : 1;

    localparam [3:0] ST_IDLE      = 4'd0;
    localparam [3:0] ST_BUS_FREE  = 4'd1;
    localparam [3:0] ST_START     = 4'd2;
    localparam [3:0] ST_SEND_BYTE = 4'd3;
    localparam [3:0] ST_RECV_ACK  = 4'd4;
    localparam [3:0] ST_RESTART   = 4'd5;
    localparam [3:0] ST_RECV_BYTE = 4'd6;
    localparam [3:0] ST_SEND_NACK = 4'd7;
    localparam [3:0] ST_STOP      = 4'd8;

    localparam [2:0] STEP_DEVADDR_W = 3'd0;
    localparam [2:0] STEP_REG_HI    = 3'd1;
    localparam [2:0] STEP_REG_LO    = 3'd2;
    localparam [2:0] STEP_DEVADDR_R = 3'd3;
    localparam [2:0] STEP_WR_DATA   = 3'd4;

    reg [3:0]  state;
    reg [1:0]  phase;
    reg [2:0]  step;
    reg [2:0]  bit_index;
    reg [7:0]  current_byte;
    reg [7:0]  rd_shift;
    reg [15:0] reg_addr_latched;
    reg [7:0]  wr_data_latched;
    reg        read_latched;
    reg        ack_sampled;
    reg [31:0] step_count;
    reg [31:0] bus_wait_count;
    reg [31:0] transaction_count;

    task begin_next_byte;
        input [2:0] next_step;
        input [7:0] next_byte;
        begin
            step         <= next_step;
            current_byte <= next_byte;
            bit_index    <= 3'd7;
            state        <= ST_SEND_BYTE;
            phase        <= 2'd0;
        end
    endtask

    task finish_with_nack;
        begin
            busy_o        <= 1'b0;
            done_o        <= 1'b1;
            ack_ok_o      <= 1'b0;
            nack_o        <= 1'b1;
            timeout_o     <= 1'b0;
            sccb_scl_o    <= 1'b1;
            sccb_sda_oe_o <= 1'b0;
            state         <= ST_IDLE;
            phase         <= 2'd0;
        end
    endtask

    task finish_with_timeout;
        begin
            busy_o        <= 1'b0;
            done_o        <= 1'b1;
            ack_ok_o      <= 1'b0;
            nack_o        <= 1'b0;
            timeout_o     <= 1'b1;
            sccb_scl_o    <= 1'b1;
            sccb_sda_oe_o <= 1'b0;
            state         <= ST_IDLE;
            phase         <= 2'd0;
        end
    endtask

    task finish_success;
        begin
            busy_o        <= 1'b0;
            done_o        <= 1'b1;
            ack_ok_o      <= 1'b1;
            nack_o        <= 1'b0;
            timeout_o     <= 1'b0;
            sccb_scl_o    <= 1'b1;
            sccb_sda_oe_o <= 1'b0;
            state         <= ST_IDLE;
            phase         <= 2'd0;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_data_o          <= 8'd0;
            busy_o             <= 1'b0;
            done_o             <= 1'b0;
            ack_ok_o           <= 1'b0;
            nack_o             <= 1'b0;
            timeout_o          <= 1'b0;
            sccb_scl_o         <= 1'b1;
            sccb_sda_oe_o      <= 1'b0;
            state              <= ST_IDLE;
            phase              <= 2'd0;
            step               <= STEP_DEVADDR_W;
            bit_index          <= 3'd7;
            current_byte       <= 8'd0;
            rd_shift           <= 8'd0;
            reg_addr_latched   <= 16'd0;
            wr_data_latched    <= 8'd0;
            read_latched       <= 1'b0;
            ack_sampled        <= 1'b0;
            step_count         <= 32'd0;
            bus_wait_count     <= 32'd0;
            transaction_count  <= 32'd0;
        end else begin
            done_o    <= 1'b0;
            ack_ok_o  <= 1'b0;
            nack_o    <= 1'b0;
            timeout_o <= 1'b0;

            if (!busy_o && start_i) begin
                busy_o            <= 1'b1;
                state             <= ST_BUS_FREE;
                phase             <= 2'd0;
                step              <= STEP_DEVADDR_W;
                bit_index         <= 3'd7;
                current_byte      <= {SENSOR_ADDR, 1'b0};
                reg_addr_latched  <= reg_addr_i;
                wr_data_latched   <= wr_data_i;
                read_latched      <= read_i;
                rd_shift          <= 8'd0;
                sccb_scl_o        <= 1'b1;
                sccb_sda_oe_o     <= 1'b0;
                step_count        <= 32'd0;
                bus_wait_count    <= 32'd0;
                transaction_count <= 32'd0;
            end else if (busy_o) begin
                transaction_count <= transaction_count + 32'd1;
                if (transaction_count >= MAX_TRANSACTION_CYCLES) begin
                    finish_with_timeout();
                end else if (step_count == STEP_DIV - 1) begin
                    step_count <= 32'd0;
                    case (state)
                        ST_BUS_FREE: begin
                            sccb_scl_o    <= 1'b1;
                            sccb_sda_oe_o <= 1'b0;
                            if (sccb_sda_i) begin
                                bus_wait_count <= 32'd0;
                                state          <= ST_START;
                                phase          <= 2'd0;
                            end else if (bus_wait_count >= BUS_FREE_TIMEOUT_CYCLES) begin
                                finish_with_timeout();
                            end else begin
                                bus_wait_count <= bus_wait_count + 32'd1;
                            end
                        end

                        ST_START: begin
                            case (phase)
                                2'd0: begin
                                    sccb_scl_o    <= 1'b1;
                                    sccb_sda_oe_o <= 1'b0;
                                    phase         <= 2'd1;
                                end
                                2'd1: begin
                                    sccb_scl_o    <= 1'b1;
                                    sccb_sda_oe_o <= 1'b1;
                                    phase         <= 2'd2;
                                end
                                2'd2: begin
                                    sccb_scl_o    <= 1'b0;
                                    sccb_sda_oe_o <= 1'b1;
                                    phase         <= 2'd3;
                                end
                                default: begin
                                    bit_index <= 3'd7;
                                    state     <= ST_SEND_BYTE;
                                    phase     <= 2'd0;
                                end
                            endcase
                        end

                        ST_SEND_BYTE: begin
                            case (phase)
                                2'd0: begin
                                    sccb_scl_o    <= 1'b0;
                                    sccb_sda_oe_o <= ~current_byte[bit_index];
                                    phase         <= 2'd1;
                                end
                                2'd1: begin
                                    sccb_scl_o <= 1'b1;
                                    phase      <= 2'd2;
                                end
                                2'd2: begin
                                    phase <= 2'd3;
                                end
                                default: begin
                                    sccb_scl_o <= 1'b0;
                                    if (bit_index == 3'd0) begin
                                        state <= ST_RECV_ACK;
                                        phase <= 2'd0;
                                    end else begin
                                        bit_index <= bit_index - 3'd1;
                                        phase     <= 2'd0;
                                    end
                                end
                            endcase
                        end

                        ST_RECV_ACK: begin
                            case (phase)
                                2'd0: begin
                                    sccb_scl_o    <= 1'b0;
                                    sccb_sda_oe_o <= 1'b0;
                                    phase         <= 2'd1;
                                end
                                2'd1: begin
                                    sccb_scl_o <= 1'b1;
                                    phase      <= 2'd2;
                                end
                                2'd2: begin
                                    ack_sampled <= ~sccb_sda_i;
                                    phase       <= 2'd3;
                                end
                                default: begin
                                    sccb_scl_o <= 1'b0;
                                    if (!ack_sampled) begin
                                        finish_with_nack();
                                    end else begin
                                        case (step)
                                            STEP_DEVADDR_W: begin
                                                if (REG_ADDR_BYTES >= 2) begin
                                                    begin_next_byte(STEP_REG_HI, reg_addr_latched[15:8]);
                                                end else begin
                                                    begin_next_byte(STEP_REG_LO, reg_addr_latched[7:0]);
                                                end
                                            end
                                            STEP_REG_HI: begin
                                                begin_next_byte(STEP_REG_LO, reg_addr_latched[7:0]);
                                            end
                                            STEP_REG_LO: begin
                                                if (read_latched) begin
                                                    step  <= STEP_DEVADDR_R;
                                                    state <= ST_RESTART;
                                                    phase <= 2'd0;
                                                end else begin
                                                    begin_next_byte(STEP_WR_DATA, wr_data_latched);
                                                end
                                            end
                                            STEP_DEVADDR_R: begin
                                                rd_shift  <= 8'd0;
                                                bit_index <= 3'd7;
                                                state     <= ST_RECV_BYTE;
                                                phase     <= 2'd0;
                                            end
                                            default: begin
                                                state <= ST_STOP;
                                                phase <= 2'd0;
                                            end
                                        endcase
                                    end
                                end
                            endcase
                        end

                        ST_RESTART: begin
                            case (phase)
                                2'd0: begin
                                    sccb_scl_o    <= 1'b0;
                                    sccb_sda_oe_o <= 1'b0;
                                    phase         <= 2'd1;
                                end
                                2'd1: begin
                                    sccb_scl_o    <= 1'b1;
                                    sccb_sda_oe_o <= 1'b0;
                                    phase         <= 2'd2;
                                end
                                2'd2: begin
                                    sccb_scl_o    <= 1'b1;
                                    sccb_sda_oe_o <= 1'b1;
                                    phase         <= 2'd3;
                                end
                                default: begin
                                    sccb_scl_o    <= 1'b0;
                                    sccb_sda_oe_o <= 1'b1;
                                    begin_next_byte(STEP_DEVADDR_R, {SENSOR_ADDR, 1'b1});
                                end
                            endcase
                        end

                        ST_RECV_BYTE: begin
                            case (phase)
                                2'd0: begin
                                    sccb_scl_o    <= 1'b0;
                                    sccb_sda_oe_o <= 1'b0;
                                    phase         <= 2'd1;
                                end
                                2'd1: begin
                                    sccb_scl_o <= 1'b1;
                                    phase      <= 2'd2;
                                end
                                2'd2: begin
                                    rd_shift[bit_index] <= sccb_sda_i;
                                    phase               <= 2'd3;
                                end
                                default: begin
                                    sccb_scl_o <= 1'b0;
                                    if (bit_index == 3'd0) begin
                                        state <= ST_SEND_NACK;
                                        phase <= 2'd0;
                                    end else begin
                                        bit_index <= bit_index - 3'd1;
                                        phase     <= 2'd0;
                                    end
                                end
                            endcase
                        end

                        ST_SEND_NACK: begin
                            case (phase)
                                2'd0: begin
                                    sccb_scl_o    <= 1'b0;
                                    sccb_sda_oe_o <= 1'b0;
                                    phase         <= 2'd1;
                                end
                                2'd1: begin
                                    sccb_scl_o <= 1'b1;
                                    phase      <= 2'd2;
                                end
                                2'd2: begin
                                    phase <= 2'd3;
                                end
                                default: begin
                                    sccb_scl_o <= 1'b0;
                                    rd_data_o  <= rd_shift;
                                    state      <= ST_STOP;
                                    phase      <= 2'd0;
                                end
                            endcase
                        end

                        ST_STOP: begin
                            case (phase)
                                2'd0: begin
                                    sccb_scl_o    <= 1'b0;
                                    sccb_sda_oe_o <= 1'b1;
                                    phase         <= 2'd1;
                                end
                                2'd1: begin
                                    sccb_scl_o    <= 1'b1;
                                    sccb_sda_oe_o <= 1'b1;
                                    phase         <= 2'd2;
                                end
                                2'd2: begin
                                    sccb_scl_o    <= 1'b1;
                                    sccb_sda_oe_o <= 1'b0;
                                    phase         <= 2'd3;
                                end
                                default: begin
                                    finish_success();
                                end
                            endcase
                        end

                        default: begin
                            finish_with_timeout();
                        end
                    endcase
                end else begin
                    step_count <= step_count + 32'd1;
                end
            end
        end
    end

endmodule
