#!/bin/bash

# 模拟监控脚本
# 用法: ./monitor.sh [检查间隔秒数，默认30]

INTERVAL=${1:-30}
LOG_FILE="log.mlp"

echo "============================================================"
echo "Allegro 模拟监控系统"
echo "============================================================"
echo "检查间隔: ${INTERVAL}秒"
echo "日志文件: $LOG_FILE"
echo "============================================================"
echo ""
echo "按 Ctrl+C 停止监控"
echo ""

while true; do
    # 检查进程
    PID=$(pgrep -f "lmp.*in.mlp" | head -1)
    
    if [ -z "$PID" ]; then
        echo "[$(date '+%H:%M:%S')] ✗ 进程未运行"
        echo ""
        echo "模拟可能已完成或出错，请检查日志文件"
        break
    fi
    
    # 读取日志
    if [ -f "$LOG_FILE" ]; then
        # 提取最后的数据点
        LAST_DATA=$(grep -E "^[[:space:]]*[0-9]+" "$LOG_FILE" | tail -1)
        
        if [ -n "$LAST_DATA" ]; then
            STEP=$(echo "$LAST_DATA" | awk '{print $1}')
            TEMP=$(echo "$LAST_DATA" | awk '{print $2}')
            PE=$(echo "$LAST_DATA" | awk '{print $3}')
            KE=$(echo "$LAST_DATA" | awk '{print $4}')
            
            # 判断阶段和进度
            if [ "$STEP" -lt 500 ]; then
                PHASE="阶段0: NVE预放松"
                PROGRESS=$((STEP * 100 / 500))
            elif [ "$STEP" -lt 10500 ]; then
                PHASE="阶段1: 升温 (50K->300K)"
                PROGRESS=$(((STEP - 500) * 100 / 10000))
            elif [ "$STEP" -lt 30500 ]; then
                PHASE="阶段2: 平衡 (300K)"
                PROGRESS=$(((STEP - 10500) * 100 / 20000))
            else
                PHASE="阶段3: 生产 (300K)"
                PROGRESS=$(((STEP - 30500) * 100 / 40000))
            fi
            
            # 温度状态
            if (( $(echo "$TEMP > 500" | bc -l) )); then
                TEMP_STATUS="✗ 异常"
            elif (( $(echo "$TEMP < 40" | bc -l) )); then
                TEMP_STATUS="⚠ 偏低"
            elif (( $(echo "$TEMP > 45 && $TEMP < 350" | bc -l) )); then
                TEMP_STATUS="✓ 正常"
            else
                TEMP_STATUS="⚠ 注意"
            fi
            
            echo "[$(date '+%H:%M:%S')] PID: $PID | Step: $STEP | Temp: $TEMP K ($TEMP_STATUS)"
            echo "  阶段: $PHASE (进度: $PROGRESS%)"
            echo "  PE: $PE eV | KE: $KE eV"
        else
            # 检查是否在最小化
            if grep -q "minimize\|Per MPI rank memory" "$LOG_FILE"; then
                echo "[$(date '+%H:%M:%S')] PID: $PID | 正在进行能量最小化..."
            else
                echo "[$(date '+%H:%M:%S')] PID: $PID | 等待数据输出..."
            fi
        fi
    else
        echo "[$(date '+%H:%M:%S')] PID: $PID | 日志文件不存在"
    fi
    
    echo ""
    sleep "$INTERVAL"
done

