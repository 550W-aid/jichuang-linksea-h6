`timescale 1ns/1ps

module tb_sccb_master;

    reg         clk;
    reg         rst_n;
    reg         start;
    reg         read_en;
    reg  [15:0] reg_addr;
    reg  [7:0]  wr_data;
    reg         force_nack;
    reg         force_hold_low;

    wire [7:0]  rd_data;
    wire        busy;
    wire        done;
    wire        ack_ok;
    wire        nack;
    wire        timeout;
    wire        scl;
    wire        master_sda_oe;
    wire        slave_sda_oe;
    wire        sda_line;

    assign sda_line = (master_sda_oe || slave_sda_oe || force_hold_low) ? 1'b0 : 1'b1;

    sccb_master #(
        .CLK_HZ(1_000_000),
        .BUS_HZ(100_000),
        .BUS_FREE_TIMEOUT_CYCLES(40),
        .MAX_TRANSACTION_CYCLES(4000)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(start),
        .read_i(read_en),
        .reg_addr_i(reg_addr),
        .wr_data_i(wr_data),
        .rd_data_o(rd_data),
        .busy_o(busy),
        .done_o(done),
        .ack_ok_o(ack_ok),
        .nack_o(nack),
        .timeout_o(timeout),
        .sccb_scl_o(scl),
        .sccb_sda_oe_o(master_sda_oe),
        .sccb_sda_i(sda_line)
    );

    ov5640_sccb_model u_model (
        .rst_n(rst_n),
        .sccb_scl_i(scl),
        .sccb_sda_i(sda_line),
        .sccb_sda_oe_o(slave_sda_oe),
        .force_nack_i(force_nack),
        .hold_sda_low_i(1'b0)
    );

    always #500 clk = ~clk;

    task pulse_start;
        input start_read;
        input [15:0] start_addr;
        input [7:0] start_data;
        begin
            @(posedge clk);
            read_en  <= start_read;
            reg_addr <= start_addr;
            wr_data  <= start_data;
            start    <= 1'b1;
            @(posedge clk);
            start    <= 1'b0;
        end
    endtask

    task wait_done;
        integer count;
        begin
            count = 0;
            while (!done) begin
                @(posedge clk);
                count = count + 1;
                if (count > 5000) begin
                    $fatal(1, "Timed out waiting for SCCB transaction to finish.");
                end
            end
        end
    endtask

    initial begin
        clk           = 1'b0;
        rst_n         = 1'b0;
        start         = 1'b0;
        read_en       = 1'b0;
        reg_addr      = 16'd0;
        wr_data       = 8'd0;
        force_nack    = 1'b0;
        force_hold_low = 1'b0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        pulse_start(1'b1, 16'h300A, 8'h00);
        wait_done();
        if (!ack_ok || rd_data != 8'h56) begin
            $fatal(1, "Expected SCCB read of OV5640 high ID to succeed.");
        end

        pulse_start(1'b0, 16'h3100, 8'hA5);
        wait_done();
        if (!ack_ok) begin
            $fatal(1, "Expected SCCB write transaction to ACK.");
        end

        force_nack = 1'b1;
        pulse_start(1'b1, 16'h300B, 8'h00);
        wait_done();
        if (!nack) begin
            $fatal(1, "Expected SCCB transaction to report NACK.");
        end
        force_nack = 1'b0;

        force_hold_low = 1'b1;
        pulse_start(1'b1, 16'h300A, 8'h00);
        wait_done();
        if (!timeout) begin
            $fatal(1, "Expected SCCB transaction to timeout when SDA is held low.");
        end
        force_hold_low = 1'b0;

        $display("tb_sccb_master: PASS");
        $finish;
    end

endmodule
