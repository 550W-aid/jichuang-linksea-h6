module frame_buf_stub #
(
    parameter integer FRAME_WIDTH = 640,
    parameter integer ADDR_W      = 12
)
(
    input  wire        wr_clk,
    input  wire        rd_clk,
    input  wire        rst_n,
    input  wire [15:0] pixel_in,
    input  wire        valid_in,
    input  wire        sof_in,
    input  wire        eol_in,
    input  wire        rd_active_i,
    input  wire        rd_sof_i,
    input  wire        rd_eol_i,
    output reg  [15:0] pixel_out,
    output reg         valid_out,
    output reg         sof_out,
    output reg         eol_out,
    output reg         frame_ready_o
);

    localparam integer FIFO_WORDS = (1 << ADDR_W);

    wire [17:0] fifo_q;
    wire        fifo_rdempty;
    wire        fifo_wrfull;
    wire        fifo_rdfull;
    wire        fifo_wrempty;
    wire [ADDR_W-1:0] fifo_rdusedw;
    wire [ADDR_W-1:0] fifo_wrusedw;
    wire        fifo_wrreq;
    wire        fifo_rdreq;

    assign fifo_wrreq = valid_in && !fifo_wrfull;
    assign fifo_rdreq = rd_active_i && !fifo_rdempty;

    dcfifo #(
        .lpm_width(18),
        .lpm_widthu(ADDR_W),
        .lpm_numwords(FIFO_WORDS),
        .delay_rdusedw(1),
        .delay_wrusedw(1),
        .rdsync_delaypipe(3),
        .wrsync_delaypipe(3),
        .intended_device_family("Stratix"),
        .lpm_showahead("ON"),
        .underflow_checking("ON"),
        .overflow_checking("ON"),
        .clocks_are_synchronized("FALSE"),
        .use_eab("ON"),
        .add_ram_output_register("OFF"),
        .lpm_hint("USE_EAB=ON")
    ) u_pixel_fifo (
        .data({sof_in, eol_in, pixel_in}),
        .rdclk(rd_clk),
        .wrclk(wr_clk),
        .aclr(~rst_n),
        .rdreq(fifo_rdreq),
        .wrreq(fifo_wrreq),
        .rdfull(fifo_rdfull),
        .wrfull(fifo_wrfull),
        .rdempty(fifo_rdempty),
        .wrempty(fifo_wrempty),
        .rdusedw(fifo_rdusedw),
        .wrusedw(fifo_wrusedw),
        .q(fifo_q)
    );

    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_out     <= 16'd0;
            valid_out     <= 1'b0;
            sof_out       <= 1'b0;
            eol_out       <= 1'b0;
            frame_ready_o <= 1'b0;
        end else begin
            frame_ready_o <= !fifo_rdempty;

            if (fifo_rdreq) begin
                pixel_out <= fifo_q[15:0];
                valid_out <= 1'b1;
                sof_out   <= fifo_q[17];
                eol_out   <= fifo_q[16];
            end else begin
                pixel_out <= 16'd0;
                valid_out <= 1'b0;
                sof_out   <= 1'b0;
                eol_out   <= 1'b0;
            end
        end
    end

endmodule
