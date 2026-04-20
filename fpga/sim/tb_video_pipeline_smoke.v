`timescale 1ns/1ps
`include "fpga/rtl/common/video_regs.vh"

module tb_video_pipeline_smoke;

    localparam integer SYS_CLK_HZ = 50_000_000;
    localparam integer PIX_CLK_HZ = 25_000_000;
    localparam integer BAUD       = 1_000_000;
    localparam integer BIT_NS     = 1_000;

    reg        sys_clk;
    reg        pix_clk;
    reg        cam_pclk;
    reg        rst_n;
    reg        uart_rx;
    reg        cam_vsync;
    reg        cam_href;
    reg [7:0]  cam_data;

    wire       uart_tx;
    wire       cam_xclk;
    wire       cam_scl;
    wire       cam_reset;
    wire       cam_pwdn;
    wire       vga_hsync;
    wire       vga_vsync;
    wire [4:0] vga_r;
    wire [5:0] vga_g;
    wire [4:0] vga_b;
    wire       master_sda_oe;
    wire       slave_sda_oe;
    wire       cam_sda;
    wire [7:0] host_rx_byte;
    wire       host_rx_valid;

    assign cam_sda = (master_sda_oe || slave_sda_oe) ? 1'b0 : 1'b1;

    video_pipeline_top #(
        .SYS_CLK_HZ(SYS_CLK_HZ),
        .PIX_CLK_HZ(PIX_CLK_HZ),
        .UART_BAUD(BAUD)
    ) dut (
        .sys_clk(sys_clk),
        .pix_clk(pix_clk),
        .sys_rst_n(rst_n),
        .uart_rx_i(uart_rx),
        .uart_tx_o(uart_tx),
        .cam_pclk_i(cam_pclk),
        .cam_vsync_i(cam_vsync),
        .cam_href_i(cam_href),
        .cam_data_i(cam_data),
        .cam_xclk_o(cam_xclk),
        .cam_sccb_scl_o(cam_scl),
        .cam_sccb_sda_io(cam_sda),
        .cam_reset_o(cam_reset),
        .cam_pwdn_o(cam_pwdn),
        .vga_hsync_o(vga_hsync),
        .vga_vsync_o(vga_vsync),
        .vga_r_o(vga_r),
        .vga_g_o(vga_g),
        .vga_b_o(vga_b)
    );

    assign master_sda_oe = dut.cam_sccb_sda_oe;

    uart_rx #(
        .CLK_HZ(SYS_CLK_HZ),
        .BAUD(BAUD)
    ) u_host_uart_rx (
        .clk(sys_clk),
        .rst_n(rst_n),
        .rx_i(uart_tx),
        .data_o(host_rx_byte),
        .data_valid_o(host_rx_valid)
    );

    ov5640_sccb_model u_model (
        .rst_n(rst_n),
        .sccb_scl_i(cam_scl),
        .sccb_sda_i(cam_sda),
        .sccb_sda_oe_o(slave_sda_oe),
        .force_nack_i(1'b0),
        .hold_sda_low_i(1'b0)
    );

    always #10 sys_clk = ~sys_clk;
    always #20 pix_clk = ~pix_clk;
    always #20 cam_pclk = ~cam_pclk;

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
                @(posedge sys_clk);
                wait_count = wait_count + 1;
                if (wait_count > 200000) begin
                    $fatal(1, "Timed out waiting for UART TX start bit in video pipeline smoke test.");
                end
            end
            value = host_rx_byte;
            @(posedge sys_clk);
        end
    endtask

    task wait_uart_tx_idle;
        integer wait_count;
        begin
            wait_count = 0;
            while ((uart_tx !== 1'b1) || dut.u_uart_ctrl.tx_busy || dut.u_uart_ctrl.resp_active) begin
                #(BIT_NS / 10);
                wait_count = wait_count + 1;
                if (wait_count > 40000) begin
                    $fatal(1, "Timed out waiting for top-level UART TX to become idle.");
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
                $fatal(1, "Invalid UART response in tb_video_pipeline_smoke.");
            end

            status_value = r1;
            resp_value   = {r3, r4};
            wait_uart_tx_idle();
        end
    endtask

    task send_pixel;
        input [15:0] pixel_value;
        begin
            cam_href = 1'b1;
            cam_data = pixel_value[15:8];
            @(posedge cam_pclk);
            cam_data = pixel_value[7:0];
            @(posedge cam_pclk);
        end
    endtask

    task send_frame;
        begin
            cam_vsync = 1'b1;
            @(posedge cam_pclk);
            cam_vsync = 1'b0;

            send_pixel(16'h1234);
            send_pixel(16'h5678);
            cam_href = 1'b0;
            @(posedge cam_pclk);

            send_pixel(16'h9ABC);
            send_pixel(16'hDEF0);
            cam_href = 1'b0;
            @(posedge cam_pclk);
        end
    endtask

    reg [7:0]  status_value;
    reg [15:0] resp_value;
    reg [15:0] poll_status;
    integer    poll_count;

    initial begin
        sys_clk   = 1'b0;
        pix_clk   = 1'b0;
        cam_pclk  = 1'b0;
        rst_n     = 1'b0;
        uart_rx   = 1'b1;
        cam_vsync = 1'b0;
        cam_href  = 1'b0;
        cam_data  = 8'd0;

        repeat (8) @(posedge sys_clk);
        rst_n = 1'b1;
        repeat (200) @(posedge sys_clk);

        transact(8'h01, `REG_CAM_REG_ADDR, `OV5640_CHIP_ID_HIGH_REG, status_value, resp_value);
        transact(8'h01, `REG_CAM_CMD, `CAM_CMD_READ, status_value, resp_value);

        poll_status = 16'd0;
        poll_count  = 0;
        while (!poll_status[`CAM_STATUS_DONE_BIT]) begin
            transact(8'h02, `REG_CAM_STATUS, 16'd0, status_value, poll_status);
            poll_count = poll_count + 1;
            if (poll_count > 200) begin
                $fatal(1, "Timed out waiting for video_pipeline_top camera status.");
            end
        end

        transact(8'h01, `REG_CAM_REG_ADDR, `OV5640_CHIP_ID_LOW_REG, status_value, resp_value);
        transact(8'h01, `REG_CAM_CMD, `CAM_CMD_READ, status_value, resp_value);

        poll_status = 16'd0;
        poll_count  = 0;
        while (!poll_status[`CAM_STATUS_DONE_BIT]) begin
            transact(8'h02, `REG_CAM_STATUS, 16'd0, status_value, poll_status);
            poll_count = poll_count + 1;
            if (poll_count > 200) begin
                $fatal(1, "Timed out waiting for second top-level camera status.");
            end
        end

        send_frame();
        repeat (20) @(posedge sys_clk);

        transact(8'h02, `REG_CAM_FRAME_COUNT, 16'd0, status_value, resp_value);
        if (resp_value == 16'd0) begin
            $fatal(1, "Expected non-zero frame counter in video_pipeline_top smoke test.");
        end

        transact(8'h02, `REG_CAM_LINE_COUNT, 16'd0, status_value, resp_value);
        if (resp_value < 16'd2) begin
            $fatal(1, "Expected at least two camera lines in video_pipeline_top smoke test.");
        end

        transact(8'h02, `REG_CAM_LAST_PIXEL, 16'd0, status_value, resp_value);
        if (resp_value != 16'hDEF0) begin
            $fatal(1, "Expected last camera pixel register to track the latest DVP pixel.");
        end

        transact(8'h02, `REG_CAM_STATUS, 16'd0, status_value, poll_status);
        if (!poll_status[`CAM_STATUS_DATA_ACTIVE_BIT]) begin
            $fatal(1, "Expected data_active bit in video_pipeline_top smoke test.");
        end

        $display("tb_video_pipeline_smoke: PASS");
        $finish;
    end

endmodule
