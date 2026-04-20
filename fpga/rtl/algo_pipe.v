module algo_pipe
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] mode_i,
    input  wire [15:0] algo_enable_i,
    input  wire [15:0] brightness_gain_i,
    input  wire [15:0] gamma_sel_i,
    input  wire [15:0] scale_sel_i,
    input  wire [15:0] rotate_sel_i,
    input  wire [15:0] edge_sel_i,
    input  wire [15:0] pixel_in,
    input  wire        valid_in,
    input  wire        sof_in,
    input  wire        eol_in,
    output wire [15:0] pixel_out,
    output wire        valid_out,
    output wire        sof_out,
    output wire        eol_out
);

    wire gray_en     = algo_enable_i[0] | (mode_i == 16'h0001);
    wire hist_eq_en  = algo_enable_i[1];
    wire scale_en    = algo_enable_i[2];
    wire rotate_en   = algo_enable_i[3];
    wire lowlight_en = algo_enable_i[4] | (mode_i == 16'h0002) | (mode_i == 16'h0003);
    wire edge_en     = algo_enable_i[5] | (mode_i == 16'h0003);

    wire [15:0] gray_pixel;
    wire        gray_valid;
    wire        gray_sof;
    wire        gray_eol;

    wire [15:0] hist_pixel;
    wire        hist_valid;
    wire        hist_sof;
    wire        hist_eol;

    wire [15:0] scale_pixel;
    wire        scale_valid;
    wire        scale_sof;
    wire        scale_eol;

    wire [15:0] rotate_pixel;
    wire        rotate_valid;
    wire        rotate_sof;
    wire        rotate_eol;

    wire [15:0] lowlight_pixel;
    wire        lowlight_valid;
    wire        lowlight_sof;
    wire        lowlight_eol;

    grayscale u_grayscale (
        .clk(clk),
        .rst_n(rst_n),
        .enable_i(gray_en),
        .pixel_in(pixel_in),
        .valid_in(valid_in),
        .sof_in(sof_in),
        .eol_in(eol_in),
        .pixel_out(gray_pixel),
        .valid_out(gray_valid),
        .sof_out(gray_sof),
        .eol_out(gray_eol)
    );

    hist_eq_stub u_hist_eq (
        .clk(clk),
        .rst_n(rst_n),
        .enable_i(hist_eq_en),
        .pixel_in(gray_pixel),
        .valid_in(gray_valid),
        .sof_in(gray_sof),
        .eol_in(gray_eol),
        .pixel_out(hist_pixel),
        .valid_out(hist_valid),
        .sof_out(hist_sof),
        .eol_out(hist_eol)
    );

    fixed_scale_stub u_scale (
        .clk(clk),
        .rst_n(rst_n),
        .enable_i(scale_en),
        .scale_sel_i(scale_sel_i),
        .pixel_in(hist_pixel),
        .valid_in(hist_valid),
        .sof_in(hist_sof),
        .eol_in(hist_eol),
        .pixel_out(scale_pixel),
        .valid_out(scale_valid),
        .sof_out(scale_sof),
        .eol_out(scale_eol)
    );

    fixed_rotate_stub u_rotate (
        .clk(clk),
        .rst_n(rst_n),
        .enable_i(rotate_en),
        .rotate_sel_i(rotate_sel_i),
        .pixel_in(scale_pixel),
        .valid_in(scale_valid),
        .sof_in(scale_sof),
        .eol_in(scale_eol),
        .pixel_out(rotate_pixel),
        .valid_out(rotate_valid),
        .sof_out(rotate_sof),
        .eol_out(rotate_eol)
    );

    lowlight_enhance u_lowlight (
        .clk(clk),
        .rst_n(rst_n),
        .enable_i(lowlight_en),
        .brightness_gain_i(brightness_gain_i),
        .gamma_sel_i(gamma_sel_i),
        .pixel_in(rotate_pixel),
        .valid_in(rotate_valid),
        .sof_in(rotate_sof),
        .eol_in(rotate_eol),
        .pixel_out(lowlight_pixel),
        .valid_out(lowlight_valid),
        .sof_out(lowlight_sof),
        .eol_out(lowlight_eol)
    );

    edge_overlay u_edge_overlay (
        .clk(clk),
        .rst_n(rst_n),
        .enable_i(edge_en),
        .edge_sel_i(edge_sel_i),
        .pixel_in(lowlight_pixel),
        .valid_in(lowlight_valid),
        .sof_in(lowlight_sof),
        .eol_in(lowlight_eol),
        .pixel_out(pixel_out),
        .valid_out(valid_out),
        .sof_out(sof_out),
        .eol_out(eol_out)
    );

endmodule

