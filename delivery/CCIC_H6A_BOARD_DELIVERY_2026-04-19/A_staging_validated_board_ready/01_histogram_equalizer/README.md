# 直方图均衡化

主模块：

- `histogram_equalizer_stream_std.v`

来源：

- `F:\codex\staging\ccic_h6a_algo\basic`

怎么用：

- 这是直接吃流式输入、直接吐流式输出的算法盒子
- 适合作为独立图像增强模块插在链路中

最少加这些文件：

- `rtl/histogram_equalizer_stream_std.v`

验证参考：

- `tb/tb_histogram_equalizer_stream_std.v`
- PASS marker: `tb_histogram_equalizer_stream_std passed.`

交接说明：

- 这是这包里最简单的一类，基本没有公共依赖压力
- 如果只是要先跑通一个上板算法，它适合做第一批
