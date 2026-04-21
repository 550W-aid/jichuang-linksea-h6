`timescale 1ns / 1ps

module affine_nearest_stream_std #(
    parameter integer MAX_LANES  = 1,
    parameter integer IMG_WIDTH  = 1024,
    parameter integer IMG_HEIGHT = 768
) (
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire                        s_valid,
    output wire                        s_ready,
    input  wire [MAX_LANES*24-1:0]     s_data,
    input  wire [MAX_LANES-1:0]        s_keep,
    input  wire                        s_sof,
    input  wire                        s_eol,
    input  wire                        s_eof,
    input  wire                        cfg_valid,
    output wire                        cfg_ready,
    input  wire signed [15:0]          cfg_m00,
    input  wire signed [15:0]          cfg_m01,
    input  wire signed [15:0]          cfg_m02,
    input  wire signed [15:0]          cfg_m10,
    input  wire signed [15:0]          cfg_m11,
    input  wire signed [15:0]          cfg_m12,
    output wire signed [15:0]          active_m00,
    output wire signed [15:0]          active_m01,
    output wire signed [15:0]          active_m02,
    output wire signed [15:0]          active_m10,
    output wire signed [15:0]          active_m11,
    output wire signed [15:0]          active_m12,
    output reg                         m_valid,
    input  wire                        m_ready,
    output reg  [MAX_LANES*24-1:0]     m_data,
    output reg  [MAX_LANES-1:0]        m_keep,
    output reg                         m_sof,
    output reg                         m_eol,
    output reg                         m_eof
);

    function integer clog2;
        input integer value;
        integer tmp;
        integer bit_idx;
        begin
            tmp = value - 1;
            clog2 = 0;
            for (bit_idx = 0; bit_idx < 32; bit_idx = bit_idx + 1) begin
                if (tmp > 0) begin
                    tmp = tmp >> 1;
                    clog2 = clog2 + 1;
                end
            end
        end
    endfunction

    function integer popcount_keep;
        input [MAX_LANES-1:0] keep_mask;
        integer idx;
        begin
            popcount_keep = 0;
            for (idx = 0; idx < MAX_LANES; idx = idx + 1) begin
                if (keep_mask[idx]) begin
                    popcount_keep = popcount_keep + 1;
                end
            end
        end
    endfunction

    localparam integer PIXELS = IMG_WIDTH * IMG_HEIGHT;
    localparam integer ADDR_W = (PIXELS <= 1) ? 1 : clog2(PIXELS);
    localparam [0:0]   ST_CAPTURE = 1'b0;
    localparam [0:0]   ST_OUTPUT  = 1'b1;

    reg  [0:0]              state_q;
    reg                     prep_valid_q;
    reg  [ADDR_W-1:0]       capture_count_q;
    reg  [15:0]             out_x_q;
    reg  [15:0]             out_y_q;
    reg  [23:0]             frame_mem [0:PIXELS-1];

    reg  [MAX_LANES-1:0]    prep_keep_q;
    reg  [MAX_LANES-1:0]    prep_sample_valid_q;
    reg  [MAX_LANES*ADDR_W-1:0] prep_sample_addr_q;
    reg                     prep_sof_q;
    reg                     prep_eol_q;
    reg                     prep_eof_q;
    reg  [15:0]             prep_next_out_x_q;
    reg  [15:0]             prep_next_out_y_q;

    wire                    frame_start_commit_w;
    wire                    pipe_advance_w;
    wire                    s_fire_w;
    wire signed [15:0]      frame_m00_w;
    wire signed [15:0]      frame_m01_w;
    wire signed [15:0]      frame_m02_w;
    wire signed [15:0]      frame_m10_w;
    wire signed [15:0]      frame_m11_w;
    wire signed [15:0]      frame_m12_w;

    integer                 capture_base_v;
    integer                 lane_idx_v;
    integer                 beat_lane_count_v;
    integer                 next_out_x_v;
    integer                 next_out_y_v;
    integer                 sample_addr_v;
    reg  [MAX_LANES-1:0]    prep_keep_w;
    reg  [MAX_LANES-1:0]    prep_sample_valid_w;
    reg  [MAX_LANES*ADDR_W-1:0] prep_sample_addr_w;
    reg                     prep_sof_w;
    reg                     prep_eol_w;
    reg                     prep_eof_w;
    reg  [15:0]             lane_out_x_r;
    reg  signed [47:0]      src_x_fixed_r;
    reg  signed [47:0]      src_y_fixed_r;
    reg  signed [31:0]      src_x_int_r;
    reg  signed [31:0]      src_y_int_r;

    assign frame_start_commit_w = s_valid && s_ready && s_sof;
    assign pipe_advance_w       = (~m_valid) || m_ready;
    assign s_ready              = (state_q == ST_CAPTURE);
    assign s_fire_w             = s_valid && s_ready && (|s_keep);

    frame_latched_affine6_s16 u_frame_latched_affine6_s16 (
        .clk              (clk),
        .rst_n            (rst_n),
        .cfg_valid        (cfg_valid),
        .cfg_ready        (cfg_ready),
        .cfg_m00          (cfg_m00),
        .cfg_m01          (cfg_m01),
        .cfg_m02          (cfg_m02),
        .cfg_m10          (cfg_m10),
        .cfg_m11          (cfg_m11),
        .cfg_m12          (cfg_m12),
        .frame_start_pulse(frame_start_commit_w),
        .active_m00       (active_m00),
        .active_m01       (active_m01),
        .active_m02       (active_m02),
        .active_m10       (active_m10),
        .active_m11       (active_m11),
        .active_m12       (active_m12),
        .frame_m00        (frame_m00_w),
        .frame_m01        (frame_m01_w),
        .frame_m02        (frame_m02_w),
        .frame_m10        (frame_m10_w),
        .frame_m11        (frame_m11_w),
        .frame_m12        (frame_m12_w)
    );

    always @* begin
        if (out_x_q >= IMG_WIDTH) begin
            beat_lane_count_v = 0;
        end else begin
            beat_lane_count_v = IMG_WIDTH - out_x_q;
        end
        if (beat_lane_count_v > MAX_LANES) begin
            beat_lane_count_v = MAX_LANES;
        end

        prep_keep_w         = {MAX_LANES{1'b0}};
        prep_sample_valid_w = {MAX_LANES{1'b0}};
        prep_sample_addr_w  = {MAX_LANES*ADDR_W{1'b0}};
        prep_sof_w          = (out_x_q == 16'd0) && (out_y_q == 16'd0);
        prep_eol_w          = ((out_x_q + beat_lane_count_v) >= IMG_WIDTH);
        prep_eof_w          = (out_y_q == (IMG_HEIGHT - 1)) && prep_eol_w;

        for (lane_idx_v = 0; lane_idx_v < MAX_LANES; lane_idx_v = lane_idx_v + 1) begin
            if (lane_idx_v < beat_lane_count_v) begin
                prep_keep_w[lane_idx_v] = 1'b1;
                lane_out_x_r = out_x_q + lane_idx_v[15:0];
                src_x_fixed_r = ($signed(frame_m00_w) * $signed({1'b0, lane_out_x_r})) +
                                ($signed(frame_m01_w) * $signed({1'b0, out_y_q})) +
                                ($signed(frame_m02_w) <<< 8);
                src_y_fixed_r = ($signed(frame_m10_w) * $signed({1'b0, lane_out_x_r})) +
                                ($signed(frame_m11_w) * $signed({1'b0, out_y_q})) +
                                ($signed(frame_m12_w) <<< 8);
                src_x_int_r   = src_x_fixed_r >>> 8;
                src_y_int_r   = src_y_fixed_r >>> 8;

                if ((src_x_int_r >= 0) &&
                    (src_x_int_r < IMG_WIDTH) &&
                    (src_y_int_r >= 0) &&
                    (src_y_int_r < IMG_HEIGHT)) begin
                    sample_addr_v = (src_y_int_r * IMG_WIDTH) + src_x_int_r;
                    prep_sample_valid_w[lane_idx_v] = 1'b1;
                    prep_sample_addr_w[lane_idx_v*ADDR_W +: ADDR_W] = sample_addr_v[ADDR_W-1:0];
                end
            end
        end

        if (prep_eol_w) begin
            next_out_x_v = 0;
            next_out_y_v = out_y_q + 1;
        end else begin
            next_out_x_v = out_x_q + beat_lane_count_v;
            next_out_y_v = out_y_q;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q            <= ST_CAPTURE;
            prep_valid_q       <= 1'b0;
            capture_count_q    <= {ADDR_W{1'b0}};
            out_x_q            <= 16'd0;
            out_y_q            <= 16'd0;
            prep_keep_q        <= {MAX_LANES{1'b0}};
            prep_sample_valid_q<= {MAX_LANES{1'b0}};
            prep_sample_addr_q <= {MAX_LANES*ADDR_W{1'b0}};
            prep_sof_q         <= 1'b0;
            prep_eol_q         <= 1'b0;
            prep_eof_q         <= 1'b0;
            prep_next_out_x_q  <= 16'd0;
            prep_next_out_y_q  <= 16'd0;
            m_valid            <= 1'b0;
            m_data             <= {MAX_LANES*24{1'b0}};
            m_keep             <= {MAX_LANES{1'b0}};
            m_sof              <= 1'b0;
            m_eol              <= 1'b0;
            m_eof              <= 1'b0;
        end else begin
            if (s_fire_w) begin
                capture_base_v = s_sof ? 0 : capture_count_q;
                for (lane_idx_v = 0; lane_idx_v < MAX_LANES; lane_idx_v = lane_idx_v + 1) begin
                    if (s_keep[lane_idx_v]) begin
                        frame_mem[capture_base_v + lane_idx_v] <= s_data[lane_idx_v*24 +: 24];
                    end
                end

                if (s_eof) begin
                    state_q         <= ST_OUTPUT;
                    prep_valid_q    <= 1'b0;
                    capture_count_q <= {ADDR_W{1'b0}};
                    out_x_q         <= 16'd0;
                    out_y_q         <= 16'd0;
                end else begin
                    capture_count_q <= capture_base_v + popcount_keep(s_keep);
                end
            end

            if ((state_q == ST_OUTPUT) && !prep_valid_q && (beat_lane_count_v > 0)) begin
                prep_valid_q        <= 1'b1;
                prep_keep_q         <= prep_keep_w;
                prep_sample_valid_q <= prep_sample_valid_w;
                prep_sample_addr_q  <= prep_sample_addr_w;
                prep_sof_q          <= prep_sof_w;
                prep_eol_q          <= prep_eol_w;
                prep_eof_q          <= prep_eof_w;
                prep_next_out_x_q   <= next_out_x_v[15:0];
                prep_next_out_y_q   <= next_out_y_v[15:0];
            end

            if (pipe_advance_w) begin
                if (state_q == ST_OUTPUT) begin
                    if (prep_valid_q) begin
                        m_valid <= 1'b1;
                        m_keep  <= prep_keep_q;
                        m_sof   <= prep_sof_q;
                        m_eol   <= prep_eol_q;
                        m_eof   <= prep_eof_q;
                        for (lane_idx_v = 0; lane_idx_v < MAX_LANES; lane_idx_v = lane_idx_v + 1) begin
                            if (prep_keep_q[lane_idx_v] && prep_sample_valid_q[lane_idx_v]) begin
                                m_data[lane_idx_v*24 +: 24] <= frame_mem[prep_sample_addr_q[lane_idx_v*ADDR_W +: ADDR_W]];
                            end else begin
                                m_data[lane_idx_v*24 +: 24] <= 24'h000000;
                            end
                        end
                        prep_valid_q <= 1'b0;

                        if (prep_eof_q) begin
                            state_q <= ST_CAPTURE;
                            out_x_q <= 16'd0;
                            out_y_q <= 16'd0;
                        end else begin
                            out_x_q <= prep_next_out_x_q;
                            out_y_q <= prep_next_out_y_q;
                        end
                    end else begin
                        m_valid <= 1'b0;
                        m_data  <= {MAX_LANES*24{1'b0}};
                        m_keep  <= {MAX_LANES{1'b0}};
                        m_sof   <= 1'b0;
                        m_eol   <= 1'b0;
                        m_eof   <= 1'b0;
                    end
                end else begin
                    m_valid      <= 1'b0;
                    m_data       <= {MAX_LANES*24{1'b0}};
                    m_keep       <= {MAX_LANES{1'b0}};
                    m_sof        <= 1'b0;
                    m_eol        <= 1'b0;
                    m_eof        <= 1'b0;
                    prep_valid_q <= 1'b0;
                end
            end
        end
    end

endmodule
