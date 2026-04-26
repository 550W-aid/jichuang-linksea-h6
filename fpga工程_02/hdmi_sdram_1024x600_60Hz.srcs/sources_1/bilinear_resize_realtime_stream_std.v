`timescale 1ns / 1ps

module resize_line_buffer_bram #(
    parameter integer DATA_W = 24,
    parameter integer DEPTH  = 1920,
    parameter integer ADDR_W = 11
) (
    input  wire              clk,
    input  wire              wr_en,
    input  wire [ADDR_W-1:0] wr_addr,
    input  wire [DATA_W-1:0] wr_data,
    input  wire [ADDR_W-1:0] rd_addr,
    output wire [DATA_W-1:0] rd_data
);

    altsyncram altsyncram_component (
        .clock0   (clk),
        .wren_a   (wr_en),
        .address_a(wr_addr),
        .data_a   (wr_data),
        .address_b(rd_addr),
        .q_b      (rd_data),
        .aclr0    (1'b0),
        .addressstall_a(1'b0),
        .byteena_a(1'b1),
        .q_a      (),
        .eccstatus()
    );
    defparam
        altsyncram_component.operation_mode = "DUAL_PORT",
        altsyncram_component.width_a = DATA_W,
        altsyncram_component.widthad_a = ADDR_W,
        altsyncram_component.numwords_a = DEPTH,
        altsyncram_component.width_b = DATA_W,
        altsyncram_component.widthad_b = ADDR_W,
        altsyncram_component.numwords_b = DEPTH,
        altsyncram_component.outdata_reg_b = "UNREGISTERED",
        altsyncram_component.address_reg_b = "CLOCK0",
        altsyncram_component.width_byteena_a = 1,
        altsyncram_component.byte_size = 8,
        altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
        altsyncram_component.ram_block_type = "M4K",
        altsyncram_component.device_family = "Stratix",
        altsyncram_component.power_up_uninitialized = "FALSE",
        altsyncram_component.init_file = "UNUSED";

endmodule

module bilinear_resize_realtime_stream_std #(
    parameter integer MAX_LANES  = 1,
    parameter integer IMG_WIDTH  = 1920,
    parameter integer IMG_HEIGHT = 1440,
    parameter integer OUT_WIDTH  = 1280,
    parameter integer OUT_HEIGHT = 960
) (
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    s_valid,
    output wire                    s_ready,
    input  wire [MAX_LANES*24-1:0] s_data,
    input  wire [MAX_LANES-1:0]    s_keep,
    input  wire                    s_sof,
    input  wire                    s_eol,
    input  wire                    s_eof,
    input  wire                    cfg_valid,
    output wire                    cfg_ready,
    input  wire [15:0]             cfg_in_width,
    input  wire [15:0]             cfg_in_height,
    input  wire [15:0]             cfg_out_width,
    input  wire [15:0]             cfg_out_height,
    input  wire [31:0]             cfg_scale_x_fp,
    input  wire [31:0]             cfg_scale_y_fp,
    output wire                    m_valid,
    input  wire                    m_ready,
    output wire [MAX_LANES*24-1:0] m_data,
    output wire [MAX_LANES-1:0]    m_keep,
    output wire                    m_sof,
    output wire                    m_eol,
    output wire                    m_eof
);

    function integer clog2;
        input integer value;
        integer tmp;
        integer bit_idx;
        begin
            tmp = value - 1;
            clog2 = 0;
            for (bit_idx = 0; bit_idx < 32; bit_idx = bit_idx + 1) begin
                if (tmp > 0) begin
                    tmp = tmp >> 1;
                    clog2 = clog2 + 1;
                end
            end
        end
    endfunction

    localparam integer PIX_W = 24;
    localparam integer X_W   = (IMG_WIDTH  <= 1) ? 1 : clog2(IMG_WIDTH);
    localparam integer Y_W   = (IMG_HEIGHT <= 1) ? 1 : clog2(IMG_HEIGHT);
    localparam [31:0] MIN_SCALE_FP = 32'h0001_0000;
    localparam [31:0] DEFAULT_SCALE_X_FP = (OUT_WIDTH  <= 1) ? 32'd0 : (((IMG_WIDTH  - 1) << 16) / (OUT_WIDTH  - 1));
    localparam [31:0] DEFAULT_SCALE_Y_FP = (OUT_HEIGHT <= 1) ? 32'd0 : (((IMG_HEIGHT - 1) << 16) / (OUT_HEIGHT - 1));

    // Signed-off delivery boundary: single-lane board path.
    // MAX_LANES>1 keeps interface compatibility, but only lane 0 is populated
    // in the current timing-closed configuration.
    wire        in_keep_w;
    wire [7:0]  in_r_w;
    wire [7:0]  in_g_w;
    wire [7:0]  in_b_w;
    wire [23:0] in_pixel_w;

    // Input stream tracking.
    reg [X_W-1:0] in_x_q;
    reg [Y_W-1:0] in_y_q;
    reg           write_bank_q;
    reg [23:0]    curr_left_q;
    reg           lb_pending_valid_q;
    reg           lb_pending_write_bank_q;
    reg [15:0]    lb_pending_x_q;
    reg [15:0]    lb_pending_y_q;
    reg [23:0]    lb_pending_rgb_q;
    reg [23:0]    lb_pending_curr_left_q;
    reg [23:0]    lb_pending_prev_left_q;

    // Output sample tracking uses fixed-point accumulators instead of
    // per-sample coordinate multipliers.
    reg [15:0]    out_x_q;
    reg [15:0]    out_y_q;
    reg [31:0]    src_x_fp_q;
    reg [31:0]    src_y_fp_q;
    // Registered source-coordinate decode stage.
    // This breaks the direct timing arc from src_* accumulators into emit/issue payload selection.
    (* DONT_TOUCH = "TRUE" *) reg [15:0]    src_x0_q;
    (* DONT_TOUCH = "TRUE" *) reg [15:0]    src_x1_q;
    (* DONT_TOUCH = "TRUE" *) reg [15:0]    src_y0_q;
    (* DONT_TOUCH = "TRUE" *) reg [15:0]    src_y1_q;
    (* DONT_TOUCH = "TRUE" *) reg [7:0]     src_fx_q;
    (* DONT_TOUCH = "TRUE" *) reg [7:0]     src_fy_q;

    // Runtime configuration is frame-latched at SOF.
    reg [15:0]    active_in_width_q;
    reg [15:0]    active_in_height_q;
    reg [15:0]    active_out_width_q;
    reg [15:0]    active_out_height_q;
    reg [15:0]    pending_in_width_q;
    reg [15:0]    pending_in_height_q;
    reg [31:0]    active_scale_x_fp_q;
    reg [31:0]    active_scale_y_fp_q;
    reg [15:0]    pending_out_width_q;
    reg [15:0]    pending_out_height_q;
    reg [31:0]    pending_scale_x_fp_q;
    reg [31:0]    pending_scale_y_fp_q;
    reg           pending_cfg_valid_q;

    // One-cycle capture stage after the line-buffer read.
    reg           sample_valid_q;
    reg [15:0]    sample_x_q;
    reg [15:0]    sample_y_q;
    reg [23:0]    sample_rgb_q;
    reg [23:0]    sample_prev_row_q;
    reg [23:0]    sample_curr_left_q;
    reg [23:0]    sample_prev_left_q;

    // Bilinear core input staging.
    reg           emit_valid_w;
    reg [23:0]    emit_p00_w;
    reg [23:0]    emit_p01_w;
    reg [23:0]    emit_p10_w;
    reg [23:0]    emit_p11_w;
    reg           emit_sof_w;
    reg           emit_eol_w;
    reg           emit_eof_w;
    reg [15:0]    next_out_x_w;
    reg [15:0]    next_out_y_w;
    reg [31:0]    next_src_x_fp_w;
    reg [31:0]    next_src_y_fp_w;
    reg           issue_valid_q;
    reg [23:0]    issue_p00_q;
    reg [23:0]    issue_p01_q;
    reg [23:0]    issue_p10_q;
    reg [23:0]    issue_p11_q;
    reg [7:0]     issue_fx_q;
    reg [7:0]     issue_fy_q;
    reg           issue_sof_q;
    reg           issue_eol_q;
    reg           issue_eof_q;
    reg [15:0]    issue_next_out_x_q;
    reg [15:0]    issue_next_out_y_q;
    reg [31:0]    issue_next_src_x_fp_q;
    reg [31:0]    issue_next_src_y_fp_q;

    wire        pipe_ce;
    wire        s_fire;
    wire [15:0] cfg_in_width_sanitized_w;
    wire [15:0] cfg_in_height_sanitized_w;
    wire [15:0] cfg_out_width_sanitized_w;
    wire [15:0] cfg_out_height_sanitized_w;
    wire [31:0] cfg_scale_x_sanitized_w;
    wire [31:0] cfg_scale_y_sanitized_w;
    wire [15:0] curr_src_x0_w;
    wire [15:0] curr_src_x1_w;
    wire [15:0] curr_src_y0_w;
    wire [15:0] curr_src_y1_w;
    wire [7:0]  curr_fx_w;
    wire [7:0]  curr_fy_w;
    wire [15:0] eval_out_x_w;
    wire [15:0] eval_out_y_w;
    wire [31:0] eval_src_x_fp_w;
    wire [31:0] eval_src_y_fp_w;
    wire [15:0] eval_src_x0_w;
    wire [15:0] eval_src_x1_w;
    wire [15:0] eval_src_y0_w;
    wire [15:0] eval_src_y1_w;
    wire [7:0]  eval_fx_w;
    wire [7:0]  eval_fy_w;
    wire [23:0] line_mem0_q_w;
    wire [23:0] line_mem1_q_w;
    wire [23:0] prev_row_data_w;
    wire        line_mem0_wr_en_w;
    wire        line_mem1_wr_en_w;
    wire        interp_valid_w;
    wire [23:0] interp_rgb_w;
    wire        interp_sof_w;
    wire        interp_eol_w;
    wire        interp_eof_w;
    wire [15:0] input_x_w;
    wire [15:0] input_y_w;

    assign in_keep_w  = s_keep[0];
    assign in_r_w     = s_data[23:16];
    assign in_g_w     = s_data[15:8];
    assign in_b_w     = s_data[7:0];
    assign in_pixel_w = {in_r_w, in_g_w, in_b_w};

    assign cfg_in_width_sanitized_w   = (cfg_in_width   < 16'd1) ? 16'd1 :
                                        ((cfg_in_width   > IMG_WIDTH)  ? IMG_WIDTH[15:0]  : cfg_in_width);
    assign cfg_in_height_sanitized_w  = (cfg_in_height  < 16'd1) ? 16'd1 :
                                        ((cfg_in_height  > IMG_HEIGHT) ? IMG_HEIGHT[15:0] : cfg_in_height);
    assign cfg_out_width_sanitized_w  = (cfg_out_width  < 16'd1) ? 16'd1 :
                                        ((cfg_out_width  > OUT_WIDTH)  ? OUT_WIDTH[15:0]  : cfg_out_width);
    assign cfg_out_height_sanitized_w = (cfg_out_height < 16'd1) ? 16'd1 :
                                        ((cfg_out_height > OUT_HEIGHT) ? OUT_HEIGHT[15:0] : cfg_out_height);
    assign cfg_scale_x_sanitized_w    = (cfg_scale_x_fp == 32'd0) ? DEFAULT_SCALE_X_FP :
                                        ((cfg_scale_x_fp < MIN_SCALE_FP) ? MIN_SCALE_FP : cfg_scale_x_fp);
    assign cfg_scale_y_sanitized_w    = (cfg_scale_y_fp == 32'd0) ? DEFAULT_SCALE_Y_FP :
                                        ((cfg_scale_y_fp < MIN_SCALE_FP) ? MIN_SCALE_FP : cfg_scale_y_fp);

    assign curr_src_x0_w = src_x0_q;
    assign curr_src_y0_w = src_y0_q;
    assign curr_src_x1_w = src_x1_q;
    assign curr_src_y1_w = src_y1_q;
    assign curr_fx_w     = src_fx_q;
    assign curr_fy_w     = src_fy_q;
    assign eval_out_x_w   = issue_valid_q ? issue_next_out_x_q    : out_x_q;
    assign eval_out_y_w   = issue_valid_q ? issue_next_out_y_q    : out_y_q;
    assign eval_src_x_fp_w= issue_valid_q ? issue_next_src_x_fp_q : src_x_fp_q;
    assign eval_src_y_fp_w= issue_valid_q ? issue_next_src_y_fp_q : src_y_fp_q;
    assign eval_src_x0_w  = issue_valid_q ? issue_next_src_x_fp_q[31:16] : curr_src_x0_w;
    assign eval_src_y0_w  = issue_valid_q ? issue_next_src_y_fp_q[31:16] : curr_src_y0_w;
    assign eval_fx_w      = issue_valid_q ? issue_next_src_x_fp_q[15:8]  : curr_fx_w;
    assign eval_fy_w      = issue_valid_q ? issue_next_src_y_fp_q[15:8]  : curr_fy_w;
    assign eval_src_x1_w  = (eval_src_x0_w >= (active_in_width_q - 16'd1))  ? (active_in_width_q - 16'd1)  : (eval_src_x0_w + 16'd1);
    assign eval_src_y1_w  = (eval_src_y0_w >= (active_in_height_q - 16'd1)) ? (active_in_height_q - 16'd1) : (eval_src_y0_w + 16'd1);
    assign prev_row_data_w  = lb_pending_write_bank_q ? line_mem0_q_w : line_mem1_q_w;
    assign line_mem0_wr_en_w = s_fire && ~write_bank_q;
    assign line_mem1_wr_en_w = s_fire &&  write_bank_q;

    assign pipe_ce   = (~interp_valid_w) | m_ready;
    assign s_ready   = pipe_ce;
    assign s_fire    = s_valid && s_ready && in_keep_w;
    assign cfg_ready = 1'b1;
    assign input_x_w = s_sof ? 16'd0 : in_x_q;
    assign input_y_w = s_sof ? 16'd0 : in_y_q;

    assign m_valid = interp_valid_w;
    assign m_sof   = interp_sof_w;
    assign m_eol   = interp_eol_w;
    assign m_eof   = interp_eof_w;

    generate
        if (MAX_LANES == 1) begin : g_single_lane_output
            assign m_data = interp_rgb_w;
            assign m_keep = interp_valid_w;
        end else begin : g_multi_lane_output
            assign m_data = {{(MAX_LANES-1)*PIX_W{1'b0}}, interp_rgb_w};
            assign m_keep = interp_valid_w ? {{(MAX_LANES-1){1'b0}}, 1'b1} : {MAX_LANES{1'b0}};
        end
    endgenerate

    bilinear_rgb888_pipe u_bilinear_rgb888_pipe (
        .clk    (clk),
        .rst_n  (rst_n),
        .ce     (pipe_ce),
        .i_valid(issue_valid_q),
        .i_p00  (issue_p00_q),
        .i_p01  (issue_p01_q),
        .i_p10  (issue_p10_q),
        .i_p11  (issue_p11_q),
        .i_fx   (issue_fx_q),
        .i_fy   (issue_fy_q),
        .i_sof  (issue_sof_q),
        .i_eol  (issue_eol_q),
        .i_eof  (issue_eof_q),
        .o_valid(interp_valid_w),
        .o_pixel(interp_rgb_w),
        .o_sof  (interp_sof_w),
        .o_eol  (interp_eol_w),
        .o_eof  (interp_eof_w)
    );

    resize_line_buffer_bram #(
        .DATA_W (24),
        .DEPTH  (IMG_WIDTH),
        .ADDR_W (X_W)
    ) u_line_mem0 (
        .clk    (clk),
        .wr_en  (line_mem0_wr_en_w),
        .wr_addr(input_x_w[X_W-1:0]),
        .wr_data(in_pixel_w),
        .rd_addr(input_x_w[X_W-1:0]),
        .rd_data(line_mem0_q_w)
    );

    resize_line_buffer_bram #(
        .DATA_W (24),
        .DEPTH  (IMG_WIDTH),
        .ADDR_W (X_W)
    ) u_line_mem1 (
        .clk    (clk),
        .wr_en  (line_mem1_wr_en_w),
        .wr_addr(input_x_w[X_W-1:0]),
        .wr_data(in_pixel_w),
        .rd_addr(input_x_w[X_W-1:0]),
        .rd_data(line_mem1_q_w)
    );

    // Decide whether the captured input pixel completes the next pending output sample.
    always @* begin
        emit_valid_w    = 1'b0;
        emit_p00_w      = 24'd0;
        emit_p01_w      = 24'd0;
        emit_p10_w      = 24'd0;
        emit_p11_w      = 24'd0;
        emit_sof_w      = 1'b0;
        emit_eol_w      = 1'b0;
        emit_eof_w      = 1'b0;
        next_out_x_w    = out_x_q;
        next_out_y_w    = out_y_q;
        next_src_x_fp_w = src_x_fp_q;
        next_src_y_fp_w = src_y_fp_q;

        if (sample_valid_q &&
            (eval_out_x_w < active_out_width_q) &&
            (eval_out_y_w < active_out_height_q) &&
            (sample_x_q == eval_src_x1_w) &&
            (sample_y_q == eval_src_y1_w)) begin

            emit_valid_w = 1'b1;
            emit_p11_w   = sample_rgb_q;
            emit_p10_w   = (eval_src_x0_w == sample_x_q) ? sample_rgb_q : sample_curr_left_q;

            if (eval_src_y0_w == sample_y_q) begin
                emit_p01_w = sample_rgb_q;
                emit_p00_w = (eval_src_x0_w == sample_x_q) ? sample_rgb_q : sample_curr_left_q;
            end else begin
                emit_p01_w = sample_prev_row_q;
                emit_p00_w = (eval_src_x0_w == sample_x_q) ? sample_prev_row_q : sample_prev_left_q;
            end

            emit_sof_w = (eval_out_x_w == 0) && (eval_out_y_w == 0);
            emit_eol_w = (eval_out_x_w == (active_out_width_q - 1'b1));
            emit_eof_w = emit_eol_w && (eval_out_y_w == (active_out_height_q - 1'b1));

            if (eval_out_x_w == (active_out_width_q - 1'b1)) begin
                next_out_x_w    = 16'd0;
                next_out_y_w    = eval_out_y_w + 16'd1;
                next_src_x_fp_w = 32'd0;
                next_src_y_fp_w = eval_src_y_fp_w + active_scale_y_fp_q;
            end else begin
                next_out_x_w    = eval_out_x_w + 16'd1;
                next_out_y_w    = eval_out_y_w;
                next_src_x_fp_w = eval_src_x_fp_w + active_scale_x_fp_q;
                next_src_y_fp_w = eval_src_y_fp_w;
            end
        end
    end

    // Update stream position, active config, and next pending output sample state.
    always @(posedge clk) begin
        if (!rst_n) begin
            in_x_q <= {X_W{1'b0}};
            in_y_q <= {Y_W{1'b0}};
            write_bank_q <= 1'b0;
            curr_left_q <= 24'd0;
            lb_pending_valid_q <= 1'b0;
            lb_pending_write_bank_q <= 1'b0;
            lb_pending_x_q <= 16'd0;
            lb_pending_y_q <= 16'd0;
            lb_pending_rgb_q <= 24'd0;
            lb_pending_curr_left_q <= 24'd0;
            lb_pending_prev_left_q <= 24'd0;
            out_x_q <= 16'd0;
            out_y_q <= 16'd0;
            src_x_fp_q <= 32'd0;
            src_y_fp_q <= 32'd0;
            src_x0_q <= 16'd0;
            src_x1_q <= 16'd0;
            src_y0_q <= 16'd0;
            src_y1_q <= 16'd0;
            src_fx_q <= 8'd0;
            src_fy_q <= 8'd0;
            active_in_width_q   <= IMG_WIDTH[15:0];
            active_in_height_q  <= IMG_HEIGHT[15:0];
            active_out_width_q  <= OUT_WIDTH[15:0];
            active_out_height_q <= OUT_HEIGHT[15:0];
            pending_in_width_q   <= IMG_WIDTH[15:0];
            pending_in_height_q  <= IMG_HEIGHT[15:0];
            active_scale_x_fp_q <= DEFAULT_SCALE_X_FP;
            active_scale_y_fp_q <= DEFAULT_SCALE_Y_FP;
            pending_out_width_q  <= OUT_WIDTH[15:0];
            pending_out_height_q <= OUT_HEIGHT[15:0];
            pending_scale_x_fp_q <= DEFAULT_SCALE_X_FP;
            pending_scale_y_fp_q <= DEFAULT_SCALE_Y_FP;
            pending_cfg_valid_q <= 1'b0;
            sample_valid_q <= 1'b0;
            sample_x_q <= 16'd0;
            sample_y_q <= 16'd0;
            sample_rgb_q <= 24'd0;
            sample_prev_row_q <= 24'd0;
            sample_curr_left_q <= 24'd0;
            sample_prev_left_q <= 24'd0;
            issue_valid_q <= 1'b0;
            issue_p00_q <= 24'd0;
            issue_p01_q <= 24'd0;
            issue_p10_q <= 24'd0;
            issue_p11_q <= 24'd0;
            issue_fx_q <= 8'd0;
            issue_fy_q <= 8'd0;
            issue_sof_q <= 1'b0;
            issue_eol_q <= 1'b0;
            issue_eof_q <= 1'b0;
            issue_next_out_x_q <= 16'd0;
            issue_next_out_y_q <= 16'd0;
            issue_next_src_x_fp_q <= 32'd0;
            issue_next_src_y_fp_q <= 32'd0;
        end else begin
            if (cfg_valid) begin
                pending_in_width_q   <= cfg_in_width_sanitized_w;
                pending_in_height_q  <= cfg_in_height_sanitized_w;
                pending_out_width_q  <= cfg_out_width_sanitized_w;
                pending_out_height_q <= cfg_out_height_sanitized_w;
                pending_scale_x_fp_q <= cfg_scale_x_sanitized_w;
                pending_scale_y_fp_q <= cfg_scale_y_sanitized_w;
                pending_cfg_valid_q  <= 1'b1;
            end

            if (pipe_ce) begin
                sample_valid_q <= 1'b0;
                issue_valid_q  <= 1'b0;
                lb_pending_valid_q <= 1'b0;

                if (lb_pending_valid_q) begin
                    sample_valid_q <= 1'b1;
                    sample_x_q <= lb_pending_x_q;
                    sample_y_q <= lb_pending_y_q;
                    sample_rgb_q <= lb_pending_rgb_q;
                    sample_prev_row_q <= (lb_pending_y_q == 16'd0) ? 24'd0 : prev_row_data_w;
                    sample_curr_left_q <= lb_pending_curr_left_q;
                    sample_prev_left_q <= (lb_pending_y_q == 16'd0) ? 24'd0 : lb_pending_prev_left_q;
                end

                if (issue_valid_q) begin
                    out_x_q    <= issue_next_out_x_q;
                    out_y_q    <= issue_next_out_y_q;
                    src_x_fp_q <= issue_next_src_x_fp_q;
                    src_y_fp_q <= issue_next_src_y_fp_q;
                    src_x0_q   <= issue_next_src_x_fp_q[31:16];
                    src_y0_q   <= issue_next_src_y_fp_q[31:16];
                    src_fx_q   <= issue_next_src_x_fp_q[15:8];
                    src_fy_q   <= issue_next_src_y_fp_q[15:8];
                    if (issue_next_src_x_fp_q[31:16] >= (active_in_width_q - 16'd1)) begin
                        src_x1_q <= (active_in_width_q - 16'd1);
                    end else begin
                        src_x1_q <= issue_next_src_x_fp_q[31:16] + 16'd1;
                    end
                    if (issue_next_src_y_fp_q[31:16] >= (active_in_height_q - 16'd1)) begin
                        src_y1_q <= (active_in_height_q - 16'd1);
                    end else begin
                        src_y1_q <= issue_next_src_y_fp_q[31:16] + 16'd1;
                    end
                end

                if (emit_valid_w) begin
                    issue_valid_q <= 1'b1;
                    issue_p00_q <= emit_p00_w;
                    issue_p01_q <= emit_p01_w;
                    issue_p10_q <= emit_p10_w;
                    issue_p11_q <= emit_p11_w;
                    issue_fx_q <= src_fx_q;
                    issue_fy_q <= src_fy_q;
                    issue_sof_q <= emit_sof_w;
                    issue_eol_q <= emit_eol_w;
                    issue_eof_q <= emit_eof_w;
                    issue_next_out_x_q <= next_out_x_w;
                    issue_next_out_y_q <= next_out_y_w;
                    issue_next_src_x_fp_q <= next_src_x_fp_w;
                    issue_next_src_y_fp_q <= next_src_y_fp_w;
                end

                if (s_fire) begin
                    if (s_sof) begin
                        in_x_q <= {X_W{1'b0}};
                        in_y_q <= {Y_W{1'b0}};
                        write_bank_q <= 1'b0;
                        curr_left_q <= 24'd0;
                        out_x_q <= 16'd0;
                        out_y_q <= 16'd0;
                        src_x_fp_q <= 32'd0;
                        src_y_fp_q <= 32'd0;
                        src_x0_q <= 16'd0;
                        src_x1_q <= 16'd0;
                        src_y0_q <= 16'd0;
                        src_y1_q <= 16'd0;
                        src_fx_q <= 8'd0;
                        src_fy_q <= 8'd0;
                        issue_valid_q <= 1'b0;

                        if (pending_cfg_valid_q) begin
                            active_in_width_q   <= pending_in_width_q;
                            active_in_height_q  <= pending_in_height_q;
                            active_out_width_q  <= pending_out_width_q;
                            active_out_height_q <= pending_out_height_q;
                            active_scale_x_fp_q <= pending_scale_x_fp_q;
                            active_scale_y_fp_q <= pending_scale_y_fp_q;
                            pending_cfg_valid_q <= 1'b0;
                        end
                    end

                    lb_pending_valid_q <= 1'b1;
                    lb_pending_write_bank_q <= write_bank_q;
                    lb_pending_x_q <= input_x_w;
                    lb_pending_y_q <= input_y_w;
                    lb_pending_rgb_q <= in_pixel_w;
                    lb_pending_curr_left_q <= (input_x_w == 16'd0) ? 24'd0 : curr_left_q;
                    lb_pending_prev_left_q <= ((input_x_w == 16'd0) || (input_y_w == 16'd0)) ? 24'd0 : prev_row_data_w;

                    curr_left_q <= in_pixel_w;

                    if (s_eol) begin
                        in_x_q <= {X_W{1'b0}};
                        in_y_q <= in_y_q + 1'b1;
                        write_bank_q <= ~write_bank_q;
                        curr_left_q <= 24'd0;
                    end else begin
                        in_x_q <= input_x_w[X_W-1:0] + 1'b1;
                    end

                    if (s_eof) begin
                        in_x_q <= {X_W{1'b0}};
                        in_y_q <= {Y_W{1'b0}};
                        write_bank_q <= 1'b0;
                        curr_left_q <= 24'd0;
                    end
                end
            end
        end
    end

endmodule
