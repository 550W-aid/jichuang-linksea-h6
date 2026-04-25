`timescale 1ns / 1ps

module rotate_trig_lut (
    input  wire signed [8:0] angle_deg,
    output reg  signed [15:0] cos_q8,
    output reg  signed [15:0] sin_q8
);

    always @* begin
        case (angle_deg)
            -9'sd180: begin cos_q8 = -16'sd256; sin_q8 =  16'sd0;   end
            -9'sd135: begin cos_q8 = -16'sd181; sin_q8 = -16'sd181; end
            -9'sd90 : begin cos_q8 =  16'sd0;   sin_q8 = -16'sd256; end
            -9'sd60 : begin cos_q8 =  16'sd128; sin_q8 = -16'sd222; end
            -9'sd45 : begin cos_q8 =  16'sd181; sin_q8 = -16'sd181; end
            -9'sd30 : begin cos_q8 =  16'sd222; sin_q8 = -16'sd128; end
             9'sd0  : begin cos_q8 =  16'sd256; sin_q8 =  16'sd0;   end
             9'sd30 : begin cos_q8 =  16'sd222; sin_q8 =  16'sd128; end
             9'sd45 : begin cos_q8 =  16'sd181; sin_q8 =  16'sd181; end
             9'sd60 : begin cos_q8 =  16'sd128; sin_q8 =  16'sd222; end
             9'sd90 : begin cos_q8 =  16'sd0;   sin_q8 =  16'sd256; end
             9'sd135: begin cos_q8 = -16'sd181; sin_q8 =  16'sd181; end
             9'sd180: begin cos_q8 = -16'sd256; sin_q8 =  16'sd0;   end
            default : begin cos_q8 =  16'sd256; sin_q8 =  16'sd0;   end
        endcase
    end

endmodule
