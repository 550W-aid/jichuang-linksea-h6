module resize_letterbox_stream #(
    parameter integer OUT_WIDTH  = 1024,
    parameter integer OUT_HEIGHT = 600
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_start_i,
    input  wire [12:0] active_width_i,
    input  wire [11:0] active_height_i,
    input  wire [10:0] offset_x_i,
    input  wire [10:0] offset_y_i,
    input  wire        s_valid_i,
    input  wire [23:0] s_data_i,
    input  wire        s_eol_i,
    output reg         m_valid_o,
    output reg [23:0]  m_data_o,
    output reg         m_sof_o,
    output reg         m_eol_o,
    output reg         m_eof_o
);

    function integer clog2;
        input integer value;
        integer tmp;
        integer bit_idx;
        begin
            tmp = value - 1;
            clog2 = 0;
            for (bit_idx = 0; tmp > 0; bit_idx = bit_idx + 1) begin
                tmp = tmp >> 1;
                clog2 = bit_idx + 1;
            end
        end
    endfunction

    localparam [23:0] BLACK_RGB = 24'h000000;
    localparam integer ADDR_W = clog2(OUT_WIDTH);

    reg [12:0] active_width_q;
    reg [11:0] active_height_q;
    reg [10:0] offset_x_q;
    reg [10:0] offset_y_q;

    reg        cap_buf_sel_q;
    reg [12:0] cap_x_q;
    reg        line_ready0_q;
    reg        line_ready1_q;

    reg        emit_frame_active_q;
    reg        emit_buf_sel_q;
    reg [10:0] emit_x_q;
    reg [10:0] emit_y_q;

    wire [11:0] active_end_y_w;
    wire [10:0] active_end_x_w;
    wire        emit_y_active_w;
    wire        emit_x_active_w;
    wire        emit_line_ready_w;
    wire [12:0] active_buf_x_w;
    wire [23:0] active_buf_pixel_w;
    wire [23:0] line_buf0_rd_w;
    wire [23:0] line_buf1_rd_w;
    wire        emit_can_advance_w;
    wire        emit_last_pixel_w;
    wire        emit_last_line_w;
    wire        line_buf0_wr_en_w;
    wire        line_buf1_wr_en_w;

    assign line_buf0_wr_en_w = s_valid_i && ~cap_buf_sel_q;
    assign line_buf1_wr_en_w = s_valid_i &&  cap_buf_sel_q;

    assign active_end_x_w   = offset_x_q + active_width_q[10:0];
    assign active_end_y_w   = offset_y_q + active_height_q[10:0];
    assign emit_y_active_w  = (emit_y_q >= offset_y_q) && (emit_y_q < active_end_y_w);
    assign emit_x_active_w  = (emit_x_q >= offset_x_q) && (emit_x_q < active_end_x_w);
    assign emit_line_ready_w = emit_buf_sel_q ? line_ready1_q : line_ready0_q;
    assign active_buf_x_w   = emit_x_q - offset_x_q;
    assign active_buf_pixel_w = emit_buf_sel_q ? line_buf1_rd_w : line_buf0_rd_w;
    assign emit_can_advance_w = emit_frame_active_q &&
                                (!emit_y_active_w || (emit_x_q < offset_x_q) || emit_line_ready_w);
    assign emit_last_pixel_w = (emit_x_q == (OUT_WIDTH - 1));
    assign emit_last_line_w  = (emit_y_q == (OUT_HEIGHT - 1));

    resize_line_buffer_bram #(
        .DATA_W (24),
        .DEPTH  (OUT_WIDTH),
        .ADDR_W (ADDR_W)
    ) u_line_buf0 (
        .clk    (clk),
        .wr_en  (line_buf0_wr_en_w),
        .wr_addr(cap_x_q[ADDR_W-1:0]),
        .wr_data(s_data_i),
        .rd_addr(active_buf_x_w[ADDR_W-1:0]),
        .rd_data(line_buf0_rd_w)
    );

    resize_line_buffer_bram #(
        .DATA_W (24),
        .DEPTH  (OUT_WIDTH),
        .ADDR_W (ADDR_W)
    ) u_line_buf1 (
        .clk    (clk),
        .wr_en  (line_buf1_wr_en_w),
        .wr_addr(cap_x_q[ADDR_W-1:0]),
        .wr_data(s_data_i),
        .rd_addr(active_buf_x_w[ADDR_W-1:0]),
        .rd_data(line_buf1_rd_w)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_width_q      <= OUT_WIDTH[12:0];
            active_height_q     <= OUT_HEIGHT[11:0];
            offset_x_q          <= 11'd0;
            offset_y_q          <= 11'd0;
            cap_buf_sel_q       <= 1'b0;
            cap_x_q             <= 13'd0;
            line_ready0_q       <= 1'b0;
            line_ready1_q       <= 1'b0;
            emit_frame_active_q <= 1'b0;
            emit_buf_sel_q      <= 1'b0;
            emit_x_q            <= 11'd0;
            emit_y_q            <= 11'd0;
            m_valid_o           <= 1'b0;
            m_data_o            <= BLACK_RGB;
            m_sof_o             <= 1'b0;
            m_eol_o             <= 1'b0;
            m_eof_o             <= 1'b0;
        end else begin
            m_valid_o <= 1'b0;
            m_data_o  <= BLACK_RGB;
            m_sof_o   <= 1'b0;
            m_eol_o   <= 1'b0;
            m_eof_o   <= 1'b0;

            if (frame_start_i) begin
                active_width_q      <= active_width_i;
                active_height_q     <= active_height_i;
                offset_x_q          <= offset_x_i;
                offset_y_q          <= offset_y_i;
                cap_buf_sel_q       <= 1'b0;
                cap_x_q             <= 13'd0;
                line_ready0_q       <= 1'b0;
                line_ready1_q       <= 1'b0;
                emit_frame_active_q <= 1'b1;
                emit_buf_sel_q      <= 1'b0;
                emit_x_q            <= 11'd0;
                emit_y_q            <= 11'd0;
            end else begin
                if (s_valid_i) begin
                    if (s_eol_i) begin
                        if (cap_buf_sel_q) begin
                            line_ready1_q <= 1'b1;
                        end else begin
                            line_ready0_q <= 1'b1;
                        end
                        cap_buf_sel_q <= ~cap_buf_sel_q;
                        cap_x_q       <= 13'd0;
                    end else begin
                        cap_x_q <= cap_x_q + 13'd1;
                    end
                end

                if (emit_can_advance_w) begin
                    m_valid_o <= 1'b1;
                    m_sof_o   <= (emit_x_q == 11'd0) && (emit_y_q == 11'd0);
                    m_eol_o   <= emit_last_pixel_w;
                    m_eof_o   <= emit_last_pixel_w && emit_last_line_w;

                    if (emit_y_active_w && emit_x_active_w) begin
                        m_data_o <= active_buf_pixel_w;
                    end else begin
                        m_data_o <= BLACK_RGB;
                    end

                    if (emit_last_pixel_w) begin
                        emit_x_q <= 11'd0;

                        if (emit_y_active_w && emit_line_ready_w) begin
                            if (emit_buf_sel_q) begin
                                line_ready1_q <= 1'b0;
                            end else begin
                                line_ready0_q <= 1'b0;
                            end
                            emit_buf_sel_q <= ~emit_buf_sel_q;
                        end

                        if (emit_last_line_w) begin
                            emit_y_q            <= 11'd0;
                            emit_frame_active_q <= 1'b0;
                        end else begin
                            emit_y_q <= emit_y_q + 11'd1;
                        end
                    end else begin
                        emit_x_q <= emit_x_q + 11'd1;
                    end
                end
            end
        end
    end

endmodule
