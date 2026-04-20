module sii9134_ctrl #
(
    parameter integer CLK_HZ                = 50_000_000,
    parameter integer I2C_HZ                = 100_000,
    parameter integer POWERUP_DELAY_CYCLES  = 100_000,
    parameter integer RESET_HOLD_CYCLES     = 100_000,
    parameter integer POST_RESET_DELAY_CYCLES = 200_000
)
(
    input  wire clk,
    input  wire rst_n,
    output reg  hdmi_reset_n_o,
    output wire i2c_scl_o,
    output wire i2c_sda_oe_o,
    input  wire i2c_sda_i,
    output wire init_done_o,
    output wire init_error_o,
    output wire [7:0] debug_error_index_o,
    output wire debug_error_use_tpi_o,
    output wire debug_error_timeout_o
);

    localparam [6:0] DEV_ADDR_MAIN_LO = 7'h39; // 0x72 write / 0x73 read
    localparam [6:0] DEV_ADDR_MAIN_HI = 7'h3B; // 0x76 write / 0x77 read
    localparam [6:0] DEV_ADDR_SEC_LO  = 7'h3D; // 0x7A write / 0x7B read
    localparam [6:0] DEV_ADDR_SEC_HI  = 7'h3F; // 0x7E write / 0x7F read

    localparam [2:0] ST_POWERUP    = 3'd0;
    localparam [2:0] ST_RESET_HOLD = 3'd1;
    localparam [2:0] ST_POST_RESET = 3'd2;
    localparam [2:0] ST_START      = 3'd3;
    localparam [2:0] ST_WAIT       = 3'd4;
    localparam [2:0] ST_DELAY      = 3'd5;
    localparam [2:0] ST_DONE       = 3'd6;
    localparam [2:0] ST_ERROR      = 3'd7;

    localparam integer WAIT_CYCLES_PER_MS = ((CLK_HZ / 1000) > 0) ? (CLK_HZ / 1000) : 1;
    localparam [7:0] INIT_TABLE_LAST = 8'd43;

    reg [2:0]  state_r;
    reg [31:0] delay_count_r;
    reg [7:0]  init_index_r;
    reg        master_start_r;
    reg [15:0] reg_addr_r;
    reg [7:0]  wr_data_r;
    reg        use_tpi_r;
    reg [31:0] init_entry_word_r;
    reg [7:0]  error_index_r;
    reg        error_use_tpi_r;
    reg        error_timeout_r;
    reg        addr_sel_r;
    reg        addr_locked_r;
    reg        addr_retry_r;

    wire       main_done_w;
    wire       main_ack_ok_w;
    wire       main_nack_w;
    wire       main_timeout_w;
    wire       main_scl_w;
    wire       main_sda_oe_w;

    wire       main_hi_done_w;
    wire       main_hi_ack_ok_w;
    wire       main_hi_nack_w;
    wire       main_hi_timeout_w;
    wire       main_hi_scl_w;
    wire       main_hi_sda_oe_w;

    wire       sec_lo_done_w;
    wire       sec_lo_ack_ok_w;
    wire       sec_lo_nack_w;
    wire       sec_lo_timeout_w;
    wire       sec_lo_scl_w;
    wire       sec_lo_sda_oe_w;

    wire       sec_hi_done_w;
    wire       sec_hi_ack_ok_w;
    wire       sec_hi_nack_w;
    wire       sec_hi_timeout_w;
    wire       sec_hi_scl_w;
    wire       sec_hi_sda_oe_w;

    wire active_done_w    = use_tpi_r ? (addr_sel_r ? sec_hi_done_w    : sec_lo_done_w)    : (addr_sel_r ? main_hi_done_w    : main_done_w);
    wire active_ack_ok_w  = use_tpi_r ? (addr_sel_r ? sec_hi_ack_ok_w  : sec_lo_ack_ok_w)  : (addr_sel_r ? main_hi_ack_ok_w  : main_ack_ok_w);
    wire active_nack_w    = use_tpi_r ? (addr_sel_r ? sec_hi_nack_w    : sec_lo_nack_w)    : (addr_sel_r ? main_hi_nack_w    : main_nack_w);
    wire active_timeout_w = use_tpi_r ? (addr_sel_r ? sec_hi_timeout_w : sec_lo_timeout_w) : (addr_sel_r ? main_hi_timeout_w : main_timeout_w);

    function [31:0] init_entry;
        input [7:0] index;
        begin
            case (index)
                // Main-page register writes follow the documented separate-sync
                // RGB888 flow. For 640x480 we must reprogram the DE generator
                // using the real HS/VS back-porch offsets rather than reusing
                // the 720p defaults.
                8'd0:  init_entry = {1'b0, 7'd1, 8'h05, 8'h01, 8'h00};
                8'd1:  init_entry = {1'b0, 7'd5, 8'h05, 8'h00, 8'h00};
                8'd2:  init_entry = {1'b0, 7'd1, 8'h08, 8'h37, 8'h00};
                8'd3:  init_entry = {1'b0, 7'd0, 8'h0C, 8'h00, 8'h00};
                8'd4:  init_entry = {1'b0, 7'd0, 8'h0D, 8'h01, 8'h00};
                8'd5:  init_entry = {1'b0, 7'd0, 8'h4B, 8'h00, 8'h00};
                8'd6:  init_entry = {1'b0, 7'd0, 8'h4C, 8'h00, 8'h00};
                8'd7:  init_entry = {1'b0, 7'd0, 8'h4D, 8'hFF, 8'h00};
                8'd8:  init_entry = {1'b0, 7'd0, 8'h82, 8'h25, 8'h00};
                8'd9:  init_entry = {1'b0, 7'd0, 8'h83, 8'h19, 8'h00};
                8'd10: init_entry = {1'b0, 7'd0, 8'h84, 8'h31, 8'h00};
                8'd11: init_entry = {1'b0, 7'd0, 8'h85, 8'h01, 8'h00};
                8'd12: init_entry = {1'b0, 7'd0, 8'h32, 8'h90, 8'h00};
                8'd13: init_entry = {1'b0, 7'd0, 8'h33, 8'h70, 8'h00};
                8'd14: init_entry = {1'b0, 7'd0, 8'h34, 8'h23, 8'h00};
                8'd15: init_entry = {1'b0, 7'd0, 8'h36, 8'h80, 8'h00};
                8'd16: init_entry = {1'b0, 7'd0, 8'h37, 8'h02, 8'h00};
                8'd17: init_entry = {1'b0, 7'd0, 8'h38, 8'hE0, 8'h00};
                8'd18: init_entry = {1'b0, 7'd0, 8'h39, 8'h01, 8'h00};

                // Page-1 / TPI-side writes: keep the conservative enable path,
                // but avoid the 720p-specific AVI payload block that is a poor
                // fit for our 640x480 smoke test.
                8'd19: init_entry = {1'b1, 7'd0, 8'h01, 8'h02, 8'h00};
                8'd20: init_entry = {1'b1, 7'd0, 8'h02, 8'h01, 8'h00};
                8'd21: init_entry = {1'b1, 7'd0, 8'h03, 8'h00, 8'h00};
                8'd22: init_entry = {1'b1, 7'd0, 8'h04, 8'h18, 8'h00};
                8'd23: init_entry = {1'b1, 7'd0, 8'h05, 8'h00, 8'h00};
                8'd24: init_entry = {1'b1, 7'd0, 8'h14, 8'h11, 8'h00};
                8'd25: init_entry = {1'b1, 7'd0, 8'h1D, 8'h40, 8'h00};
                8'd26: init_entry = {1'b1, 7'd0, 8'h21, 8'h02, 8'h00};
                8'd27: init_entry = {1'b1, 7'd0, 8'h22, 8'h2B, 8'h00};
                8'd28: init_entry = {1'b1, 7'd0, 8'h2F, 8'h01, 8'h00};
                8'd29: init_entry = {1'b1, 7'd0, 8'h80, 8'h84, 8'h00};
                8'd30: init_entry = {1'b1, 7'd0, 8'h81, 8'h01, 8'h00};
                8'd31: init_entry = {1'b1, 7'd0, 8'h82, 8'h0A, 8'h00};
                8'd32: init_entry = {1'b1, 7'd0, 8'h83, 8'h70, 8'h00};
                8'd33: init_entry = {1'b1, 7'd0, 8'h84, 8'h01, 8'h00};
                8'd34: init_entry = {1'b1, 7'd0, 8'h85, 8'h00, 8'h00};
                8'd35: init_entry = {1'b1, 7'd0, 8'h86, 8'h00, 8'h00};
                8'd36: init_entry = {1'b1, 7'd0, 8'h87, 8'h00, 8'h00};
                8'd37: init_entry = {1'b1, 7'd0, 8'h88, 8'h00, 8'h00};
                8'd38: init_entry = {1'b1, 7'd0, 8'h89, 8'h00, 8'h00};
                8'd39: init_entry = {1'b1, 7'd0, 8'h8A, 8'h00, 8'h00};
                8'd40: init_entry = {1'b1, 7'd0, 8'h8B, 8'h00, 8'h00};
                8'd41: init_entry = {1'b1, 7'd0, 8'h8C, 8'h00, 8'h00};
                8'd42: init_entry = {1'b1, 7'd0, 8'h8D, 8'h00, 8'h00};
                8'd43: init_entry = {1'b1, 7'd5, 8'h3E, 8'h33, 8'h00};
                default: init_entry = 32'd0;
            endcase
        end
    endfunction

    always @* begin
        init_entry_word_r = init_entry(init_index_r);
    end

    assign i2c_scl_o    = main_scl_w & main_hi_scl_w & sec_lo_scl_w & sec_hi_scl_w;
    assign i2c_sda_oe_o = main_sda_oe_w | main_hi_sda_oe_w | sec_lo_sda_oe_w | sec_hi_sda_oe_w;
    assign init_done_o  = (state_r == ST_DONE);
    assign init_error_o = (state_r == ST_ERROR);
    assign debug_error_index_o   = error_index_r;
    assign debug_error_use_tpi_o = error_use_tpi_r;
    assign debug_error_timeout_o = error_timeout_r;

    sccb_master #(
        .CLK_HZ(CLK_HZ),
        .BUS_HZ(I2C_HZ),
        .SENSOR_ADDR(DEV_ADDR_MAIN_LO),
        .REG_ADDR_BYTES(1)
    ) u_main_master (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(master_start_r && !use_tpi_r && !addr_sel_r),
        .read_i(1'b0),
        .reg_addr_i({8'h00, reg_addr_r[7:0]}),
        .wr_data_i(wr_data_r),
        .rd_data_o(),
        .busy_o(),
        .done_o(main_done_w),
        .ack_ok_o(main_ack_ok_w),
        .nack_o(main_nack_w),
        .timeout_o(main_timeout_w),
        .sccb_scl_o(main_scl_w),
        .sccb_sda_oe_o(main_sda_oe_w),
        .sccb_sda_i(i2c_sda_i)
    );

    sccb_master #(
        .CLK_HZ(CLK_HZ),
        .BUS_HZ(I2C_HZ),
        .SENSOR_ADDR(DEV_ADDR_MAIN_HI),
        .REG_ADDR_BYTES(1)
    ) u_main_hi_master (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(master_start_r && !use_tpi_r && addr_sel_r),
        .read_i(1'b0),
        .reg_addr_i({8'h00, reg_addr_r[7:0]}),
        .wr_data_i(wr_data_r),
        .rd_data_o(),
        .busy_o(),
        .done_o(main_hi_done_w),
        .ack_ok_o(main_hi_ack_ok_w),
        .nack_o(main_hi_nack_w),
        .timeout_o(main_hi_timeout_w),
        .sccb_scl_o(main_hi_scl_w),
        .sccb_sda_oe_o(main_hi_sda_oe_w),
        .sccb_sda_i(i2c_sda_i)
    );

    sccb_master #(
        .CLK_HZ(CLK_HZ),
        .BUS_HZ(I2C_HZ),
        .SENSOR_ADDR(DEV_ADDR_SEC_LO),
        .REG_ADDR_BYTES(1)
    ) u_sec_lo_master (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(master_start_r && use_tpi_r && !addr_sel_r),
        .read_i(1'b0),
        .reg_addr_i({8'h00, reg_addr_r[7:0]}),
        .wr_data_i(wr_data_r),
        .rd_data_o(),
        .busy_o(),
        .done_o(sec_lo_done_w),
        .ack_ok_o(sec_lo_ack_ok_w),
        .nack_o(sec_lo_nack_w),
        .timeout_o(sec_lo_timeout_w),
        .sccb_scl_o(sec_lo_scl_w),
        .sccb_sda_oe_o(sec_lo_sda_oe_w),
        .sccb_sda_i(i2c_sda_i)
    );

    sccb_master #(
        .CLK_HZ(CLK_HZ),
        .BUS_HZ(I2C_HZ),
        .SENSOR_ADDR(DEV_ADDR_SEC_HI),
        .REG_ADDR_BYTES(1)
    ) u_sec_hi_master (
        .clk(clk),
        .rst_n(rst_n),
        .start_i(master_start_r && use_tpi_r && addr_sel_r),
        .read_i(1'b0),
        .reg_addr_i({8'h00, reg_addr_r[7:0]}),
        .wr_data_i(wr_data_r),
        .rd_data_o(),
        .busy_o(),
        .done_o(sec_hi_done_w),
        .ack_ok_o(sec_hi_ack_ok_w),
        .nack_o(sec_hi_nack_w),
        .timeout_o(sec_hi_timeout_w),
        .sccb_scl_o(sec_hi_scl_w),
        .sccb_sda_oe_o(sec_hi_sda_oe_w),
        .sccb_sda_i(i2c_sda_i)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hdmi_reset_n_o <= 1'b0;
            state_r        <= ST_POWERUP;
            delay_count_r  <= 32'd0;
            init_index_r   <= 8'd0;
            master_start_r <= 1'b0;
            reg_addr_r     <= 16'd0;
            wr_data_r      <= 8'd0;
            use_tpi_r      <= 1'b0;
            error_index_r  <= 8'd0;
            error_use_tpi_r <= 1'b0;
            error_timeout_r <= 1'b0;
            addr_sel_r       <= 1'b0;
            addr_locked_r    <= 1'b0;
            addr_retry_r     <= 1'b0;
        end else begin
            master_start_r <= 1'b0;

            case (state_r)
                ST_POWERUP: begin
                    hdmi_reset_n_o <= 1'b0;
                    if (delay_count_r >= POWERUP_DELAY_CYCLES - 1) begin
                        delay_count_r <= 32'd0;
                        state_r       <= ST_RESET_HOLD;
                    end else begin
                        delay_count_r <= delay_count_r + 32'd1;
                    end
                end

                ST_RESET_HOLD: begin
                    hdmi_reset_n_o <= 1'b0;
                    if (delay_count_r >= RESET_HOLD_CYCLES - 1) begin
                        delay_count_r  <= 32'd0;
                        hdmi_reset_n_o <= 1'b1;
                        state_r        <= ST_POST_RESET;
                    end else begin
                        delay_count_r <= delay_count_r + 32'd1;
                    end
                end

                ST_POST_RESET: begin
                    hdmi_reset_n_o <= 1'b1;
                    if (delay_count_r >= POST_RESET_DELAY_CYCLES - 1) begin
                        delay_count_r <= 32'd0;
                        init_index_r  <= 8'd0;
                        state_r       <= ST_START;
                    end else begin
                        delay_count_r <= delay_count_r + 32'd1;
                    end
                end

                ST_START: begin
                    hdmi_reset_n_o <= 1'b1;
                    use_tpi_r      <= init_entry_word_r[31];
                    reg_addr_r     <= {8'h00, init_entry_word_r[23:16]};
                    wr_data_r      <= init_entry_word_r[15:8];
                    master_start_r <= 1'b1;
                    state_r        <= ST_WAIT;
                end

                ST_WAIT: begin
                    hdmi_reset_n_o <= 1'b1;
                    if (active_done_w) begin
                        if (active_ack_ok_w) begin
                            addr_locked_r <= 1'b1;
                            addr_retry_r  <= 1'b0;
                            delay_count_r <= 32'd0;
                            if (init_entry_word_r[30:24] != 7'd0) begin
                                state_r <= ST_DELAY;
                            end else if (init_index_r == INIT_TABLE_LAST) begin
                                state_r <= ST_DONE;
                            end else begin
                                init_index_r <= init_index_r + 8'd1;
                                state_r      <= ST_START;
                            end
                        end else if (active_nack_w || active_timeout_w) begin
                            if (!addr_locked_r && !addr_retry_r) begin
                                addr_sel_r  <= ~addr_sel_r;
                                addr_retry_r <= 1'b1;
                                state_r        <= ST_START;
                            end else begin
                                error_index_r   <= init_index_r;
                                error_use_tpi_r <= use_tpi_r;
                                error_timeout_r <= active_timeout_w;
                                state_r         <= ST_ERROR;
                            end
                        end
                    end
                end

                ST_DELAY: begin
                    hdmi_reset_n_o <= 1'b1;
                    if (delay_count_r >= (init_entry_word_r[30:24] * WAIT_CYCLES_PER_MS) - 1) begin
                        delay_count_r <= 32'd0;
                        if (init_index_r == INIT_TABLE_LAST) begin
                            state_r <= ST_DONE;
                        end else begin
                            init_index_r <= init_index_r + 8'd1;
                            state_r      <= ST_START;
                        end
                    end else begin
                        delay_count_r <= delay_count_r + 32'd1;
                    end
                end

                ST_DONE: begin
                    hdmi_reset_n_o <= 1'b1;
                end

                default: begin
                    hdmi_reset_n_o <= 1'b1;
                    state_r        <= ST_ERROR;
                end
            endcase
        end
    end

endmodule
