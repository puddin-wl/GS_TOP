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
- 场镜：`HPFT-532-14-420-396`
- 焦距：`420 mm`
- 中心场、正入射
- 连续相位 DOE
- 不含 SLM
- 不含振镜离轴扫描
- 不含可制造多级相位和工艺容差

## Main Entry Points

- `gs_top_default_config.m`
  生成默认配置 `cfg`
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

## Default Acceptance Targets

- RMS 非均匀性 `<= 5%`
- ROI 衍射效率 `>= 95%`

如果默认参数下未达到门限，程序仍会输出最佳结果、完整指标和失败标记。
