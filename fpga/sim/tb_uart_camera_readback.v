`timescale 1ns/1ps
`include "fpga/rtl/common/video_regs.vh"

module tb_uart_camera_readback;

    localparam integer SYS_CLK_HZ = 50_000_000;
    localparam integer BAUD       = 1_000_000;
    localparam integer BIT_NS     = 1_000;

    reg         clk;
    reg         rst_n;
    reg         uart_rx;

    wire        uart_tx;
    wire        wr_en;
    wire [7:0]  addr;
    wire [15:0] wr_data;
    wire [15:0] base_rd_data;
    wire [15:0] camera_rd_data;
    wire [15:0] rd_data;
    wire        cam_cmd_strobe;
    wire [15:0] cam_cmd;
    wire [15:0] cam_reg_addr;
    wire [15:0] cam_wr_data;
    wire [15:0] cam_reg_rd_data;
    wire [15:0] cam_status;
    wire [15:0] cam_frame_counter;
    wire [15:0] cam_line_counter;
    wire [15:0] cam_last_pixel;
    wire [15:0] cam_error_count;
    wire        cam_reset;
    wire        cam_pwdn;
    wire        scl;
    wire        master_sda_oe;
    wire        slave_sda_oe;
    wire        sda_line;
    wire [7:0]  host_rx_byte;
    wire        host_rx_valid;

    assign rd_data = (addr >= `REG_CAM_CMD && addr <= `REG_CAM_ERROR_COUNT) ? camera_rd_data : base_rd_data;
    assign sda_line = (master_sda_oe || slave_sda_oe) ? 1'b0 : 1'b1;

    uart_ctrl #(
        .CLK_HZ(SYS_CLK_HZ),
        .BAUD(BAUD)
    ) u_uart_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx_i(uart_rx),
        .uart_tx_o(uart_tx),
        .wr_en_o(wr_en),
        .addr_o(addr),
        .wr_data_o(wr_data),
        .rd_data_i(rd_data)
    );

    uart_rx #(
        .CLK_HZ(SYS_CLK_HZ),
        .BAUD(BAUD)
    ) u_host_uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx_i(uart_tx),
        .data_o(host_rx_byte),
        .data_valid_o(host_rx_valid)
    );

    ctrl_regs u_ctrl_regs (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(base_rd_data),
        .status_in(16'd0),
        .fps_counter_in(16'd0),
        .heartbeat_in(16'd0),
        .mode(),
        .algo_enable(),
        .brightness_gain(),
        .gamma_sel(),
        .scale_sel(),
        .rotate_sel(),
        .edge_sel(),
        .osd_sel()
    );

    camera_ctrl_regs u_camera_ctrl_regs (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(camera_rd_data),
        .cam_cmd_strobe_o(cam_cmd_strobe),
        .cam_cmd_o(cam_cmd),
        .cam_reg_addr_o(cam_reg_addr),
        .cam_wr_data_o(cam_wr_data),
        .cam_rd_data_i(cam_reg_rd_data),
        .cam_status_i(cam_status),
        .cam_frame_counter_i(cam_frame_counter),
        .cam_line_counter_i(cam_line_counter),
        .cam_last_pixel_i(cam_last_pixel),
        .cam_error_count_i(cam_error_count)
    );

    ov5640_reg_if #(
        .CLK_HZ(SYS_CLK_HZ),
        .SCCB_HZ(100_000),
        .POWERUP_DELAY_CYCLES(32),
        .RESET_RELEASE_CYCLES(32)
    ) u_ov5640_reg_if (
        .clk(clk),
        .rst_n(rst_n),
        .cmd_strobe_i(cam_cmd_strobe),
        .cmd_i(cam_cmd),
        .reg_addr_i(cam_reg_addr),
        .wr_data_i(cam_wr_data),
        .rd_data_o(cam_reg_rd_data),
        .status_o(cam_status),
        .frame_counter_o(cam_frame_counter),
        .line_counter_o(cam_line_counter),
        .last_pixel_o(cam_last_pixel),
        .error_count_o(cam_error_count),
        .pixel_i(16'd0),
        .valid_i(1'b0),
        .sof_i(1'b0),
        .eol_i(1'b0),
        .cam_reset_o(cam_reset),
        .cam_pwdn_o(cam_pwdn),
        .init_done_o(),
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

    always #10 clk = ~clk;

    function [7:0] checksum;
        input [7:0] b0;
        input [7:0] b1;
        input [7:0] b2;
        input [7:0] b3;
        input [7:0] b4;
        begin
            checksum = b0 ^ b1 ^ b2 ^ b3 ^ b4;
        end
    endfunction

    task uart_send_byte;
        input [7:0] value;
        integer i;
        begin
            uart_rx = 1'b0;
            #(BIT_NS);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = value[i];
                #(BIT_NS);
            end
            uart_rx = 1'b1;
            #(BIT_NS);
        end
    endtask

    task uart_recv_byte;
        output [7:0] value;
        integer wait_count;
        begin
            value = 8'd0;
            wait_count = 0;
            while (!host_rx_valid) begin
                @(posedge clk);
                wait_count = wait_count + 1;
                if (wait_count > 200000) begin
                    $fatal(1, "Timed out waiting for UART TX start bit.");
                end
            end
            value = host_rx_byte;
            @(posedge clk);
        end
    endtask

    task wait_uart_tx_idle;
        integer wait_count;
        begin
            wait_count = 0;
            while ((uart_tx !== 1'b1) || u_uart_ctrl.tx_busy || u_uart_ctrl.resp_active) begin
                #(BIT_NS / 10);
                wait_count = wait_count + 1;
                if (wait_count > 40000) begin
                    $fatal(1, "Timed out waiting for UART TX to become idle.");
                end
            end
            #(BIT_NS);
        end
    endtask

    task transact;
        input  [7:0]  cmd_value;
        input  [7:0]  addr_value;
        input  [15:0] data_value;
        output [7:0]  status_value;
        output [15:0] resp_value;
        reg    [7:0]  r0;
        reg    [7:0]  r1;
        reg    [7:0]  r2;
        reg    [7:0]  r3;
        reg    [7:0]  r4;
        reg    [7:0]  r5;
        begin
            wait_uart_tx_idle();
            uart_send_byte(8'h55);
            uart_send_byte(cmd_value);
            uart_send_byte(addr_value);
            uart_send_byte(data_value[15:8]);
            uart_send_byte(data_value[7:0]);
            uart_send_byte(checksum(8'h55, cmd_value, addr_value, data_value[15:8], data_value[7:0]));

            uart_recv_byte(r0);
            uart_recv_byte(r1);
            uart_recv_byte(r2);
            uart_recv_byte(r3);
            uart_recv_byte(r4);
            uart_recv_byte(r5);

            if (r0 != 8'hAA || r2 != addr_value || r5 != checksum(r0, r1, r2, r3, r4)) begin
                $fatal(1, "Invalid UART response frame.");
            end

            status_value = r1;
            resp_value   = {r3, r4};
            wait_uart_tx_idle();
        end
    endtask

    reg [7:0]  status_value;
    reg [15:0] resp_value;
    reg [15:0] poll_status;
    integer    poll_count;

    initial begin
        clk      = 1'b0;
        rst_n    = 1'b0;
        uart_rx  = 1'b1;

        repeat (8) @(posedge clk);
        rst_n = 1'b1;
        repeat (100) @(posedge clk);

        transact(8'h01, `REG_CAM_REG_ADDR, `OV5640_CHIP_ID_HIGH_REG, status_value, resp_value);
        transact(8'h01, `REG_CAM_CMD, `CAM_CMD_READ, status_value, resp_value);

        poll_status = 16'd0;
        poll_count  = 0;
        while (!poll_status[`CAM_STATUS_DONE_BIT]) begin
            transact(8'h02, `REG_CAM_STATUS, 16'd0, status_value, poll_status);
            poll_count = poll_count + 1;
            if (poll_count > 200) begin
                $fatal(1, "Polling cam_status timed out.");
            end
        end

        transact(8'h02, `REG_CAM_RD_DATA, 16'd0, status_value, resp_value);
        if (resp_value != 16'h0056) begin
            $fatal(1, "Expected UART camera readback to return OV5640 high chip ID.");
        end

        transact(8'h01, `REG_CAM_REG_ADDR, `OV5640_CHIP_ID_LOW_REG, status_value, resp_value);
        transact(8'h01, `REG_CAM_CMD, `CAM_CMD_READ, status_value, resp_value);

        poll_status = 16'd0;
        poll_count  = 0;
        while (!poll_status[`CAM_STATUS_DONE_BIT]) begin
            transact(8'h02, `REG_CAM_STATUS, 16'd0, status_value, poll_status);
            poll_count = poll_count + 1;
            if (poll_count > 200) begin
                $fatal(1, "Polling second camera read timed out.");
            end
        end

        transact(8'h02, `REG_CAM_RD_DATA, 16'd0, status_value, resp_value);
        if (resp_value != 16'h0040) begin
            $fatal(1, "Expected UART camera readback to return OV5640 low chip ID.");
        end

        transact(8'h02, `REG_CAM_STATUS, 16'd0, status_value, poll_status);
        if (!poll_status[`CAM_STATUS_SENSOR_PRESENT_BIT]) begin
            $fatal(1, "Expected sensor_present bit after UART-driven probe-id flow.");
        end

        $display("tb_uart_camera_readback: PASS");
        $finish;
    end

endmodule
