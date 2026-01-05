# Mac GPU (MPS) 支持说明

## 当前状态

**重要**: LibTorch C++ API **可能不支持** MPS (Metal Performance Shaders) 设备类型，即使 PyTorch Python API 支持 MPS。

这意味着：
- ✅ 在 Python 中使用 PyTorch 时，可以使用 `device='mps'` 进行 GPU 加速
- ❌ 在 LAMMPS 的 C++ 代码中使用 LibTorch 时，**可能无法直接使用 MPS**

## 已验证的事实

1. **PyTorch 2.8.0** 支持 MPS（在 Python 中）
2. **pair_allegro** 代码已修改以尝试支持 MPS
3. **LibTorch C++ API** 可能没有暴露 `torch::kMPS` 设备类型

## 测试步骤

### 1. 编译测试

尝试编译修改后的 LAMMPS：

```bash
cd /Users/lijunchen/coding/allegro/scripts
./compile_lammps_with_allegro.sh
```

如果编译失败，错误信息会显示 LibTorch 是否支持 MPS。

### 2. 运行时测试

如果编译成功，尝试使用 MPS：

```bash
export _NEQUIP_USE_MPS=1
export _NEQUIP_LOG_LEVEL=DEBUG
cd /Users/lijunchen/coding/allegro/comparison_DFT
./run.sh
```

检查日志中是否显示使用了 MPS 设备。

### 3. 检查实际使用的设备

查看日志文件：

```bash
grep -i "device\|MPS\|CUDA" log.mlp
```

## 替代方案

### 方案 1: 使用 CPU（当前默认）

如果不支持 MPS，代码会自动回退到 CPU：

```bash
# 强制使用 CPU（即使有 GPU 可用）
export _NEQUIP_FORCE_CPU=1
```

### 方案 2: 等待官方支持

LibTorch 可能在未来版本中添加 MPS 支持。关注：
- PyTorch GitHub issues
- LibTorch 发布说明

### 方案 3: 使用其他 GPU 加速

如果您的 Mac 有 NVIDIA GPU（较老的 Mac Pro），可以使用 CUDA。

## 性能对比

即使 LibTorch 不支持 MPS，CPU 模式仍然可以使用：
- Apple Silicon (M4) 的 CPU 性能很强
- 多线程 CPU 计算可能已经足够快
- ML 模型的推理通常在 CPU 上也能有不错的性能

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `_NEQUIP_USE_MPS` | 尝试使用 Mac GPU (MPS) | 未设置（使用 CPU） |
| `_NEQUIP_FORCE_CPU` | 强制使用 CPU | 未设置 |
| `_NEQUIP_LOG_LEVEL` | 日志级别（DEBUG/INFO） | INFO |

## 相关链接

- [PyTorch MPS 文档](https://pytorch.org/docs/stable/notes/mps.html)
- [LibTorch 文档](https://pytorch.org/cppdocs/)
- [pair_nequip_allegro 仓库](https://github.com/mir-group/pair_nequip_allegro)

