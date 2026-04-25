`timescale 1ns / 1ps

module virtual_grab_button_event #(
    parameter integer STABLE_CYCLES = 4
) (
    input  wire clk,         // Processing clock.
    input  wire rst_n,       // Active-low reset.
    input  wire button_raw,  // Asynchronous raw button input.
    output reg  press_pulse  // One-cycle pulse on a debounced rising edge.
);

    localparam integer COUNT_W = (STABLE_CYCLES <= 1) ? 1 : $clog2(STABLE_CYCLES);

    reg button_sync0_reg;
    reg button_sync1_reg;
    reg button_state_reg;
    reg [COUNT_W-1:0] stable_count_reg;

    // Synchronize the asynchronous button input into the local clock domain.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            button_sync0_reg <= 1'b0;
            button_sync1_reg <= 1'b0;
        end else begin
            button_sync0_reg <= button_raw;
            button_sync1_reg <= button_sync0_reg;
        end
    end

    // Debounce the synchronized signal and emit a pulse only on a stable press.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            button_state_reg  <= 1'b0;
            stable_count_reg  <= {COUNT_W{1'b0}};
            press_pulse       <= 1'b0;
        end else begin
            press_pulse <= 1'b0;

            if (button_sync1_reg == button_state_reg) begin
                stable_count_reg <= {COUNT_W{1'b0}};
            end else if (stable_count_reg == STABLE_CYCLES - 1) begin
                stable_count_reg <= {COUNT_W{1'b0}};
                button_state_reg <= button_sync1_reg;

                if (button_sync1_reg) begin
                    press_pulse <= 1'b1;
                end
            end else begin
                stable_count_reg <= stable_count_reg + {{(COUNT_W-1){1'b0}}, 1'b1};
            end
        end
    end

endmodule
