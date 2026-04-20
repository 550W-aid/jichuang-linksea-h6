module perf_counter #
(
    parameter integer CLK_HZ = 25_000_000
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sof_pulse,
    output reg  [15:0] fps_counter,
    output reg  [15:0] heartbeat
);

    reg [31:0] sec_divider;
    reg [15:0] frame_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_divider   <= 32'd0;
            frame_counter <= 16'd0;
            fps_counter   <= 16'd0;
            heartbeat     <= 16'd0;
        end else begin
            if (sof_pulse) begin
                frame_counter <= frame_counter + 16'd1;
            end

            if (sec_divider == CLK_HZ - 1) begin
                sec_divider   <= 32'd0;
                fps_counter   <= frame_counter;
                frame_counter <= 16'd0;
                heartbeat     <= heartbeat + 16'd1;
            end else begin
                sec_divider <= sec_divider + 32'd1;
            end
        end
    end

endmodule

