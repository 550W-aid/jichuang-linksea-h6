`timescale 1ns / 1ps

module hdr_luma_tonemap_stream_std #(
    parameter integer MAX_LANES = 8
) (
    input  wire                        clk,                 // Processing clock.
    input  wire                        rst_n,               // Active-low reset.
    input  wire                        s_valid,             // Input beat valid.
    output wire                        s_ready,             // Input beat ready.
    input  wire [MAX_LANES*24-1:0]     s_data,              // Input YCbCr444 stream data.
    input  wire [MAX_LANES-1:0]        s_keep,              // Input lane keep mask.
    input  wire                        s_sof,               // Input start-of-frame marker.
    input  wire                        s_eol,               // Input end-of-line marker.
    input  wire                        s_eof,               // Input end-of-frame marker.
    input  wire [1:0]                  shadow_level,        // Shadow lift level for current frame.
    input  wire [1:0]                  highlight_level,     // Highlight compression level for current frame.
    output reg                         m_valid,             // Output beat valid.
    input  wire                        m_ready,             // Output beat ready.
    output reg  [MAX_LANES*24-1:0]     m_data,              // Output YCbCr444 stream data.
    output reg  [MAX_LANES-1:0]        m_keep,              // Output lane keep mask.
    output reg                         m_sof,               // Output start-of-frame marker.
    output reg                         m_eol,               // Output end-of-line marker.
    output reg                         m_eof                // Output end-of-frame marker.
);

    localparam [7:0] SHADOW_PIVOT    = 8'd96;
    localparam [7:0] HIGHLIGHT_PIVOT = 8'd160;

    integer lane_idx;

    wire has_active_lane;                                  // Detect at least one active lane in this beat.
    wire stage2_ready;                                     // Output register stage can accept a new beat.
    wire stage1_ready;                                     // Shadow-lift stage can accept a new beat.
    wire stage0_ready;                                     // Input capture stage can accept a new beat.

    reg                         stage0_valid;              // Captured beat valid.
    reg  [MAX_LANES*24-1:0]     stage0_data;               // Captured beat payload.
    reg  [MAX_LANES-1:0]        stage0_keep;               // Captured lane keep mask.
    reg                         stage0_sof;                // Captured SOF marker.
    reg                         stage0_eol;                // Captured EOL marker.
    reg                         stage0_eof;                // Captured EOF marker.
    reg  [1:0]                  stage0_shadow_level;       // Captured frame shadow level.
    reg  [1:0]                  stage0_highlight_level;    // Captured frame highlight level.

    reg                         stage1_valid;              // Shadow-lift stage valid.
    reg  [MAX_LANES*24-1:0]     stage1_data;               // Shadow-lift stage data.
    reg  [MAX_LANES-1:0]        stage1_keep;               // Shadow-lift stage keep.
    reg                         stage1_sof;                // Shadow-lift stage SOF.
    reg                         stage1_eol;                // Shadow-lift stage EOL.
    reg                         stage1_eof;                // Shadow-lift stage EOF.
    reg  [1:0]                  stage1_highlight_level;    // Shadow-lift stage highlight level.

    function [7:0] apply_shadow_lift;                     // Stage-1 shadow lift curve.
        input [7:0] in_y;
        input [1:0] in_level;
        reg [8:0] shadow_delta;
        reg [8:0] shadow_lift;
        reg [8:0] y_lifted;
        reg [1:0] shift_sel;
        begin
            if (in_y < SHADOW_PIVOT) begin
                shadow_delta = SHADOW_PIVOT - in_y;
            end else begin
                shadow_delta = 9'd0;
            end

            shift_sel = 2'd3 - in_level;
            case (shift_sel)
                2'd0: shadow_lift = shadow_delta;
                2'd1: shadow_lift = shadow_delta >> 1;
                2'd2: shadow_lift = shadow_delta >> 2;
                default: shadow_lift = shadow_delta >> 3;
            endcase

            y_lifted = {1'b0, in_y} + shadow_lift;
            if (y_lifted > 9'd255) begin
                y_lifted = 9'd255;
            end

            apply_shadow_lift = y_lifted[7:0];
        end
    endfunction

    function [7:0] apply_highlight_compress;              // Stage-2 highlight compression curve.
        input [7:0] in_y;
        input [1:0] in_level;
        reg [8:0] highlight_delta;
        reg [8:0] highlight_comp;
        reg [8:0] y_tonemapped;
        reg [1:0] shift_sel;
        begin
            if (in_y > HIGHLIGHT_PIVOT) begin
                highlight_delta = in_y - HIGHLIGHT_PIVOT;
            end else begin
                highlight_delta = 9'd0;
            end

            shift_sel = 2'd3 - in_level;
            case (shift_sel)
                2'd0: highlight_comp = highlight_delta;
                2'd1: highlight_comp = highlight_delta >> 1;
                2'd2: highlight_comp = highlight_delta >> 2;
                default: highlight_comp = highlight_delta >> 3;
            endcase

            if (highlight_comp >= {1'b0, in_y}) begin
                y_tonemapped = 9'd0;
            end else begin
                y_tonemapped = {1'b0, in_y} - highlight_comp;
            end

            apply_highlight_compress = y_tonemapped[7:0];
        end
    endfunction

    assign has_active_lane = |s_keep;
    assign stage2_ready    = (~m_valid) | m_ready;
    assign stage1_ready    = (~stage1_valid) | stage2_ready;
    assign stage0_ready    = (~stage0_valid) | stage1_ready;
    assign s_ready         = stage0_ready;

    always @(posedge clk or negedge rst_n) begin            // Three-stage stream pipeline with metadata alignment.
        if (!rst_n) begin
            stage0_valid           <= 1'b0;
            stage0_data            <= {MAX_LANES*24{1'b0}};
            stage0_keep            <= {MAX_LANES{1'b0}};
            stage0_sof             <= 1'b0;
            stage0_eol             <= 1'b0;
            stage0_eof             <= 1'b0;
            stage0_shadow_level    <= 2'd0;
            stage0_highlight_level <= 2'd0;
            stage1_valid           <= 1'b0;
            stage1_data            <= {MAX_LANES*24{1'b0}};
            stage1_keep            <= {MAX_LANES{1'b0}};
            stage1_sof             <= 1'b0;
            stage1_eol             <= 1'b0;
            stage1_eof             <= 1'b0;
            stage1_highlight_level <= 2'd0;
            m_valid                <= 1'b0;
            m_data                 <= {MAX_LANES*24{1'b0}};
            m_keep                 <= {MAX_LANES{1'b0}};
            m_sof                  <= 1'b0;
            m_eol                  <= 1'b0;
            m_eof                  <= 1'b0;
        end else begin
            if (stage2_ready) begin
                m_valid <= stage1_valid;
                if (stage1_valid) begin
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (stage1_keep[lane_idx]) begin
                            m_data[lane_idx*24 +: 24] <= {
                                apply_highlight_compress(
                                    stage1_data[lane_idx*24 + 16 +: 8],
                                    stage1_highlight_level
                                ),
                                stage1_data[lane_idx*24 + 8 +: 8],
                                stage1_data[lane_idx*24 +: 8]
                            };
                        end else begin
                            m_data[lane_idx*24 +: 24] <= 24'd0;
                        end
                    end
                    m_keep <= stage1_keep;
                    m_sof  <= stage1_sof;
                    m_eol  <= stage1_eol;
                    m_eof  <= stage1_eof;
                end else begin
                    m_data <= {MAX_LANES*24{1'b0}};
                    m_keep <= {MAX_LANES{1'b0}};
                    m_sof  <= 1'b0;
                    m_eol  <= 1'b0;
                    m_eof  <= 1'b0;
                end
            end

            if (stage1_ready) begin
                stage1_valid <= stage0_valid;
                if (stage0_valid) begin
                    for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
                        if (stage0_keep[lane_idx]) begin
                            stage1_data[lane_idx*24 +: 24] <= {
                                apply_shadow_lift(
                                    stage0_data[lane_idx*24 + 16 +: 8],
                                    stage0_shadow_level
                                ),
                                stage0_data[lane_idx*24 + 8 +: 8],
                                stage0_data[lane_idx*24 +: 8]
                            };
                        end else begin
                            stage1_data[lane_idx*24 +: 24] <= 24'd0;
                        end
                    end
                    stage1_keep            <= stage0_keep;
                    stage1_sof             <= stage0_sof;
                    stage1_eol             <= stage0_eol;
                    stage1_eof             <= stage0_eof;
                    stage1_highlight_level <= stage0_highlight_level;
                end else begin
                    stage1_data            <= {MAX_LANES*24{1'b0}};
                    stage1_keep            <= {MAX_LANES{1'b0}};
                    stage1_sof             <= 1'b0;
                    stage1_eol             <= 1'b0;
                    stage1_eof             <= 1'b0;
                    stage1_highlight_level <= 2'd0;
                end
            end

            if (stage0_ready) begin
                stage0_valid <= s_valid && has_active_lane;
                if (s_valid && has_active_lane) begin
                    stage0_data            <= s_data;
                    stage0_keep            <= s_keep;
                    stage0_sof             <= s_sof;
                    stage0_eol             <= s_eol;
                    stage0_eof             <= s_eof;
                    stage0_shadow_level    <= shadow_level;
                    stage0_highlight_level <= highlight_level;
                end else begin
                    stage0_data            <= {MAX_LANES*24{1'b0}};
                    stage0_keep            <= {MAX_LANES{1'b0}};
                    stage0_sof             <= 1'b0;
                    stage0_eol             <= 1'b0;
                    stage0_eof             <= 1'b0;
                    stage0_shadow_level    <= 2'd0;
                    stage0_highlight_level <= 2'd0;
                end
            end
        end
    end

endmodule
