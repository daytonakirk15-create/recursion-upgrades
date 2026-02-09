#!/data/data/com.termux/files/usr/bin/bash
# setup_full_engine.sh - Complete Recursion Engine Installer & Upgrader

### CONFIG
RECURSION_DIR="$HOME/recursion"
UPG_DIR="$RECURSION_DIR/upgrades"
DYN_DIR="$RECURSION_DIR/dynamic_updates"
BK_DIR="$RECURSION_DIR/backups"
LOG_FILE="$RECURSION_DIR/recursion_log.txt"
EXEC_DB="$RECURSION_DIR/executed_db.txt"
CORE="$RECURSION_DIR/core.sh"
BOOT_SCRIPT="$HOME/.termux/boot/startup.sh"
GITHUB_REPO="git@github.com:daytonakirk15-create/recursion-upgrades.git"
FETCH_INTERVAL=3600

mkdir -p "$UPG_DIR" "$DYN_DIR" "$BK_DIR" "$(dirname "$BOOT_SCRIPT")"

log(){ echo "$(date '+%F %T') - $1" | tee -a "$LOG_FILE"; }

### EXECUTED MODULE DB
declare -A EXEC
if [ -f "$EXEC_DB" ]; then
  while IFS='=' read -r fname meta; do
    EXEC["$fname"]="$meta"
  done < "$EXEC_DB"
fi

save_exec_db(){
  : > "$EXEC_DB"
  for k in "${!EXEC[@]}"; do
    echo "$k=${EXEC[$k]}" >> "$EXEC_DB"
  done
}

get_version(){ grep -m1 '^VERSION=' "$1" 2>/dev/null | cut -d'=' -f2 || echo ""; }
backup_module(){ cp -a "$1" "$BK_DIR/$(basename $1)_$(date +%s)" 2>/dev/null; }
rollback_module(){ local last=$(ls -1t "$BK_DIR/${1}_"* 2>/dev/null | head -n1); [ -n "$last" ] && cp -a "$last" "$UPG_DIR/$1"; }

execute_mod(){
  local f="$1"; [ -f "$f" ] || return
  local fn=$(basename "$f")
  local ver=$(get_version "$f")
  local now=$(date '+%F %T')
  if [ -n "${EXEC[$fn]}" ]; then local recorded_ver=${EXEC[$fn]%%|*}; [ "$ver" = "$recorded_ver" ] && { log "Skip $fn (v$ver already executed)"; return; }; fi
  backup_module "$f"
  bash "$f"; rc=$?
  if [ $rc -eq 0 ]; then
    EXEC["$fn"]="${ver}|$now"; save_exec_db; log "Executed $fn"
  else
    log "Error executing $fn. Rolling back."; rollback_module "$fn"
  fi
}

### FETCH REMOTE UPDATES
fetch_updates(){
  [ -z "$GITHUB_REPO" ] && { log "No repo configured"; return; }
  TMP=$(mktemp -d)
  if git clone --depth 1 "$GITHUB_REPO" "$TMP" >/dev/null 2>&1; then
    cp -u "$TMP"/*.mod "$DYN_DIR/" 2>/dev/null || true
    cp -u "$TMP"/upgrades/*.mod "$DYN_DIR/" 2>/dev/null || true
    log "Fetched remote .mod files"
  else
    log "Git clone failed"
  fi
  rm -rf "$TMP"
}

### DERIVATIVE MODULE GENERATOR
generate_derivative(){
  local name="derived_$(date +%s).mod"
  cat > "$UPG_DIR/$name" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
VERSION=1.0
echo "Auto-derived module running: $0"
EOF
  chmod +x "$UPG_DIR/$name"
  log "Generated derivative $name"
}

### PUSH CHANGES BACK TO GITHUB
push_mods(){
  cd "$RECURSION_DIR"
  git add upgrades/*.mod 2>/dev/null
  if git diff --cached --quiet; then log "No changes to push"; return; fi
  git commit -m "Auto-upload recursion modules: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null || log "Commit failed"
  git push origin main 2>/dev/null && log "Pushed to GitHub" || log "Push failed"
}

### RUN CYCLE
run_cycle(){
  shopt -s nullglob
  for f in "$UPG_DIR"/*.mod; do execute_mod "$f"; done
  for f in "$DYN_DIR"/*.mod; do cp -u "$f" "$UPG_DIR/"; execute_mod "$UPG_DIR/$(basename $f)"; done
  for f in "$UPG_DIR"/derived_*.mod; do execute_mod "$f"; done
  shopt -u nullglob
  generate_derivative
  push_mods
  log "Cycle complete"
}

### CREATE CORE LOOP
cat > "$CORE" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
while true; do
  bash "$HOME/recursion/setup_full_engine.sh" --fetch-and-run
  sleep 3600
done
EOF
chmod +x "$CORE"

if [ "$1" = "--fetch-and-run" ]; then fetch_updates; run_cycle; exit 0; fi

### INITIAL RUN
fetch_updates; run_cycle
pgrep -f "$CORE" >/dev/null || nohup bash "$CORE" >/dev/null 2>&1 &

### BOOT SCRIPT
cat > "$BOOT_SCRIPT" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
bash "$HOME/recursion/core.sh" &
EOF
chmod +x "$BOOT_SCRIPT"
log "Setup finished. Use 'tail -f $LOG_FILE' to watch activity."
