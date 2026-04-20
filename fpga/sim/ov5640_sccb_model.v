`timescale 1ns/1ps

module ov5640_sccb_model #
(
    parameter [6:0] DEVICE_ADDR       = 7'h3C,
    parameter [7:0] CHIP_ID_HIGH      = 8'h56,
    parameter [7:0] CHIP_ID_LOW       = 8'h40
)
(
    input  wire rst_n,
    input  wire sccb_scl_i,
    input  wire sccb_sda_i,
    output wire sccb_sda_oe_o,
    input  wire force_nack_i,
    input  wire hold_sda_low_i
);

    reg        drive_low_r;
    reg [15:0] current_reg_r;
    reg [15:0] last_written_reg_r;
    reg [7:0]  last_written_data_r;

    event start_event;
    event stop_event;

    assign sccb_sda_oe_o = hold_sda_low_i || drive_low_r;

    always @(negedge sccb_sda_i) begin
        if (rst_n && sccb_scl_i) begin
            -> start_event;
        end
    end

    always @(posedge sccb_sda_i) begin
        if (rst_n && sccb_scl_i) begin
            -> stop_event;
        end
    end

    function [7:0] read_register;
        input [15:0] addr;
        begin
            case (addr)
                16'h300A: read_register = CHIP_ID_HIGH;
                16'h300B: read_register = CHIP_ID_LOW;
                default: begin
                    if (addr == last_written_reg_r) begin
                        read_register = last_written_data_r;
                    end else begin
                        read_register = 8'h00;
                    end
                end
            endcase
        end
    endfunction

    task wait_for_start;
        begin
            @start_event;
        end
    endtask

    task recv_byte;
        output [7:0] value;
        integer i;
        begin
            value = 8'd0;
            for (i = 7; i >= 0; i = i - 1) begin
                @(posedge sccb_scl_i);
                #1;
                value[i] = sccb_sda_i;
            end
        end
    endtask

    task recv_byte_after_first_clock;
        output [7:0] value;
        integer i;
        begin
            value    = 8'd0;
            #1;
            value[7] = sccb_sda_i;
            for (i = 6; i >= 0; i = i - 1) begin
                @(posedge sccb_scl_i);
                #1;
                value[i] = sccb_sda_i;
            end
        end
    endtask

    task send_ack;
        input ack_en;
        begin
            @(negedge sccb_scl_i);
            drive_low_r = ack_en && !force_nack_i;
            @(posedge sccb_scl_i);
            @(negedge sccb_scl_i);
            drive_low_r = 1'b0;
        end
    endtask

    task send_read_byte;
        input [7:0] value;
        integer i;
        begin
            for (i = 7; i >= 0; i = i - 1) begin
                if (sccb_scl_i !== 1'b0) begin
                    @(negedge sccb_scl_i);
                end
                drive_low_r = ~value[i];
                @(posedge sccb_scl_i);
            end
            @(negedge sccb_scl_i);
            drive_low_r = 1'b0;
            @(posedge sccb_scl_i);
            @(negedge sccb_scl_i);
            drive_low_r = 1'b0;
        end
    endtask

    reg [7:0] addr_byte;
    reg [7:0] reg_hi_byte;
    reg [7:0] reg_lo_byte;
    reg [7:0] data_byte;
    reg       saw_restart;
    reg       saw_stop;

    initial begin
        drive_low_r        = 1'b0;
        current_reg_r      = 16'd0;
        last_written_reg_r = 16'd0;
        last_written_data_r = 8'd0;

        forever begin
            wait(rst_n === 1'b1);
            wait_for_start();
            recv_byte(addr_byte);

            if (addr_byte[7:1] != DEVICE_ADDR) begin
                send_ack(1'b0);
                @stop_event;
            end else begin
                send_ack(1'b1);
                if (!addr_byte[0]) begin
                    recv_byte(reg_hi_byte);
                    send_ack(1'b1);
                    recv_byte(reg_lo_byte);
                    send_ack(1'b1);
                    current_reg_r = {reg_hi_byte, reg_lo_byte};

                    saw_restart = 1'b0;
                    saw_stop    = 1'b0;
                    data_byte   = 8'd0;

`ifdef __ICARUS__
                    fork : wait_next_transfer
                        begin
                            @start_event;
                            saw_restart = 1'b1;
                        end
                        begin
                            @stop_event;
                            saw_stop = 1'b1;
                        end
                        begin
                            recv_byte(data_byte);
                        end
                    join_any
                    disable wait_next_transfer;
`else
                    @(negedge sccb_sda_i or posedge sccb_sda_i or posedge sccb_scl_i);
                    #1;
                    if (!sccb_sda_i && sccb_scl_i) begin
                        saw_restart = 1'b1;
                    end else if (sccb_sda_i && sccb_scl_i) begin
                        saw_stop = 1'b1;
                    end else begin
                        recv_byte_after_first_clock(data_byte);
                    end
`endif

                    if (saw_restart) begin
                        recv_byte(addr_byte);
                        send_ack(addr_byte[7:1] == DEVICE_ADDR && addr_byte[0]);
                        if (addr_byte[7:1] == DEVICE_ADDR && addr_byte[0]) begin
                            send_read_byte(read_register(current_reg_r));
                        end
                        @stop_event;
                    end else if (!saw_stop) begin
                        send_ack(1'b1);
                        last_written_reg_r  = current_reg_r;
                        last_written_data_r = data_byte;
                        @stop_event;
                    end
                end else begin
                    send_read_byte(read_register(current_reg_r));
                    @stop_event;
                end
            end
        end
    end

endmodule
