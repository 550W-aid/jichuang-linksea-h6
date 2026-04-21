`timescale 1ns / 1ps

module u16_u10_div_pipe8 (
    input  wire        clk,     // processing clock
    input  wire        rst_n,   // active-low reset
    input  wire        i_valid, // divider input valid
    output wire        i_ready, // divider input ready
    input  wire [15:0] i_num,   // unsigned numerator
    input  wire [9:0]  i_den,   // unsigned denominator, must be non-zero
    output wire        o_valid, // quotient valid
    input  wire        o_ready, // quotient ready
    output wire [7:0]  o_quot   // integer quotient
);
    reg        s0_valid;
    reg [7:0]  s0_num_lo;
    reg [9:0]  s0_den;
    reg [9:0]  s0_rem;
    reg [7:0]  s0_quot;

    reg        s1_valid;
    reg [7:0]  s1_num_lo;
    reg [9:0]  s1_den;
    reg [9:0]  s1_rem;
    reg [7:0]  s1_quot;

    reg        s2_valid;
    reg [7:0]  s2_num_lo;
    reg [9:0]  s2_den;
    reg [9:0]  s2_rem;
    reg [7:0]  s2_quot;

    reg        s3_valid;
    reg [7:0]  s3_num_lo;
    reg [9:0]  s3_den;
    reg [9:0]  s3_rem;
    reg [7:0]  s3_quot;

    reg        s4_valid;
    reg [7:0]  s4_num_lo;
    reg [9:0]  s4_den;
    reg [9:0]  s4_rem;
    reg [7:0]  s4_quot;

    reg        s5_valid;
    reg [7:0]  s5_num_lo;
    reg [9:0]  s5_den;
    reg [9:0]  s5_rem;
    reg [7:0]  s5_quot;

    reg        s6_valid;
    reg [7:0]  s6_num_lo;
    reg [9:0]  s6_den;
    reg [9:0]  s6_rem;
    reg [7:0]  s6_quot;

    reg        s7_valid;
    reg [7:0]  s7_quot;

    wire       s7_ready;
    wire       s6_ready;
    wire       s5_ready;
    wire       s4_ready;
    wire       s3_ready;
    wire       s2_ready;
    wire       s1_ready;
    wire       s0_ready;

    wire [10:0] den_ext_in_w;
    wire [10:0] den_ext0_w;
    wire [10:0] den_ext1_w;
    wire [10:0] den_ext2_w;
    wire [10:0] den_ext3_w;
    wire [10:0] den_ext4_w;
    wire [10:0] den_ext5_w;
    wire [10:0] den_ext6_w;

    wire [10:0] trial0_w;
    wire [10:0] trial1_w;
    wire [10:0] trial2_w;
    wire [10:0] trial3_w;
    wire [10:0] trial4_w;
    wire [10:0] trial5_w;
    wire [10:0] trial6_w;
    wire [10:0] trial7_w;

    wire        qbit0_w;
    wire        qbit1_w;
    wire        qbit2_w;
    wire        qbit3_w;
    wire        qbit4_w;
    wire        qbit5_w;
    wire        qbit6_w;
    wire        qbit7_w;

    wire [9:0]  rem0_next_w;
    wire [9:0]  rem1_next_w;
    wire [9:0]  rem2_next_w;
    wire [9:0]  rem3_next_w;
    wire [9:0]  rem4_next_w;
    wire [9:0]  rem5_next_w;
    wire [9:0]  rem6_next_w;
    wire [9:0]  rem7_next_w;

    assign s7_ready = (~s7_valid) | o_ready;
    assign s6_ready = (~s6_valid) | s7_ready;
    assign s5_ready = (~s5_valid) | s6_ready;
    assign s4_ready = (~s4_valid) | s5_ready;
    assign s3_ready = (~s3_valid) | s4_ready;
    assign s2_ready = (~s2_valid) | s3_ready;
    assign s1_ready = (~s1_valid) | s2_ready;
    assign s0_ready = (~s0_valid) | s1_ready;

    assign i_ready = s0_ready;
    assign o_valid = s7_valid;
    assign o_quot  = s7_quot;

    assign den_ext_in_w = {1'b0, i_den};
    assign den_ext0_w   = {1'b0, s0_den};
    assign den_ext1_w   = {1'b0, s1_den};
    assign den_ext2_w   = {1'b0, s2_den};
    assign den_ext3_w   = {1'b0, s3_den};
    assign den_ext4_w   = {1'b0, s4_den};
    assign den_ext5_w   = {1'b0, s5_den};
    assign den_ext6_w   = {1'b0, s6_den};

    assign trial0_w = {2'b00, i_num[15:8], i_num[7]};
    assign qbit0_w  = (trial0_w >= den_ext_in_w);
    assign rem0_next_w = qbit0_w ? ((trial0_w - den_ext_in_w) & 11'h3FF) : trial0_w[9:0];

    assign trial1_w = {s0_rem, s0_num_lo[6]};
    assign qbit1_w  = (trial1_w >= den_ext0_w);
    assign rem1_next_w = qbit1_w ? ((trial1_w - den_ext0_w) & 11'h3FF) : trial1_w[9:0];

    assign trial2_w = {s1_rem, s1_num_lo[5]};
    assign qbit2_w  = (trial2_w >= den_ext1_w);
    assign rem2_next_w = qbit2_w ? ((trial2_w - den_ext1_w) & 11'h3FF) : trial2_w[9:0];

    assign trial3_w = {s2_rem, s2_num_lo[4]};
    assign qbit3_w  = (trial3_w >= den_ext2_w);
    assign rem3_next_w = qbit3_w ? ((trial3_w - den_ext2_w) & 11'h3FF) : trial3_w[9:0];

    assign trial4_w = {s3_rem, s3_num_lo[3]};
    assign qbit4_w  = (trial4_w >= den_ext3_w);
    assign rem4_next_w = qbit4_w ? ((trial4_w - den_ext3_w) & 11'h3FF) : trial4_w[9:0];

    assign trial5_w = {s4_rem, s4_num_lo[2]};
    assign qbit5_w  = (trial5_w >= den_ext4_w);
    assign rem5_next_w = qbit5_w ? ((trial5_w - den_ext4_w) & 11'h3FF) : trial5_w[9:0];

    assign trial6_w = {s5_rem, s5_num_lo[1]};
    assign qbit6_w  = (trial6_w >= den_ext5_w);
    assign rem6_next_w = qbit6_w ? ((trial6_w - den_ext5_w) & 11'h3FF) : trial6_w[9:0];

    assign trial7_w = {s6_rem, s6_num_lo[0]};
    assign qbit7_w  = (trial7_w >= den_ext6_w);
    assign rem7_next_w = qbit7_w ? ((trial7_w - den_ext6_w) & 11'h3FF) : trial7_w[9:0];

    // Each always block below advances one quotient bit, turning the original
    // long combinational divider into a one-sample-per-cycle pipeline.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_valid  <= 1'b0;
            s0_num_lo <= 8'd0;
            s0_den    <= 10'd0;
            s0_rem    <= 10'd0;
            s0_quot   <= 8'd0;
        end else if (s0_ready) begin
            s0_valid <= i_valid;
            if (i_valid) begin
                s0_num_lo <= i_num[7:0];
                s0_den    <= i_den;
                s0_rem    <= rem0_next_w;
                s0_quot   <= {7'd0, qbit0_w};
            end else begin
                s0_num_lo <= 8'd0;
                s0_den    <= 10'd0;
                s0_rem    <= 10'd0;
                s0_quot   <= 8'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid  <= 1'b0;
            s1_num_lo <= 8'd0;
            s1_den    <= 10'd0;
            s1_rem    <= 10'd0;
            s1_quot   <= 8'd0;
        end else if (s1_ready) begin
            s1_valid <= s0_valid;
            if (s0_valid) begin
                s1_num_lo <= s0_num_lo;
                s1_den    <= s0_den;
                s1_rem    <= rem1_next_w;
                s1_quot   <= {s0_quot[6:0], qbit1_w};
            end else begin
                s1_num_lo <= 8'd0;
                s1_den    <= 10'd0;
                s1_rem    <= 10'd0;
                s1_quot   <= 8'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid  <= 1'b0;
            s2_num_lo <= 8'd0;
            s2_den    <= 10'd0;
            s2_rem    <= 10'd0;
            s2_quot   <= 8'd0;
        end else if (s2_ready) begin
            s2_valid <= s1_valid;
            if (s1_valid) begin
                s2_num_lo <= s1_num_lo;
                s2_den    <= s1_den;
                s2_rem    <= rem2_next_w;
                s2_quot   <= {s1_quot[6:0], qbit2_w};
            end else begin
                s2_num_lo <= 8'd0;
                s2_den    <= 10'd0;
                s2_rem    <= 10'd0;
                s2_quot   <= 8'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_valid  <= 1'b0;
            s3_num_lo <= 8'd0;
            s3_den    <= 10'd0;
            s3_rem    <= 10'd0;
            s3_quot   <= 8'd0;
        end else if (s3_ready) begin
            s3_valid <= s2_valid;
            if (s2_valid) begin
                s3_num_lo <= s2_num_lo;
                s3_den    <= s2_den;
                s3_rem    <= rem3_next_w;
                s3_quot   <= {s2_quot[6:0], qbit3_w};
            end else begin
                s3_num_lo <= 8'd0;
                s3_den    <= 10'd0;
                s3_rem    <= 10'd0;
                s3_quot   <= 8'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s4_valid  <= 1'b0;
            s4_num_lo <= 8'd0;
            s4_den    <= 10'd0;
            s4_rem    <= 10'd0;
            s4_quot   <= 8'd0;
        end else if (s4_ready) begin
            s4_valid <= s3_valid;
            if (s3_valid) begin
                s4_num_lo <= s3_num_lo;
                s4_den    <= s3_den;
                s4_rem    <= rem4_next_w;
                s4_quot   <= {s3_quot[6:0], qbit4_w};
            end else begin
                s4_num_lo <= 8'd0;
                s4_den    <= 10'd0;
                s4_rem    <= 10'd0;
                s4_quot   <= 8'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s5_valid  <= 1'b0;
            s5_num_lo <= 8'd0;
            s5_den    <= 10'd0;
            s5_rem    <= 10'd0;
            s5_quot   <= 8'd0;
        end else if (s5_ready) begin
            s5_valid <= s4_valid;
            if (s4_valid) begin
                s5_num_lo <= s4_num_lo;
                s5_den    <= s4_den;
                s5_rem    <= rem5_next_w;
                s5_quot   <= {s4_quot[6:0], qbit5_w};
            end else begin
                s5_num_lo <= 8'd0;
                s5_den    <= 10'd0;
                s5_rem    <= 10'd0;
                s5_quot   <= 8'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s6_valid  <= 1'b0;
            s6_num_lo <= 8'd0;
            s6_den    <= 10'd0;
            s6_rem    <= 10'd0;
            s6_quot   <= 8'd0;
        end else if (s6_ready) begin
            s6_valid <= s5_valid;
            if (s5_valid) begin
                s6_num_lo <= s5_num_lo;
                s6_den    <= s5_den;
                s6_rem    <= rem6_next_w;
                s6_quot   <= {s5_quot[6:0], qbit6_w};
            end else begin
                s6_num_lo <= 8'd0;
                s6_den    <= 10'd0;
                s6_rem    <= 10'd0;
                s6_quot   <= 8'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s7_valid <= 1'b0;
            s7_quot  <= 8'd0;
        end else if (s7_ready) begin
            s7_valid <= s6_valid;
            if (s6_valid) begin
                s7_quot <= {s6_quot[6:0], qbit7_w};
            end else begin
                s7_quot <= 8'd0;
            end
        end
    end
endmodule
