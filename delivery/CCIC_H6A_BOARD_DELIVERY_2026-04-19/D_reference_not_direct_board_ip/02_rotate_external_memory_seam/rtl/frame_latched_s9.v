`timescale 1ns / 1ps

module frame_latched_s9 (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              cfg_valid,
    output wire              cfg_ready,
    input  wire signed [8:0] cfg_data,
    input  wire              frame_start_pulse,
    output reg  signed [8:0] active_data,
    output wire signed [8:0] frame_data
);

    reg              pending_valid;
    reg signed [8:0] pending_data;

    wire commit_pending;

    assign cfg_ready      = 1'b1;
    assign commit_pending = frame_start_pulse && pending_valid;
    assign frame_data     = commit_pending ? pending_data : active_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_valid <= 1'b0;
            pending_data  <= 9'sd0;
            active_data   <= 9'sd0;
        end else begin
            if (commit_pending) begin
                active_data <= pending_data;
            end

            case ({commit_pending, cfg_valid})
                2'b01: begin
                    pending_valid <= 1'b1;
                    pending_data  <= cfg_data;
                end
                2'b10: begin
                    pending_valid <= 1'b0;
                end
                2'b11: begin
                    pending_valid <= 1'b1;
                    pending_data  <= cfg_data;
                end
                default: begin
                end
            endcase
        end
    end

endmodule
