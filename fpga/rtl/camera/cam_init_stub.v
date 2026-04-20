module cam_init_stub #
(
    parameter integer STARTUP_DELAY = 2_500_000
)
(
    input  wire clk,
    input  wire rst_n,
    output reg  sccb_scl_o,
    output reg  sccb_sda_o,
    output reg  init_done_o
);

    reg [31:0] delay_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_cnt    <= 32'd0;
            sccb_scl_o   <= 1'b1;
            sccb_sda_o   <= 1'b1;
            init_done_o  <= 1'b0;
        end else begin
            if (!init_done_o) begin
                if (delay_cnt == STARTUP_DELAY - 1) begin
                    init_done_o <= 1'b1;
                end else begin
                    delay_cnt <= delay_cnt + 32'd1;
                end
            end
        end
    end

endmodule

