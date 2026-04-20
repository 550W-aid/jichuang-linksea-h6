module vga_top(
    input        clk_25m,
    input        rst_n,

    output       vga_clk,
    output       vga_hs,
    output       vga_vs,
    output [7:0] vga_r,
    output [7:0] vga_g,
    output [7:0] vga_b
);

    localparam integer H_FRONT        = 16;
    localparam integer H_SYNC         = 96;
    localparam integer H_BACK         = 48;
    localparam integer H_DISP         = 640;
    localparam integer H_TOTAL        = 800;
    localparam integer V_FRONT        = 10;
    localparam integer V_SYNC         = 2;
    localparam integer V_BACK         = 33;
    localparam integer V_DISP         = 480;
    localparam integer V_TOTAL        = 525;
    localparam integer ACTIVE_X_START = H_SYNC + H_BACK;
    localparam integer ACTIVE_Y_START = V_SYNC + V_BACK;
    localparam integer PIPE_LAT       = H_TOTAL + 4;

    reg  [11:0] src_x;
    reg  [11:0] src_y;
    reg  [PIPE_LAT-1:0] hs_pipe;
    reg  [PIPE_LAT-1:0] vs_pipe;
    reg  [7:0] gauss_gray_hold;

    wire        src_valid;
    wire        src_ready;
    wire [23:0] src_rgb888;
    wire        src_keep;
    wire        src_sof;
    wire        src_eol;
    wire        src_eof;
    wire        src_active;
    wire [11:0] src_active_x;
    wire [11:0] src_active_y;
    wire        src_hs_raw;
    wire        src_vs_raw;

    wire        gray_valid;
    wire        gray_ready;
    wire [7:0]  gray_data;
    wire        gray_keep;
    wire        gray_sof;
    wire        gray_eol;
    wire        gray_eof;

    wire        win_valid;
    wire        win_ready;
    wire [71:0] win_data;
    wire        win_keep;
    wire        win_sof;
    wire        win_eol;
    wire        win_eof;

    wire        gauss_valid;
    wire [7:0]  gauss_data;
    wire        gauss_keep;
    wire        gauss_sof;
    wire        gauss_eol;
    wire        gauss_eof;

    assign src_valid    = 1'b1;
    assign src_keep     = 1'b1;
    assign src_sof      = (src_x == 12'd0) && (src_y == 12'd0);
    assign src_eol      = (src_x == H_TOTAL - 1);
    assign src_eof      = (src_x == H_TOTAL - 1) && (src_y == V_TOTAL - 1);
    assign src_hs_raw   = (src_x <= H_SYNC - 1) ? 1'b0 : 1'b1;
    assign src_vs_raw   = (src_y <= V_SYNC - 1) ? 1'b0 : 1'b1;
    assign src_active   = (src_x >= ACTIVE_X_START) && (src_x < ACTIVE_X_START + H_DISP) &&
                          (src_y >= ACTIVE_Y_START) && (src_y < ACTIVE_Y_START + V_DISP);
    assign src_active_x = src_active ? (src_x - ACTIVE_X_START) : 12'd0;
    assign src_active_y = src_active ? (src_y - ACTIVE_Y_START) : 12'd0;

    assign src_rgb888 =
        !src_active ? 24'h000000 :
        ((src_active_x[5] ^ src_active_y[5]) ? 24'hF0F0F0 : 24'h101010);

    always @(posedge clk_25m or negedge rst_n) begin
        if (!rst_n) begin
            src_x <= 12'd0;
            src_y <= 12'd0;
        end else if (src_ready) begin
            if (src_x == H_TOTAL - 1) begin
                src_x <= 12'd0;
                if (src_y == V_TOTAL - 1)
                    src_y <= 12'd0;
                else
                    src_y <= src_y + 12'd1;
            end else begin
                src_x <= src_x + 12'd1;
            end
        end
    end

    always @(posedge clk_25m or negedge rst_n) begin
        if (!rst_n) begin
            hs_pipe         <= {PIPE_LAT{1'b1}};
            vs_pipe         <= {PIPE_LAT{1'b1}};
            gauss_gray_hold <= 8'd0;
        end else begin
            hs_pipe <= {hs_pipe[PIPE_LAT-2:0], src_hs_raw};
            vs_pipe <= {vs_pipe[PIPE_LAT-2:0], src_vs_raw};

            if (gauss_valid && gauss_keep)
                gauss_gray_hold <= gauss_data;
            else
                gauss_gray_hold <= 8'd0;
        end
    end

    grayscale_stream_std #(
        .MAX_LANES(1),
        .PIX_W_IN (24),
        .PIX_W_OUT(8)
    ) u_grayscale_stream_std (
        .clk    (clk_25m),
        .rst_n  (rst_n),
        .s_valid(src_valid),
        .s_ready(src_ready),
        .s_data (src_rgb888),
        .s_keep (src_keep),
        .s_sof  (src_sof),
        .s_eol  (src_eol),
        .s_eof  (src_eof),
        .m_valid(gray_valid),
        .m_ready(gray_ready),
        .m_data (gray_data),
        .m_keep (gray_keep),
        .m_sof  (gray_sof),
        .m_eol  (gray_eol),
        .m_eof  (gray_eof)
    );

    window3x3_stream_std #(
        .MAX_LANES (1),
        .DATA_W    (8),
        .IMG_WIDTH (H_TOTAL),
        .IMG_HEIGHT(V_TOTAL)
    ) u_window3x3_stream_std (
        .clk    (clk_25m),
        .rst_n  (rst_n),
        .s_valid(gray_valid),
        .s_ready(gray_ready),
        .s_data (gray_data),
        .s_keep (gray_keep),
        .s_sof  (gray_sof),
        .s_eol  (gray_eol),
        .s_eof  (gray_eof),
        .m_valid(win_valid),
        .m_ready(win_ready),
        .m_data (win_data),
        .m_keep (win_keep),
        .m_sof  (win_sof),
        .m_eol  (win_eol),
        .m_eof  (win_eof)
    );

    gaussian3x3_stream_demo #(
        .MAX_LANES(1),
        .DATA_W   (8)
    ) u_gaussian3x3_stream_demo (
        .clk    (clk_25m),
        .rst_n  (rst_n),
        .s_valid(win_valid),
        .s_ready(win_ready),
        .s_data (win_data),
        .s_keep (win_keep),
        .s_sof  (win_sof),
        .s_eol  (win_eol),
        .s_eof  (win_eof),
        .m_valid(gauss_valid),
        .m_ready(1'b1),
        .m_data (gauss_data),
        .m_keep (gauss_keep),
        .m_sof  (gauss_sof),
        .m_eol  (gauss_eol),
        .m_eof  (gauss_eof)
    );

    assign vga_clk = clk_25m;
    assign vga_hs  = hs_pipe[PIPE_LAT-1];
    assign vga_vs  = vs_pipe[PIPE_LAT-1];
    assign vga_r   = gauss_gray_hold;
    assign vga_g   = gauss_gray_hold;
    assign vga_b   = gauss_gray_hold;

    wire unused_meta;
    assign unused_meta = &{1'b0, gauss_sof, gauss_eol, gauss_eof};

endmodule
