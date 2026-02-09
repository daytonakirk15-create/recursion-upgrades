#!/bin/bash
RECURSION_DIR="$HOME/recursion"
UPG_DIR="$RECURSION_DIR/upgrades"
DYN_DIR="$RECURSION_DIR/dynamic_updates"
MODULE_DIR="$RECURSION_DIR/modules"
LOG_FILE="$RECURSION_DIR/recursion_log.txt"
EXEC_DB="$RECURSION_DIR/executed_db.txt"
PUSH_SCRIPT="$RECURSION_DIR/push_mods.sh"

execute_mod() {
    local file="$1"
    local base=$(basename "$file")
    local version="1.0"
    if grep -q "^$base==$version" "$EXEC_DB"; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - Skip $base (version $version already executed)" | tee -a "$LOG_FILE"
        return
    fi
    chmod +x "$file"
    "$file"
    echo "$base==$version" >> "$EXEC_DB"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Executed $base" | tee -a "$LOG_FILE"
}

run_cycle() {
    shopt -s nullglob
    for f in "$UPG_DIR"/*.mod; do execute_mod "$f"; done
    for f in "$DYN_DIR"/*.mod; do
        cp -u "$f" "$UPG_DIR/"
        execute_mod "$UPG_DIR/$(basename "$f")"
    done
    for f in "$MODULE_DIR"/*.mod; do
        cp -u "$f" "$UPG_DIR/"
        execute_mod "$UPG_DIR/$(basename "$f")"
    done
    if [ -x "$PUSH_SCRIPT" ]; then "$PUSH_SCRIPT"; fi
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Cycle complete" | tee -a "$LOG_FILE"
}

# === AUTO-CYCLE LOOP ===
if [[ "$1" != "--no-loop" ]]; then
    echo "Starting automatic 1-minute recursion cycles..."
    while true; do
        run_cycle
        sleep 60
    done
fi
