`timescale 1ns/1ps
`include "fpga/rtl/common/video_regs.vh"

module tb_ov5640_reg_if;

    reg         clk;
    reg         rst_n;
    reg         cmd_strobe;
    reg  [15:0] cmd;
    reg  [15:0] reg_addr;
    reg  [15:0] wr_data;
    reg  [15:0] pixel;
    reg         valid;
    reg         sof;
    reg         eol;

    wire [15:0] rd_data;
    wire [15:0] status;
    wire [15:0] frame_counter;
    wire [15:0] line_counter;
    wire [15:0] last_pixel;
    wire [15:0] error_count;
    wire        cam_reset;
    wire        cam_pwdn;
    wire        init_done;
    wire        scl;
    wire        master_sda_oe;
    wire        slave_sda_oe;
    wire        sda_line;

    assign sda_line = (master_sda_oe || slave_sda_oe) ? 1'b0 : 1'b1;

    ov5640_reg_if #(
        .CLK_HZ(1_000_000),
        .SCCB_HZ(100_000),
        .POWERUP_DELAY_CYCLES(8),
        .RESET_RELEASE_CYCLES(8)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_strobe_i(cmd_strobe),
        .cmd_i(cmd),
        .reg_addr_i(reg_addr),
        .wr_data_i(wr_data),
        .rd_data_o(rd_data),
        .status_o(status),
        .frame_counter_o(frame_counter),
        .line_counter_o(line_counter),
        .last_pixel_o(last_pixel),
        .error_count_o(error_count),
        .pixel_i(pixel),
        .valid_i(valid),
        .sof_i(sof),
        .eol_i(eol),
        .cam_reset_o(cam_reset),
        .cam_pwdn_o(cam_pwdn),
        .init_done_o(init_done),
        .sccb_scl_o(scl),
        .sccb_sda_oe_o(master_sda_oe),
        .sccb_sda_i(sda_line)
    );

    ov5640_sccb_model u_model (
        .rst_n(rst_n),
        .sccb_scl_i(scl),
        .sccb_sda_i(sda_line),
        .sccb_sda_oe_o(slave_sda_oe),
        .force_nack_i(1'b0),
        .hold_sda_low_i(1'b0)
    );

    always #500 clk = ~clk;

    task issue_command;
        input [15:0] cmd_value;
        input [15:0] reg_value;
        input [15:0] wr_value;
        begin
            @(posedge clk);
            reg_addr    <= reg_value;
            wr_data     <= wr_value;
            cmd         <= cmd_value;
            cmd_strobe  <= 1'b1;
            @(posedge clk);
            cmd_strobe  <= 1'b0;
            cmd         <= 16'd0;
        end
    endtask

    task wait_status_done;
        integer count;
        begin
            count = 0;
            while (status[`CAM_STATUS_DONE_BIT]) begin
                @(posedge clk);
                count = count + 1;
                if (count > 5000) begin
                    $fatal(1, "Timed out waiting for camera status done bit to clear.");
                end
            end
            count = 0;
            while (!status[`CAM_STATUS_DONE_BIT]) begin
                @(posedge clk);
                count = count + 1;
                if (count > 5000) begin
                    $fatal(1, "Timed out waiting for camera status done bit.");
                end
            end
        end
    endtask

    initial begin
        clk        = 1'b0;
        rst_n      = 1'b0;
        cmd_strobe = 1'b0;
        cmd        = 16'd0;
        reg_addr   = 16'd0;
        wr_data    = 16'd0;
        pixel      = 16'd0;
        valid      = 1'b0;
        sof        = 1'b0;
        eol        = 1'b0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        wait(init_done);
        if (cam_pwdn || !cam_reset) begin
            $fatal(1, "Expected OV5640 control pins to leave reset after startup.");
        end

        issue_command(`CAM_CMD_READ, `OV5640_CHIP_ID_HIGH_REG, 16'd0);
        wait_status_done();
        if (rd_data != 16'h0056 || !status[`CAM_STATUS_ACK_OK_BIT]) begin
            $fatal(1, "Expected OV5640 high chip ID readback to succeed.");
        end

        issue_command(`CAM_CMD_READ, `OV5640_CHIP_ID_LOW_REG, 16'd0);
        wait_status_done();
        if (rd_data != 16'h0040 || !status[`CAM_STATUS_SENSOR_PRESENT_BIT]) begin
            $fatal(1, "Expected sensor_present bit after both OV5640 chip ID reads.");
        end

        @(posedge clk);
        pixel <= 16'h1111;
        valid <= 1'b1;
        sof   <= 1'b1;
        eol   <= 1'b0;

        @(posedge clk);
        pixel <= 16'h2222;
        sof   <= 1'b0;
        eol   <= 1'b1;

        @(posedge clk);
        pixel <= 16'h3333;
        eol   <= 1'b0;

        @(posedge clk);
        pixel <= 16'h4444;
        eol   <= 1'b1;

        @(posedge clk);
        valid <= 1'b0;
        eol   <= 1'b0;
        pixel <= 16'd0;

        repeat (4) @(posedge clk);
        if (!status[`CAM_STATUS_DATA_ACTIVE_BIT]) begin
            $fatal(1, "Expected data_active bit after valid camera pixels.");
        end
        if (frame_counter != 16'd1 || line_counter != 16'd2 || last_pixel != 16'h4444) begin
            $fatal(1, "Expected camera counters to track incoming pixels.");
        end
        if (error_count != 16'd0) begin
            $fatal(1, "Did not expect SCCB error counter to increment in the happy path.");
        end

        $display("tb_ov5640_reg_if: PASS");
        $finish;
    end

endmodule
