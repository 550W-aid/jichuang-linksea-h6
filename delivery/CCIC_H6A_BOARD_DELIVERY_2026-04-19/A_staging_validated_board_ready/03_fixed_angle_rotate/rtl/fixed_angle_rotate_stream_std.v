`timescale 1ns / 1ps

module fixed_angle_rotate_stream_std #(
    parameter integer MAX_LANES  = 8,
    parameter integer IMG_WIDTH  = 640,
    parameter integer IMG_HEIGHT = 480
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
    input  wire [1:0]                  cfg_angle_sel,
    output wire [1:0]                  active_angle_sel,
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

    function integer output_width_for_angle;
        input [1:0] angle_sel;
        begin
            if ((angle_sel == 2'd1) || (angle_sel == 2'd3)) begin
                output_width_for_angle = IMG_HEIGHT;
            end else begin
                output_width_for_angle = IMG_WIDTH;
            end
        end
    endfunction

    function integer output_height_for_angle;
        input [1:0] angle_sel;
        begin
            if ((angle_sel == 2'd1) || (angle_sel == 2'd3)) begin
                output_height_for_angle = IMG_WIDTH;
            end else begin
                output_height_for_angle = IMG_HEIGHT;
            end
        end
    endfunction

    function integer source_addr_for_angle;
        input [1:0] angle_sel;
        input integer out_x;
        input integer out_y;
        integer src_x;
        integer src_y;
        begin
            case (angle_sel)
                2'd1: begin
                    src_x = out_y;
                    src_y = IMG_HEIGHT - 1 - out_x;
                end
                2'd2: begin
                    src_x = IMG_WIDTH  - 1 - out_x;
                    src_y = IMG_HEIGHT - 1 - out_y;
                end
                2'd3: begin
                    src_x = IMG_WIDTH - 1 - out_y;
                    src_y = out_x;
                end
                default: begin
                    src_x = out_x;
                    src_y = out_y;
                end
            endcase

            source_addr_for_angle = (src_y * IMG_WIDTH) + src_x;
        end
    endfunction

    localparam integer PIXELS = IMG_WIDTH * IMG_HEIGHT;
    localparam integer ADDR_W = (PIXELS <= 1) ? 1 : clog2(PIXELS);
    localparam [0:0]   ST_CAPTURE = 1'b0;
    localparam [0:0]   ST_OUTPUT  = 1'b1;

    reg [0:0] state_q;
    reg       output_prime_q;
    reg       prep_valid_q;
    reg [ADDR_W-1:0] capture_count_q;
    reg [15:0]       out_x_q;
    reg [15:0]       out_y_q;
    reg [23:0]       frame_mem [0:PIXELS-1];

    reg [MAX_LANES*ADDR_W-1:0] prep_src_addr_q;
    reg [MAX_LANES-1:0]        prep_keep_q;
    reg                        prep_sof_q;
    reg                        prep_eol_q;
    reg                        prep_eof_q;
    reg [15:0]                 prep_next_out_x_q;
    reg [15:0]                 prep_next_out_y_q;

    wire [1:0] angle_active_w;
    wire [1:0] angle_frame_w;
    wire       frame_start_commit;
    wire       pipe_advance;
    wire       s_fire;

    integer lane_idx;
    integer capture_base;
    integer out_width_v;
    integer out_height_v;
    integer beat_lane_count_v;
    integer src_addr_v;
    integer next_out_x_v;
    integer next_out_y_v;
    reg [MAX_LANES-1:0]        prep_keep_w;
    reg [MAX_LANES*ADDR_W-1:0] prep_src_addr_w;
    reg                        prep_sof_w;
    reg                        prep_eol_w;
    reg                        prep_eof_w;

    assign frame_start_commit = s_valid && s_ready && s_sof;
    assign pipe_advance       = (~m_valid) || m_ready;
    assign s_ready            = (state_q == ST_CAPTURE);
    assign s_fire             = s_valid && s_ready && (|s_keep);
    assign active_angle_sel   = angle_active_w;

    frame_latched_u2 u_angle_latch (
        .clk              (clk),
        .rst_n            (rst_n),
        .cfg_valid        (cfg_valid),
        .cfg_ready        (cfg_ready),
        .cfg_data         (cfg_angle_sel),
        .frame_start_pulse(frame_start_commit),
        .active_data      (angle_active_w),
        .frame_data       (angle_frame_w)
    );

    always @* begin
        out_width_v       = output_width_for_angle(angle_active_w);
        out_height_v      = output_height_for_angle(angle_active_w);
        beat_lane_count_v = out_width_v - out_x_q;
        if (beat_lane_count_v > MAX_LANES) begin
            beat_lane_count_v = MAX_LANES;
        end
        if (beat_lane_count_v < 0) begin
            beat_lane_count_v = 0;
        end

        prep_keep_w     = {MAX_LANES{1'b0}};
        prep_src_addr_w = {MAX_LANES*ADDR_W{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (lane_idx < beat_lane_count_v) begin
                prep_keep_w[lane_idx] = 1'b1;
                src_addr_v = source_addr_for_angle(angle_active_w, out_x_q + lane_idx, out_y_q);
                prep_src_addr_w[lane_idx*ADDR_W +: ADDR_W] = src_addr_v[ADDR_W-1:0];
            end
        end

        prep_sof_w = (out_x_q == 0) && (out_y_q == 0);
        prep_eol_w = ((out_x_q + beat_lane_count_v) >= out_width_v);
        prep_eof_w = (out_y_q == (out_height_v - 1)) && prep_eol_w;

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
            state_q           <= ST_CAPTURE;
            output_prime_q    <= 1'b0;
            prep_valid_q      <= 1'b0;
            capture_count_q   <= {ADDR_W{1'b0}};
            out_x_q           <= 16'd0;
            out_y_q           <= 16'd0;
            prep_src_addr_q   <= {MAX_LANES*ADDR_W{1'b0}};
            prep_keep_q       <= {MAX_LANES{1'b0}};
            prep_sof_q        <= 1'b0;
            prep_eol_q        <= 1'b0;
            prep_eof_q        <= 1'b0;
            prep_next_out_x_q <= 16'd0;
            prep_next_out_y_q <= 16'd0;
            m_valid           <= 1'b0;
            m_data            <= {MAX_LANES*24{1'b0}};
            m_keep            <= {MAX_LANES{1'b0}};
            m_sof             <= 1'b0;
            m_eol             <= 1'b0;
            m_eof             <= 1'b0;
        end else begin
            if (s_fire) begin
                capture_base = s_sof ? 0 : capture_count_q;
                for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                    if (s_keep[lane_idx]) begin
                        frame_mem[capture_base + lane_idx] <= s_data[lane_idx*24 +: 24];
                    end
                end

                if (s_eof) begin
                    state_q         <= ST_OUTPUT;
                    output_prime_q  <= 1'b1;
                    prep_valid_q    <= 1'b0;
                    capture_count_q <= {ADDR_W{1'b0}};
                    out_x_q         <= 16'd0;
                    out_y_q         <= 16'd0;
                end else begin
                    capture_count_q <= capture_base + popcount_keep(s_keep);
                end
            end

            if ((state_q == ST_OUTPUT) && !output_prime_q && !prep_valid_q && (beat_lane_count_v > 0)) begin
                prep_valid_q      <= 1'b1;
                prep_src_addr_q   <= prep_src_addr_w;
                prep_keep_q       <= prep_keep_w;
                prep_sof_q        <= prep_sof_w;
                prep_eol_q        <= prep_eol_w;
                prep_eof_q        <= prep_eof_w;
                prep_next_out_x_q <= next_out_x_v[15:0];
                prep_next_out_y_q <= next_out_y_v[15:0];
            end

            if (pipe_advance) begin
                if (state_q == ST_OUTPUT) begin
                    if (output_prime_q) begin
                        m_valid        <= 1'b0;
                        m_data         <= {MAX_LANES*24{1'b0}};
                        m_keep         <= {MAX_LANES{1'b0}};
                        m_sof          <= 1'b0;
                        m_eol          <= 1'b0;
                        m_eof          <= 1'b0;
                        output_prime_q <= 1'b0;
                    end else if (prep_valid_q) begin
                        m_valid <= 1'b1;
                        m_keep  <= prep_keep_q;
                        m_sof   <= prep_sof_q;
                        m_eol   <= prep_eol_q;
                        m_eof   <= prep_eof_q;
                        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                            if (prep_keep_q[lane_idx]) begin
                                m_data[lane_idx*24 +: 24] <= frame_mem[prep_src_addr_q[lane_idx*ADDR_W +: ADDR_W]];
                            end else begin
                                m_data[lane_idx*24 +: 24] <= 24'd0;
                            end
                        end
                        prep_valid_q <= 1'b0;

                        if (prep_eof_q) begin
                            state_q        <= ST_CAPTURE;
                            output_prime_q <= 1'b0;
                            out_x_q        <= 16'd0;
                            out_y_q        <= 16'd0;
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
                    m_valid        <= 1'b0;
                    m_data         <= {MAX_LANES*24{1'b0}};
                    m_keep         <= {MAX_LANES{1'b0}};
                    m_sof          <= 1'b0;
                    m_eol          <= 1'b0;
                    m_eof          <= 1'b0;
                    output_prime_q <= 1'b0;
                    prep_valid_q   <= 1'b0;
                end
            end
        end
    end

endmodule
