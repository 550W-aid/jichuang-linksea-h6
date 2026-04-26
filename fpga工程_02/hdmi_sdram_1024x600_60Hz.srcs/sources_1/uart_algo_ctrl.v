module uart_algo_ctrl (
    input  wire              clk,
    input  wire              rst_n,
    input  wire [7:0]        data_i,
    input  wire              data_valid_i,
    output reg               zoom_valid_o,
    output reg [7:0]         zoom_level_o,
    output reg               zoom_in_valid_o,
    output reg [7:0]         zoom_in_level_o,
    output reg               pan_x_valid_o,
    output reg [7:0]         pan_x_value_o,
    output reg               pan_y_valid_o,
    output reg [7:0]         pan_y_value_o,
    output reg               lowlight_valid_o,
    output reg signed [8:0]  lowlight_value_o
);

    localparam [2:0] MODE_IDLE     = 3'd0;
    localparam [2:0] MODE_ZOOM_OUT = 3'd1;
    localparam [2:0] MODE_ZOOM_IN  = 3'd2;
    localparam [2:0] MODE_PAN_X    = 3'd3;
    localparam [2:0] MODE_PAN_Y    = 3'd4;
    localparam [2:0] MODE_LOW      = 3'd5;
    localparam [2:0] MODE_DISCARD  = 3'd6;

    reg [2:0] mode_r;
    reg [9:0] accum_r;
    reg       digit_seen_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_r           <= MODE_IDLE;
            accum_r          <= 10'd0;
            digit_seen_r     <= 1'b0;
            zoom_valid_o     <= 1'b0;
            zoom_level_o     <= 8'd0;
            zoom_in_valid_o  <= 1'b0;
            zoom_in_level_o  <= 8'd0;
            pan_x_valid_o    <= 1'b0;
            pan_x_value_o    <= 8'd128;
            pan_y_valid_o    <= 1'b0;
            pan_y_value_o    <= 8'd128;
            lowlight_valid_o <= 1'b0;
            lowlight_value_o <= 9'sd0;
        end else begin
            zoom_valid_o     <= 1'b0;
            zoom_in_valid_o  <= 1'b0;
            pan_x_valid_o    <= 1'b0;
            pan_y_valid_o    <= 1'b0;
            lowlight_valid_o <= 1'b0;

            if (data_valid_i) begin
                if ((data_i == 8'h0A) || (data_i == 8'h0D)) begin
                    if (digit_seen_r) begin
                        if (mode_r == MODE_ZOOM_OUT) begin
                            zoom_valid_o <= 1'b1;
                            if (accum_r >= 10'd255) begin
                                zoom_level_o <= 8'd255;
                            end else begin
                                zoom_level_o <= accum_r[7:0];
                            end
                        end else if (mode_r == MODE_ZOOM_IN) begin
                            zoom_in_valid_o <= 1'b1;
                            if (accum_r >= 10'd255) begin
                                zoom_in_level_o <= 8'd255;
                            end else begin
                                zoom_in_level_o <= accum_r[7:0];
                            end
                        end else if (mode_r == MODE_PAN_X) begin
                            pan_x_valid_o <= 1'b1;
                            if (accum_r >= 10'd255) begin
                                pan_x_value_o <= 8'd255;
                            end else begin
                                pan_x_value_o <= accum_r[7:0];
                            end
                        end else if (mode_r == MODE_PAN_Y) begin
                            pan_y_valid_o <= 1'b1;
                            if (accum_r >= 10'd255) begin
                                pan_y_value_o <= 8'd255;
                            end else begin
                                pan_y_value_o <= accum_r[7:0];
                            end
                        end else if (mode_r == MODE_LOW) begin
                            lowlight_valid_o <= 1'b1;
                            if (accum_r >= 10'd255) begin
                                lowlight_value_o <= 9'sd255;
                            end else begin
                                lowlight_value_o <= {1'b0, accum_r[7:0]};
                            end
                        end
                    end

                    mode_r       <= MODE_IDLE;
                    accum_r      <= 10'd0;
                    digit_seen_r <= 1'b0;
                end else begin
                    case (mode_r)
                        MODE_IDLE: begin
                            accum_r      <= 10'd0;
                            digit_seen_r <= 1'b0;
                            if ((data_i == "Z") || (data_i == "z")) begin
                                mode_r <= MODE_ZOOM_OUT;
                            end else if ((data_i == "X") || (data_i == "x")) begin
                                mode_r <= MODE_ZOOM_IN;
                            end else if ((data_i == "H") || (data_i == "h")) begin
                                mode_r <= MODE_PAN_X;
                            end else if ((data_i == "V") || (data_i == "v")) begin
                                mode_r <= MODE_PAN_Y;
                            end else if ((data_i == "L") || (data_i == "l")) begin
                                mode_r <= MODE_LOW;
                            end else if ((data_i == " ") || (data_i == 8'h09)) begin
                                mode_r <= MODE_IDLE;
                            end else begin
                                mode_r <= MODE_DISCARD;
                            end
                        end

                        MODE_ZOOM_OUT,
                        MODE_ZOOM_IN,
                        MODE_PAN_X,
                        MODE_PAN_Y,
                        MODE_LOW: begin
                            if ((data_i >= "0") && (data_i <= "9")) begin
                                digit_seen_r <= 1'b1;
                                if (accum_r < 10'd999) begin
                                    accum_r <= (accum_r * 10'd10) + (data_i - "0");
                                end
                            end else if ((data_i == " ") || (data_i == 8'h09)) begin
                                mode_r <= mode_r;
                            end else begin
                                mode_r <= MODE_DISCARD;
                            end
                        end

                        default: begin
                            mode_r <= MODE_DISCARD;
                        end
                    endcase
                end
            end
        end
    end

endmodule
