#!/bin/bash
# Run TIP3P and Allegro water simulations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Find LAMMPS - Updated for new compilation
TORCH_LIB="/Users/lijunchen/Library/Python/3.9/lib/python/site-packages/torch/lib"

# Priority order: new build > system install > PATH
if [ -f "/Users/lijunchen/lammps/lammps/build/lmp" ]; then
    LMP="/Users/lijunchen/lammps/lammps/build/lmp"
    echo "Using LAMMPS: $LMP"
    export DYLD_LIBRARY_PATH="$TORCH_LIB:${DYLD_LIBRARY_PATH:-}"
elif [ -f "$HOME/lammps/lammps/build/lmp" ]; then
    LMP="$HOME/lammps/lammps/build/lmp"
    echo "Using LAMMPS: $LMP"
    export DYLD_LIBRARY_PATH="$TORCH_LIB:${DYLD_LIBRARY_PATH:-}"
elif [ -f "$HOME/lammps_nequip/install/bin/lmp_mpi" ]; then
    LMP="$HOME/lammps_nequip/install/bin/lmp_mpi"
    echo "Using LAMMPS: $LMP"
    export DYLD_LIBRARY_PATH="$TORCH_LIB:${DYLD_LIBRARY_PATH:-}"
elif command -v lmp_mpi &> /dev/null; then
    LMP="lmp_mpi"
    echo "Using LAMMPS: $LMP (from PATH)"
    export DYLD_LIBRARY_PATH="$TORCH_LIB:${DYLD_LIBRARY_PATH:-}"
elif command -v lmp &> /dev/null; then
    LMP="lmp"
    echo "Using LAMMPS: $LMP (from PATH)"
    export DYLD_LIBRARY_PATH="$TORCH_LIB:${DYLD_LIBRARY_PATH:-}"
else
    echo "Error: LAMMPS not found"
    echo "Please ensure LAMMPS is compiled at: /Users/lijunchen/lammps/lammps/build/lmp"
    exit 1
fi

# Check data files
[ -f "data/water.data" ] || { echo "Error: data/water.data not found"; exit 1; }
[ -f "data/water_atomic.data" ] || { echo "Error: data/water_atomic.data not found"; exit 1; }

# Check model file
MODEL="../outputs/2025-12-23/10-46-15/lammps_allegro.nequip.pt2"
[ -f "$MODEL" ] || { echo "Error: Model file not found: $MODEL"; exit 1; }

echo "Running TIP3P simulation..."
$LMP -in in.tip3p > log.tip3p 2>&1

echo "Running Allegro simulation..."
$LMP -in in.mlp > log.mlp 2>&1

echo "Done! Results:"
echo "  TIP3P: data/rdf_tip3p.xvg"
echo "  Allegro: data/rdf_mlp.xvg"
echo ""
echo "Run: python3 plot.py"

