`timescale 1ns / 1ps

module blob_stats #(
    parameter X_WIDTH    = 12,
    parameter Y_WIDTH    = 12,
    parameter COUNT_W    = 24,
    parameter SUM_X_W    = 36,
    parameter SUM_Y_W    = 36,
    parameter MIN_PIXELS = 16
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  sof,
    input  wire                  eof,
    input  wire                  pixel_valid,
    input  wire                  pixel_match,
    input  wire [X_WIDTH-1:0]    pixel_x,
    input  wire [Y_WIDTH-1:0]    pixel_y,
    output reg                   blob_valid,
    output reg [X_WIDTH-1:0]     center_x,
    output reg [Y_WIDTH-1:0]     center_y,
    output reg [COUNT_W-1:0]     pixel_count,
    output reg [X_WIDTH-1:0]     min_x,
    output reg [X_WIDTH-1:0]     max_x,
    output reg [Y_WIDTH-1:0]     min_y,
    output reg [Y_WIDTH-1:0]     max_y
);

    reg [COUNT_W-1:0] count_acc;
    reg [SUM_X_W-1:0] sum_x_acc;
    reg [SUM_Y_W-1:0] sum_y_acc;
    reg [X_WIDTH-1:0] min_x_acc;
    reg [X_WIDTH-1:0] max_x_acc;
    reg [Y_WIDTH-1:0] min_y_acc;
    reg [Y_WIDTH-1:0] max_y_acc;

    wire add_sample;
    assign add_sample = pixel_valid && pixel_match;

    wire [COUNT_W-1:0] next_count = count_acc + {{(COUNT_W-1){1'b0}}, add_sample};
    wire [SUM_X_W-1:0] next_sum_x = sum_x_acc + (add_sample ? pixel_x : {X_WIDTH{1'b0}});
    wire [SUM_Y_W-1:0] next_sum_y = sum_y_acc + (add_sample ? pixel_y : {Y_WIDTH{1'b0}});

    wire [X_WIDTH-1:0] next_min_x =
        !add_sample ? min_x_acc :
        (count_acc == 0) ? pixel_x : ((pixel_x < min_x_acc) ? pixel_x : min_x_acc);
    wire [X_WIDTH-1:0] next_max_x =
        !add_sample ? max_x_acc :
        (count_acc == 0) ? pixel_x : ((pixel_x > max_x_acc) ? pixel_x : max_x_acc);
    wire [Y_WIDTH-1:0] next_min_y =
        !add_sample ? min_y_acc :
        (count_acc == 0) ? pixel_y : ((pixel_y < min_y_acc) ? pixel_y : min_y_acc);
    wire [Y_WIDTH-1:0] next_max_y =
        !add_sample ? max_y_acc :
        (count_acc == 0) ? pixel_y : ((pixel_y > max_y_acc) ? pixel_y : max_y_acc);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count_acc   <= {COUNT_W{1'b0}};
            sum_x_acc   <= {SUM_X_W{1'b0}};
            sum_y_acc   <= {SUM_Y_W{1'b0}};
            min_x_acc   <= {X_WIDTH{1'b1}};
            max_x_acc   <= {X_WIDTH{1'b0}};
            min_y_acc   <= {Y_WIDTH{1'b1}};
            max_y_acc   <= {Y_WIDTH{1'b0}};
            blob_valid  <= 1'b0;
            center_x    <= {X_WIDTH{1'b0}};
            center_y    <= {Y_WIDTH{1'b0}};
            pixel_count <= {COUNT_W{1'b0}};
            min_x       <= {X_WIDTH{1'b0}};
            max_x       <= {X_WIDTH{1'b0}};
            min_y       <= {Y_WIDTH{1'b0}};
            max_y       <= {Y_WIDTH{1'b0}};
        end else begin
            if (sof) begin
                count_acc <= {COUNT_W{1'b0}};
                sum_x_acc <= {SUM_X_W{1'b0}};
                sum_y_acc <= {SUM_Y_W{1'b0}};
                min_x_acc <= {X_WIDTH{1'b1}};
                max_x_acc <= {X_WIDTH{1'b0}};
                min_y_acc <= {Y_WIDTH{1'b1}};
                max_y_acc <= {Y_WIDTH{1'b0}};
            end else if (add_sample) begin
                count_acc <= next_count;
                sum_x_acc <= next_sum_x;
                sum_y_acc <= next_sum_y;
                min_x_acc <= next_min_x;
                max_x_acc <= next_max_x;
                min_y_acc <= next_min_y;
                max_y_acc <= next_max_y;
            end

            if (eof) begin
                if (next_count >= MIN_PIXELS) begin
                    blob_valid  <= 1'b1;
                    center_x    <= next_sum_x / next_count;
                    center_y    <= next_sum_y / next_count;
                    pixel_count <= next_count;
                    min_x       <= next_min_x;
                    max_x       <= next_max_x;
                    min_y       <= next_min_y;
                    max_y       <= next_max_y;
                end else begin
                    blob_valid  <= 1'b0;
                    center_x    <= {X_WIDTH{1'b0}};
                    center_y    <= {Y_WIDTH{1'b0}};
                    pixel_count <= next_count;
                    min_x       <= {X_WIDTH{1'b0}};
                    max_x       <= {X_WIDTH{1'b0}};
                    min_y       <= {Y_WIDTH{1'b0}};
                    max_y       <= {Y_WIDTH{1'b0}};
                end
            end
        end
    end

endmodule
