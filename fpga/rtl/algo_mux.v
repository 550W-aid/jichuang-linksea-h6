`include "fpga/rtl/common/video_regs.vh"

module algo_mux
(
    input  wire [15:0] mode_i,
    input  wire [15:0] bypass_pixel_i,
    input  wire        bypass_valid_i,
    input  wire        bypass_sof_i,
    input  wire        bypass_eol_i,
    input  wire [15:0] proc_pixel_i,
    input  wire        proc_valid_i,
    input  wire        proc_sof_i,
    input  wire        proc_eol_i,
    output wire [15:0] pixel_o,
    output wire        valid_o,
    output wire        sof_o,
    output wire        eol_o
);

    wire use_proc = (mode_i != `MODE_BYPASS);

    assign pixel_o = use_proc ? proc_pixel_i : bypass_pixel_i;
    assign valid_o = use_proc ? proc_valid_i : bypass_valid_i;
    assign sof_o   = use_proc ? proc_sof_i   : bypass_sof_i;
    assign eol_o   = use_proc ? proc_eol_i   : bypass_eol_i;

endmodule
