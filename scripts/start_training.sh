#!/bin/bash
# 设置环境变量
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# 设置 PyTorch 默认 dtype 为 float32 (MPS 不支持 float64)
export PYTORCH_ENABLE_MPS_FALLBACK=1

cd /Users/lijunchen/coding/allegro

# 启动训练并显示实时输出
nequip-train --config-path=/Users/lijunchen/coding/allegro/configs --config-name=dataset_1593_mps

