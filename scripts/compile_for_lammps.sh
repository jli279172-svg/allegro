#!/usr/bin/env bash
# 将 Allegro 训练得到的 best.ckpt 编译为 LAMMPS 可用的模型文件

set -euo pipefail

ROOT="/Users/lijunchen/coding/allegro"
DEFAULT_CKPT="$ROOT/outputs/2025-12-23/10-46-15/best.ckpt"
DEFAULT_OUT="$ROOT/outputs/2025-12-23/10-46-15/lammps_allegro.nequip.pt2"

CKPT_PATH="${1:-$DEFAULT_CKPT}"
OUT_PATH="${2:-$DEFAULT_OUT}"
DEVICE="${3:-cuda}" # 可选: cpu 或 cuda

if ! command -v nequip-compile >/dev/null 2>&1; then
  echo "未找到 nequip-compile，请先执行: pip install nequip-allegro" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_PATH")"

nequip-compile \
  "$CKPT_PATH" \
  "$OUT_PATH" \
  --device "$DEVICE" \
  --mode aotinductor \
  --target pair_allegro

printf "编译完成，生成文件: %s\n" "$OUT_PATH"
printf "在 LAMMPS 中示例使用:\n  pair_style nequip\n  pair_coeff * * %s <元素1> <元素2> ...\n" "$OUT_PATH"

