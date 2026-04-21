`timescale 1ns / 1ps

// 对每个有效灰度窗口拍执行 3x3 中值滤波。
// 本模块不是把 9 个数一次性做完整排序，而是拆成 3 级更短的流水：
// 第 1 级：每一行 3 个数先各自排成 {最小, 中间, 最大}
// 第 2 级：从三行结果中提取 3 个最终候选值
// 第 3 级：对这 3 个候选值再取一次中值
// 这样做的目的，是把比较交换网络拆短，便于冲更高时钟。
module median3x3_stream_std #(
    parameter integer MAX_LANES = 1,
    parameter integer DATA_W    = 8
) (
    // 时钟与复位。
    input  wire                            clk,     // 处理时钟。
    input  wire                            rst_n,   // 低有效异步复位。

    // 上游标准流接口输入。
    input  wire                            s_valid, // 当前拍上游数据有效。
    output wire                            s_ready, // 当前拍本模块可接收输入。
    input  wire [MAX_LANES*DATA_W*9-1:0]   s_data,  // 3x3 输入窗口数据，lane0 放在最低位。
    input  wire [MAX_LANES-1:0]            s_keep,  // s_data 对应的每路有效掩码。
    input  wire                            s_sof,   // 一帧中第一个有效输入像素。
    input  wire                            s_eol,   // 当前行最后一个有效输入像素。
    input  wire                            s_eof,   // 当前帧最后一个有效输入像素。

    // 下游标准流接口输出。
    output reg                             m_valid, // 当前拍滤波输出有效。
    input  wire                            m_ready, // 下游当前拍可以接收输出。
    output reg  [MAX_LANES*DATA_W-1:0]     m_data,  // 中值滤波后的像素数据，lane0 放在最低位。
    output reg  [MAX_LANES-1:0]            m_keep,  // m_data 对应的每路有效掩码。
    output reg                             m_sof,   // 一帧中第一个有效输出像素。
    output reg                             m_eol,   // 当前行最后一个有效输出像素。
    output reg                             m_eof    // 当前帧最后一个有效输出像素。
);
    integer lane_idx;

    wire has_active_lane;   // 本拍至少有一路 lane 有效。
    wire out_ready;
    wire stg3_ready;
    wire stg2_ready;
    wire stg1_ready;

    // 第 1 级流水输出：
    // 把每一行 3 个像素分别排成 最小/中间/最大。
    reg                             stg1_valid;
    reg  [MAX_LANES*DATA_W*9-1:0]   stg1_rowsort;
    reg  [MAX_LANES-1:0]            stg1_keep;
    reg                             stg1_sof;
    reg                             stg1_eol;
    reg                             stg1_eof;

    // 第 2 级流水输出：
    // 由三行排序结果提取 3 个候选值：
    // max(row_min)、median(row_mid)、min(row_max)。
    reg                             stg2_valid;
    reg  [MAX_LANES*DATA_W*3-1:0]   stg2_candidates;
    reg  [MAX_LANES-1:0]            stg2_keep;
    reg                             stg2_sof;
    reg                             stg2_eol;
    reg                             stg2_eof;
    reg                             stg3_valid;
    reg  [MAX_LANES*DATA_W-1:0]     stg3_median;
    reg  [MAX_LANES-1:0]            stg3_keep;
    reg                             stg3_sof;
    reg                             stg3_eol;
    reg                             stg3_eof;

    // 三个组合块分别计算三段流水在“下一拍要写入”的数据。
    // 这样写的好处是：每一级做什么非常清楚，也便于后续继续切流水。
    reg [MAX_LANES*DATA_W*9-1:0] stg1_rowsort_comb;
    reg [MAX_LANES*DATA_W*3-1:0] stg2_candidates_comb;
    reg [MAX_LANES*DATA_W-1:0]   stg3_median_comb;

    // 读取 9 元窗口中第 tap_idx 个像素。
    // tap_idx=0 对应左上角，tap_idx=8 对应右下角。
    // 窗口下标关系为：
    // 0 1 2
    // 3 4 5
    // 6 7 8
    function [DATA_W-1:0] tap9;
        input [DATA_W*9-1:0] window;
        input integer tap_idx;
        begin
            tap9 = window[(8-tap_idx)*DATA_W +: DATA_W];
        end
    endfunction

    // 读取 3 元向量中第 tap_idx 个元素。
    // tap_idx=0 对应最高位元素，tap_idx=2 对应最低位元素。
    function [DATA_W-1:0] tap3;
        input [DATA_W*3-1:0] values;
        input integer tap_idx;
        begin
            tap3 = values[(2-tap_idx)*DATA_W +: DATA_W];
        end
    endfunction

    // 三数排序网络：
    // 只用 3 次比较交换，就把 a/b/c 排成 {最小, 中间, 最大}。
    // 这里是真正的“排序一次拿到三个结果”，不是分别求 min/mid/max 三遍。
    function [DATA_W*3-1:0] sort3_pack;
        input [DATA_W-1:0] a;
        input [DATA_W-1:0] b;
        input [DATA_W-1:0] c;
        reg [DATA_W-1:0] sort_a;
        reg [DATA_W-1:0] sort_b;
        reg [DATA_W-1:0] sort_c;
        reg [DATA_W-1:0] swap_tmp;
        begin
            sort_a = a;
            sort_b = b;
            sort_c = c;

            // 第 1 次比较交换：先保证 sort_a <= sort_b。
            if (sort_a > sort_b) begin
                swap_tmp = sort_a;
                sort_a = sort_b;
                sort_b = swap_tmp;
            end

            // 第 2 次比较交换：再保证 sort_b <= sort_c。
            if (sort_b > sort_c) begin
                swap_tmp = sort_b;
                sort_b = sort_c;
                sort_c = swap_tmp;
            end

            // 第 3 次比较交换：最后再检查一次 sort_a <= sort_b。
            // 做完这一步后，三个数就已经整体有序。
            if (sort_a > sort_b) begin
                swap_tmp = sort_a;
                sort_a = sort_b;
                sort_b = swap_tmp;
            end

            sort3_pack = {
                sort_a,
                sort_b,
                sort_c
            };
        end
    endfunction

    // 三数取最大值。
    function [DATA_W-1:0] max3;
        input [DATA_W-1:0] a;
        input [DATA_W-1:0] b;
        input [DATA_W-1:0] c;
        reg [DATA_W-1:0] max_ab;
        begin
            max_ab = (a > b) ? a : b;
            max3 = (max_ab > c) ? max_ab : c;
        end
    endfunction

    // 三数取最小值。
    function [DATA_W-1:0] min3;
        input [DATA_W-1:0] a;
        input [DATA_W-1:0] b;
        input [DATA_W-1:0] c;
        reg [DATA_W-1:0] min_ab;
        begin
            min_ab = (a < b) ? a : b;
            min3 = (min_ab < c) ? min_ab : c;
        end
    endfunction

    // 三数取中值（只返回中值，不返回完整排序向量）。
    function [DATA_W-1:0] median3_from3;
        input [DATA_W-1:0] a;
        input [DATA_W-1:0] b;
        input [DATA_W-1:0] c;
        reg [DATA_W-1:0] x;
        reg [DATA_W-1:0] y;
        reg [DATA_W-1:0] z;
        reg [DATA_W-1:0] swap_tmp;
        begin
            x = a;
            y = b;
            z = c;
            if (x > y) begin
                swap_tmp = x;
                x = y;
                y = swap_tmp;
            end
            if (y > z) begin
                swap_tmp = y;
                y = z;
                z = swap_tmp;
            end
            if (x > y) begin
                swap_tmp = x;
                x = y;
                y = swap_tmp;
            end
            median3_from3 = y;
        end
    endfunction

    // 第 1 级算法核心：
    // 对 3x3 窗口的三行分别做一次三数排序。
    // 例如：
    // [a0 a1 a2] -> [amin amid amax]
    // [b0 b1 b2] -> [bmin bmid bmax]
    // [c0 c1 c2] -> [cmin cmid cmax]
    // 经过这一步后，后级就不用再反复在整 9 个数里乱比大小了。
    function [DATA_W*9-1:0] sort_window_rows;
        input [DATA_W*9-1:0] window;
        reg [DATA_W*3-1:0] row0_sorted;
        reg [DATA_W*3-1:0] row1_sorted;
        reg [DATA_W*3-1:0] row2_sorted;
        begin
            row0_sorted = sort3_pack(
                tap9(window, 0),
                tap9(window, 1),
                tap9(window, 2)
            );
            row1_sorted = sort3_pack(
                tap9(window, 3),
                tap9(window, 4),
                tap9(window, 5)
            );
            row2_sorted = sort3_pack(
                tap9(window, 6),
                tap9(window, 7),
                tap9(window, 8)
            );

            // 打包顺序仍然保持为：
            // {第1行最小/中值/最大, 第2行最小/中值/最大, 第3行最小/中值/最大}
            sort_window_rows = {row0_sorted, row1_sorted, row2_sorted};
        end
    endfunction

    // 第 2 级算法核心：
    // 从三行排序结果里提取 3 个候选值：
    // 1. max(行最小值)
    // 2. median(行中值)
    // 3. min(行最大值)
    // 到这里，原来 9 个数的信息被压缩成 3 个候选值，下一拍只需要再做一次三数中值。
    function [DATA_W*3-1:0] extract_median_candidates;
        input [DATA_W*9-1:0] rowsort;
        reg [DATA_W-1:0] cand_max_of_min;
        reg [DATA_W-1:0] cand_med_of_mid;
        reg [DATA_W-1:0] cand_min_of_max;
        begin
            cand_max_of_min = max3(
                tap9(rowsort, 0),
                tap9(rowsort, 3),
                tap9(rowsort, 6)
            );
            cand_med_of_mid = median3_from3(
                tap9(rowsort, 1),
                tap9(rowsort, 4),
                tap9(rowsort, 7)
            );
            cand_min_of_max = min3(
                tap9(rowsort, 2),
                tap9(rowsort, 5),
                tap9(rowsort, 8)
            );

            extract_median_candidates = {
                cand_max_of_min, // 三个行最小值里的最大值
                cand_med_of_mid, // 三个行中值里的中间值
                cand_min_of_max  // 三个行最大值里的最小值
            };
        end
    endfunction

    // 第 3 级算法核心：
    // 对 3 个候选值再做一次三数排序，取其中间值，作为最终 3x3 中值结果。
    function [DATA_W-1:0] median_from_candidates;
        input [DATA_W*3-1:0] candidates;
        reg [DATA_W*3-1:0] candidates_sorted;
        begin
            candidates_sorted = sort3_pack(
                tap3(candidates, 0),
                tap3(candidates, 1),
                tap3(candidates, 2)
            );
            median_from_candidates = tap3(candidates_sorted, 1);
        end
    endfunction

    assign has_active_lane = |s_keep;
    // 三级流水的 ready 自后向前逐级传播：
    // 末级空闲或下游 ready -> 第 3 级可推进
    // 第 3 级可推进          -> 第 2 级可推进
    // 第 2 级可推进          -> 第 1 级可推进
    // 第 1 级可推进          -> 本模块可继续接收上游新窗口
    assign out_ready       = (~m_valid) | m_ready;
    assign stg3_ready      = (~stg3_valid) | out_ready;
    assign stg2_ready      = (~stg2_valid) | stg3_ready;
    assign stg1_ready      = (~stg1_valid) | stg2_ready;
    assign s_ready         = stg1_ready;

    // 第 1 级组合逻辑：
    // 先对窗口的三行分别做 3 点排序，输出三行各自的 min/mid/max。
    always @* begin
        stg1_rowsort_comb = {MAX_LANES*DATA_W*9{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (s_keep[lane_idx]) begin
                // s_keep=1 的 lane 才真正参与比较交换网络。
                stg1_rowsort_comb[lane_idx*DATA_W*9 +: DATA_W*9] =
                    sort_window_rows(s_data[lane_idx*DATA_W*9 +: DATA_W*9]);
            end
        end
    end

    // 第 2 级组合逻辑：
    // 由三行的 min/mid/max 提取最终 3 个候选值。
    always @* begin
        stg2_candidates_comb = {MAX_LANES*DATA_W*3{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg1_keep[lane_idx]) begin
                // lane 只要在上一级有效，这一级就从该 lane 的三行排序结果里提候选值。
                stg2_candidates_comb[lane_idx*DATA_W*3 +: DATA_W*3] =
                    extract_median_candidates(stg1_rowsort[lane_idx*DATA_W*9 +: DATA_W*9]);
            end
        end
    end

    // 第 3 级组合逻辑：
    // 对 3 个候选值再取一次中值，这就是 9 个数的最终中值。
    always @* begin
        stg3_median_comb = {MAX_LANES*DATA_W{1'b0}};
        for (lane_idx = 0; lane_idx < MAX_LANES; lane_idx = lane_idx + 1) begin
            if (stg2_keep[lane_idx]) begin
                // 无效 lane 在前两级已经被清空，这里只对有效 lane 输出最终结果。
                stg3_median_comb[lane_idx*DATA_W +: DATA_W] =
                    median_from_candidates(stg2_candidates[lane_idx*DATA_W*3 +: DATA_W*3]);
            end
        end
    end

    // 第 1 级寄存器：
    // 在 ready/valid 握手成立时锁存“按行排序”的结果，
    // 并把 keep/sof/eol/eof 一起带到下一级。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg1_valid   <= 1'b0;
            stg1_rowsort <= {MAX_LANES*DATA_W*9{1'b0}};
            stg1_keep    <= {MAX_LANES{1'b0}};
            stg1_sof     <= 1'b0;
            stg1_eol     <= 1'b0;
            stg1_eof     <= 1'b0;
        end else if (stg1_ready) begin
            stg1_valid <= s_valid && has_active_lane;
            if (s_valid && has_active_lane) begin
                stg1_rowsort <= stg1_rowsort_comb;
                stg1_keep    <= s_keep;
                stg1_sof     <= s_sof;
                stg1_eol     <= s_eol;
                stg1_eof     <= s_eof;
            end else begin
                stg1_rowsort <= {MAX_LANES*DATA_W*9{1'b0}};
                stg1_keep    <= {MAX_LANES{1'b0}};
                stg1_sof     <= 1'b0;
                stg1_eol     <= 1'b0;
                stg1_eof     <= 1'b0;
            end
        end
    end

    // 第 2 级寄存器：
    // 在后级允许推进时，锁存 3 个候选值和对齐后的元数据。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg2_valid      <= 1'b0;
            stg2_candidates <= {MAX_LANES*DATA_W*3{1'b0}};
            stg2_keep       <= {MAX_LANES{1'b0}};
            stg2_sof        <= 1'b0;
            stg2_eol        <= 1'b0;
            stg2_eof        <= 1'b0;
        end else if (stg2_ready) begin
            stg2_valid <= stg1_valid;
            if (stg1_valid) begin
                stg2_candidates <= stg2_candidates_comb;
                stg2_keep       <= stg1_keep;
                stg2_sof        <= stg1_sof;
                stg2_eol        <= stg1_eol;
                stg2_eof        <= stg1_eof;
            end else begin
                stg2_candidates <= {MAX_LANES*DATA_W*3{1'b0}};
                stg2_keep       <= {MAX_LANES{1'b0}};
                stg2_sof        <= 1'b0;
                stg2_eol        <= 1'b0;
                stg2_eof        <= 1'b0;
            end
        end
    end

    // 第 3 级寄存器：
    // 先锁存“候选中值结果”，缩短 stg2 -> m_out 的组合深度。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stg3_valid  <= 1'b0;
            stg3_median <= {MAX_LANES*DATA_W{1'b0}};
            stg3_keep   <= {MAX_LANES{1'b0}};
            stg3_sof    <= 1'b0;
            stg3_eol    <= 1'b0;
            stg3_eof    <= 1'b0;
        end else if (stg3_ready) begin
            stg3_valid <= stg2_valid;
            if (stg2_valid) begin
                stg3_median <= stg3_median_comb;
                stg3_keep   <= stg2_keep;
                stg3_sof    <= stg2_sof;
                stg3_eol    <= stg2_eol;
                stg3_eof    <= stg2_eof;
            end else begin
                stg3_median <= {MAX_LANES*DATA_W{1'b0}};
                stg3_keep   <= {MAX_LANES{1'b0}};
                stg3_sof    <= 1'b0;
                stg3_eol    <= 1'b0;
                stg3_eof    <= 1'b0;
            end
        end
    end

    // 第 4 级输出寄存器：
    // 在下游允许接收时输出最终中值结果。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_valid <= 1'b0;
            m_data  <= {MAX_LANES*DATA_W{1'b0}};
            m_keep  <= {MAX_LANES{1'b0}};
            m_sof   <= 1'b0;
            m_eol   <= 1'b0;
            m_eof   <= 1'b0;
        end else if (out_ready) begin
            m_valid <= stg3_valid;
            if (stg3_valid) begin
                m_data <= stg3_median;
                m_keep <= stg3_keep;
                m_sof  <= stg3_sof;
                m_eol  <= stg3_eol;
                m_eof  <= stg3_eof;
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
