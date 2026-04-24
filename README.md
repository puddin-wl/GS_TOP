# GS_TOP

GS_TOP 是一个 MATLAB DOE/GS 仿真项目，用于 `532 nm` 中心场、正入射、连续相位 DOE 的矩形平顶光设计与评估。

当前版本包含三层能力：

- 标准 GS 理想相位设计
- `DOE -> 场镜 -> 焦平面` 的系统传播评估
- `R_in` 与 `L1` 的参数扫描

## Current Model Scope

- 目标光斑：硬边矩形 `330 um × 120 um`
- 入射光束：高斯光，`5 mm @ 1/e^2`
- 默认波前：平面波，`R_in = Inf`
- 场镜：`JENar APTAline 429-532-339 AL`
- 焦距：`429 mm`
- 中心场、正入射
- 连续相位 DOE
- 不含 SLM
- 不含振镜离轴扫描
- 不含可制造多级相位和工艺容差

## Main Entry Points

- `gs_top_default_config.m`
  生成默认配置 `cfg`
- `gs_top_load_bgdata.m`
  读取 Spiricon `.bgData` 实测光斑文件，并提取像素标定、D4Sigma 束宽和图像矩阵
- `gs_top_run.m`
  跑一次完整设计与评估，并保存图表与 MAT 结果
- `gs_top_sweep.m`
  扫描 `R_in` 和 `L1`，输出趋势图和热图
- `run_tests.m`
  运行基础单元测试

## Quick Start

```matlab
cfg = gs_top_default_config();
result = gs_top_run(cfg);
```

运行容差扫描：

```matlab
cfg = gs_top_default_config();
sweep = gs_top_sweep(cfg);
```

导入实测高斯光斑：

```matlab
cfg = gs_top_default_config();
cfg.source.beam_measurement_path = 'D:/qq_shuju/xwechat_files/wxid_zvpqcwmfi4vf22_ec28/msg/file/2026-04/3037.bgData';
cfg.beam.use_measured_profile = true;
result = gs_top_run(cfg);
```

运行测试：

```matlab
results = run_tests();
```

## Output Metrics

程序固定输出以下指标：

- `50%` 等值线尺寸
- `13.5%` 等值线尺寸
- `13.5% -> 90%` 边缘过渡宽度
- ROI 内 RMS 非均匀性
- `Uniformity_score = (1 - std/mean) * 100%`
- ROI 衍射效率
- ROI 外能量泄漏
- 总输出效率
- 功率、单脉冲能量、峰值辐照度、fluence 报表

## External Inputs

当前项目已经对接以下外部资料口径：

- 光路图：
  输出口到第一反射镜 `150 mm`，
  第一反射镜到第二反射镜 `380 mm`，
  第二反射镜到扩束镜 `140 mm`，
  扩束镜到 DOE `70 mm`，
  DOE 到振镜 `150 mm`
- 场镜规格：
  焦距 `429 mm`，
  波长 `532 nm`，
  输入光束 `16 mm @ 1/e^2`，
  聚焦光斑 `26.9 um @ 1/e^2`
- Spiricon `.bgData` 测量：
  图像尺寸 `1928 × 1448`，
  像素标定 `3.69 um/pixel`，
  束宽基准 `D4Sigma`，
  近似 D4Sigma 束宽约 `2.008 mm × 1.930 mm`

## Default Acceptance Targets

- RMS 非均匀性 `<= 5%`
- ROI 衍射效率 `>= 95%`

如果默认参数下未达到门限，程序仍会输出最佳结果、完整指标和失败标记。
