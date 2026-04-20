module gaussian3x3_stream_demo #(
    parameter integer MAX_LANES = 1,
    parameter integer DATA_W    = 8
) (
    input  wire                          clk,
    input  wire                          rst_n,
    input  wire                          s_valid,
    output wire                          s_ready,
    input  wire [MAX_LANES*DATA_W*9-1:0] s_data,
    input  wire [MAX_LANES-1:0]          s_keep,
    input  wire                          s_sof,
    input  wire                          s_eol,
    input  wire                          s_eof,
    output reg                           m_valid,
    input  wire                          m_ready,
    output reg  [MAX_LANES*DATA_W-1:0]   m_data,
    output reg  [MAX_LANES-1:0]          m_keep,
    output reg                           m_sof,
    output reg                           m_eol,
    output reg                           m_eof
);

    localparam integer WINDOW_W = DATA_W * 9;
    localparam integer SUM_W    = DATA_W + 4;

    wire [MAX_LANES*DATA_W-1:0] filtered_data;
    wire                        has_active_lane;

    genvar lane;
    generate
        for (lane = 0; lane < MAX_LANES; lane = lane + 1) begin : g_lane
            wire [WINDOW_W-1:0] lane_window;
            wire [DATA_W-1:0]   p0;
            wire [DATA_W-1:0]   p1;
            wire [DATA_W-1:0]   p2;
            wire [DATA_W-1:0]   p3;
            wire [DATA_W-1:0]   p4;
            wire [DATA_W-1:0]   p5;
            wire [DATA_W-1:0]   p6;
            wire [DATA_W-1:0]   p7;
            wire [DATA_W-1:0]   p8;
            wire [SUM_W-1:0]    weighted_sum;

            assign lane_window = s_data[lane*WINDOW_W +: WINDOW_W];
            assign p0 = lane_window[0*DATA_W +: DATA_W];
            assign p1 = lane_window[1*DATA_W +: DATA_W];
            assign p2 = lane_window[2*DATA_W +: DATA_W];
            assign p3 = lane_window[3*DATA_W +: DATA_W];
            assign p4 = lane_window[4*DATA_W +: DATA_W];
            assign p5 = lane_window[5*DATA_W +: DATA_W];
            assign p6 = lane_window[6*DATA_W +: DATA_W];
            assign p7 = lane_window[7*DATA_W +: DATA_W];
            assign p8 = lane_window[8*DATA_W +: DATA_W];

            assign weighted_sum =
                {{4{1'b0}}, p0} +
                {{3{1'b0}}, p1, 1'b0} +
                {{4{1'b0}}, p2} +
                {{3{1'b0}}, p3, 1'b0} +
                {{2{1'b0}}, p4, 2'b00} +
                {{3{1'b0}}, p5, 1'b0} +
                {{4{1'b0}}, p6} +
                {{3{1'b0}}, p7, 1'b0} +
                {{4{1'b0}}, p8};

            assign filtered_data[lane*DATA_W +: DATA_W] = weighted_sum[SUM_W-1:4];
        end
    endgenerate

    assign has_active_lane = |s_keep;
    assign s_ready         = (~m_valid) | m_ready;

    always @(posedge clk) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= {MAX_LANES*DATA_W{1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else if (s_ready) begin
            m_valid <= s_valid && has_active_lane;
            if (s_valid && has_active_lane) begin
                m_data <= filtered_data;
                m_keep <= s_keep;
                m_sof  <= s_sof;
                m_eol  <= s_eol;
                m_eof  <= s_eof;
            end else begin
                m_data <= {MAX_LANES*DATA_W{1'b0}};
                m_keep <= {MAX_LANES{1'b0}};
                m_sof  <= 1'b0;
                m_eol  <= 1'b0;
                m_eof  <= 1'b0;
            end
        end
    end

endmodule
