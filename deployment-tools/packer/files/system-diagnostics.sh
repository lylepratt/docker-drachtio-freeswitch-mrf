#!/bin/bash

echo "=========================================="
echo "System Load & Performance Diagnostics"
echo "=========================================="
echo "Timestamp: $(date)"
echo ""

# System Load
echo "--- LOAD AVERAGE ---"
uptime
echo ""

# CPU Breakdown
echo "--- CPU UTILIZATION ---"
top -bn1 | head -3 | tail -1
echo ""

# Context Switches & Interrupts
echo "--- CONTEXT SWITCHES & INTERRUPTS (5 second average) ---"
vmstat 1 5 | tail -1 | awk '{printf "Context Switches/sec: %s\nInterrupts/sec: %s\nCPU: %s%% user, %s%% system, %s%% idle, %s%% iowait\n", $12, $11, $13, $14, $15, $16}'
echo ""

# Memory
echo "--- MEMORY ---"
free -h | grep -E "Mem|Swap"
echo ""

# Network Connections Summary
echo "--- NETWORK CONNECTIONS ---"
ss -s
echo ""

# TCP States Breakdown
echo "--- TCP CONNECTION STATES ---"
ss -ant | awk 'NR>1 {print $1}' | sort | uniq -c | sort -rn
echo ""

# Connections by Process
echo "--- CONNECTIONS BY PROCESS ---"
if command -v lsof &> /dev/null; then
    lsof -i -n 2>/dev/null | grep ESTABLISHED | awk '{print $1}' | sort | uniq -c | sort -rn | head -10
else
    echo "lsof not available"
fi
echo ""

# Top Processes by CPU
echo "--- TOP PROCESSES BY CPU ---"
ps aux --sort=-%cpu | head -11 | awk 'NR==1 || NR<=11 {printf "%-10s %5s %5s %s\n", $11, $3, $4, $2}'
echo ""

# Load Average Interpretation
echo "--- INTERPRETATION ---"
LOAD_1MIN=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
NCPU=$(nproc)

echo "CPUs: $NCPU"
echo "1-min Load: $LOAD_1MIN"

# Use awk for floating point comparison
LOAD_PER_CPU=$(awk "BEGIN {printf \"%.2f\", $LOAD_1MIN / $NCPU}")
echo "Load per CPU: $LOAD_PER_CPU"

if awk "BEGIN {exit !($LOAD_PER_CPU > 2)}"; then
    echo "Status: ⚠️  HIGH - System is heavily loaded"
elif awk "BEGIN {exit !($LOAD_PER_CPU > 1)}"; then
    echo "Status: ⚡ BUSY - Some queuing but may be normal for high-concurrency workloads"
else
    echo "Status: ✅ HEALTHY - Load is manageable"
fi

echo ""
echo "=========================================="