module dvp_rx
(
    input  wire       pclk,
    input  wire       rst_n,
    input  wire       vsync_i,
    input  wire       href_i,
    input  wire [7:0] data_i,
    output reg  [15:0] pixel_o,
    output reg         valid_o,
    output reg         sof_o,
    output reg         eol_o
);

    reg        byte_phase;
    reg [7:0]  byte_hi;
    reg        href_d;
    reg        vsync_d;
    reg        pending_sof;

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            byte_phase  <= 1'b0;
            byte_hi     <= 8'd0;
            href_d      <= 1'b0;
            vsync_d     <= 1'b0;
            pending_sof <= 1'b0;
            pixel_o     <= 16'd0;
            valid_o     <= 1'b0;
            sof_o       <= 1'b0;
            eol_o       <= 1'b0;
        end else begin
            href_d  <= href_i;
            vsync_d <= vsync_i;
            valid_o <= 1'b0;
            sof_o   <= 1'b0;
            eol_o   <= 1'b0;

            // OV5640 DVP timing in the reference design treats VSYNC falling
            // edge as the start of a new frame.
            if (vsync_d && !vsync_i) begin
                pending_sof <= 1'b1;
                byte_phase  <= 1'b0;
            end

            if (href_i) begin
                if (!byte_phase) begin
                    byte_hi    <= data_i;
                    byte_phase <= 1'b1;
                end else begin
                    pixel_o    <= {byte_hi, data_i};
                    valid_o    <= 1'b1;
                    sof_o      <= pending_sof;
                    pending_sof <= 1'b0;
                    byte_phase <= 1'b0;
                end
            end else begin
                byte_phase <= 1'b0;
            end

            if (href_d && !href_i) begin
                eol_o <= 1'b1;
            end
        end
    end

endmodule
