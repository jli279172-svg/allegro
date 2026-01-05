#!/bin/bash
###############################################################################
# 测试 Mac GPU (MPS) 支持脚本
#
# 此脚本测试 LibTorch 是否支持 MPS 设备类型
###############################################################################

set -euo pipefail

echo "============================================================"
echo "Mac GPU (MPS) 支持测试"
echo "============================================================"
echo

# 检查 Python PyTorch MPS 支持
echo "1. 检查 Python PyTorch MPS 支持:"
python3 << 'EOF'
import torch
print(f"   PyTorch 版本: {torch.__version__}")
print(f"   MPS 可用: {torch.backends.mps.is_available()}")
print(f"   MPS 已编译: {torch.backends.mps.is_built()}")

if torch.backends.mps.is_available():
    print("   ✓ Python PyTorch 支持 MPS")
    try:
        x = torch.randn(10, 10, device='mps')
        y = torch.randn(10, 10, device='mps')
        z = torch.matmul(x, y)
        print("   ✓ MPS 计算测试成功")
    except Exception as e:
        print(f"   ✗ MPS 计算测试失败: {e}")
else:
    print("   ✗ Python PyTorch 不支持 MPS")
EOF

echo
echo "2. 检查 LibTorch C++ 支持:"
echo "   注意: LibTorch C++ API 可能不支持 MPS，即使 Python API 支持"
echo

# 创建简单的测试程序
TEST_DIR="/tmp/lammps_mps_test"
mkdir -p "$TEST_DIR"

cat > "$TEST_DIR/test_mps.cpp" << 'CPPEOF'
#include <torch/torch.h>
#include <iostream>

int main() {
    std::cout << "LibTorch 版本: " << TORCH_VERSION_MAJOR << "." << TORCH_VERSION_MINOR << std::endl;
    
    #ifdef __APPLE__
    std::cout << "运行在 macOS" << std::endl;
    
    #ifdef TORCH_ENABLE_MPS
        std::cout << "✓ TORCH_ENABLE_MPS 已定义" << std::endl;
        auto device = torch::kMPS;
        std::cout << "✓ MPS 设备类型可用" << std::endl;
        return 0;
    #else
        std::cout << "✗ TORCH_ENABLE_MPS 未定义" << std::endl;
        std::cout << "  LibTorch 可能不支持 MPS 设备类型" << std::endl;
        return 1;
    #endif
    
    #else
    std::cout << "非 macOS 系统" << std::endl;
    return 1;
    #endif
}
CPPEOF

echo "   测试程序已创建: $TEST_DIR/test_mps.cpp"
echo
echo "   要测试编译，需要:"
echo "   1. 找到 LibTorch 头文件路径"
echo "   2. 编译测试程序"
echo "   3. 检查是否支持 MPS"
echo
echo "   这需要在 LAMMPS 编译环境中进行实际测试"
echo

echo "============================================================"
echo "结论和建议"
echo "============================================================"
echo
echo "LibTorch C++ API 可能不支持 MPS 设备类型。"
echo
echo "建议:"
echo "  1. 先尝试编译修改后的 LAMMPS"
echo "  2. 如果编译失败，检查错误信息"
echo "  3. 如果编译成功但运行时出错，使用 CPU 模式:"
echo "     export _NEQUIP_FORCE_CPU=1"
echo "  4. CPU 模式在 Apple Silicon 上性能也很好"
echo

