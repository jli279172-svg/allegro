#!/bin/bash
# Check Allegro simulation status

cd "$(dirname "$0")"

echo "============================================================"
echo "Allegro Simulation Status"
echo "============================================================"
echo ""

# Check if running (updated for new LAMMPS path)
if pgrep -f "lmp.*in.mlp|lammps.*in.mlp" > /dev/null; then
    PID=$(pgrep -f "lmp.*in.mlp|lammps.*in.mlp" | head -1)
    RUNTIME=$(ps -p $PID -o etime= 2>/dev/null | xargs)
    echo "✓ Status: Running"
    echo "  Process ID: $PID"
    echo "  Runtime: $RUNTIME"
else
    echo "✗ Status: Not running"
fi

echo ""

# Get current step
if [ -f "log.mlp" ]; then
    CURRENT_STEP=$(tail -200 log.mlp 2>/dev/null | grep -E "^[[:space:]]*[0-9]+[[:space:]]" | tail -1 | awk '{print $1}')
    
    if [ -n "$CURRENT_STEP" ]; then
        echo "Current Step: $CURRENT_STEP"
        echo ""
        
        # Calculate progress
        # Total steps: 10000 (heating) + 20000 (equilibration) + 40000 (production) = 70000
        TOTAL_STEPS=70000
        OVERALL_PROGRESS=$((CURRENT_STEP * 100 / TOTAL_STEPS))
        
        if [ "$CURRENT_STEP" -lt 10000 ]; then
            PHASE="阶段1: 升温 (5 ps, 0-10000步)"
            PHASE_PROGRESS=$((CURRENT_STEP * 100 / 10000))
            REMAINING=$((10000 - CURRENT_STEP))
        elif [ "$CURRENT_STEP" -lt 30000 ]; then
            PHASE="阶段2: 平衡 (10 ps, 10000-30000步)"
            PHASE_PROGRESS=$(((CURRENT_STEP - 10000) * 100 / 20000))
            REMAINING=$((30000 - CURRENT_STEP))
        elif [ "$CURRENT_STEP" -lt 70000 ]; then
            PHASE="阶段3: 生产采样 (20 ps, 30000-70000步)"
            PHASE_PROGRESS=$(((CURRENT_STEP - 30000) * 100 / 40000))
            REMAINING=$((70000 - CURRENT_STEP))
        else
            PHASE="已完成"
            PHASE_PROGRESS=100
            REMAINING=0
        fi
        
        echo "Overall Progress: ${OVERALL_PROGRESS}% (${CURRENT_STEP}/${TOTAL_STEPS} steps)"
        echo "Phase: $PHASE"
        echo "Phase Progress: ${PHASE_PROGRESS}%"
        echo "Remaining steps: $REMAINING"
        echo ""
        
        # Show latest data
        echo "Latest data:"
        tail -200 log.mlp 2>/dev/null | grep -E "^[[:space:]]*[0-9]+[[:space:]]" | tail -1 | \
            awk '{printf "  Step: %d, Temp: %.1f K, PotEng: %.2f eV, Press: %.0f bar\n", $1, $2, $3, $6}'
    else
        echo "No step data found in log"
    fi
else
    echo "Log file not found"
fi

echo ""

