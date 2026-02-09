#!/data/data/com.termux/files/usr/bin/bash
# full_setup.sh - fully integrated recursion engine installer

echo "=== Recursion Engine Full Setup Starting ==="

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

# Make directories
mkdir -p "$UPG_DIR" "$DYN_DIR" "$BK_DIR" "$(dirname "$BOOT_SCRIPT")"

# Logging helper
log(){ echo "$(date '+%F %T') - $1" | tee -a "$LOG_FILE"; }

# Setup SSH folder if missing
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key if none exists
if [ ! -f ~/.ssh/id_ed25519 ]; then
  echo "Generating SSH key..."
  ssh-keygen -t ed25519 -C "your_email@example.com" -f ~/.ssh/id_ed25519 -N ""
fi

# Start ssh-agent and add key
eval $(ssh-agent)
ssh-add ~/.ssh/id_ed25519

# --- Setup Engine Script ---
cat > "$RECURSION_DIR/setup_engine.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
# setup_engine.sh - Full recursion engine installer & updater
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
declare -A EXEC
if [ -f "$EXEC_DB" ]; then
  while IFS='=' read -r fname meta; do EXEC["$fname"]="$meta"; done < "$EXEC_DB"
fi
save_exec_db(){ : > "$EXEC_DB"; for k in "${!EXEC[@]}"; do echo "$k=${EXEC[$k]}" >> "$EXEC_DB"; done; }
get_version(){ grep -m1 -E '^VERSION=' "$1" 2>/dev/null | cut -d'=' -f2 || echo ""; }
backup_module(){ local f="$1"; cp -a "$f" "$BK_DIR/$(basename "$f")_$(date +%s)" 2>/dev/null && log "Backed up $f"; }
rollback_module(){ local f="$1"; local last=$(ls -1t "$BK_DIR/${f}_"* 2>/dev/null | head -n1); [ -n "$last" ] && cp -a "$last" "$UPG_DIR/$f" && log "Rolled back $f from $(basename $last)"; }
execute_mod(){
  local f="$1"; [ -f "$f" ] || return
  local fn=$(basename "$f")
  local ver=$(get_version "$f")
  local now=$(date '+%F %T')
  if [ -n "${EXEC[$fn]}" ] && [ "$ver" = "${EXEC[$fn]%%|*}" ]; then log "Skip $fn (v$ver already executed)"; return; fi
  backup_module "$f"
  bash "$f"
  rc=$?
  if [ $rc -eq 0 ]; then EXEC["$fn"]="${ver}|$now"; save_exec_db; log "Executed $fn"; else log "Error $fn rc=$rc, rolling back"; rollback_module "$fn"; fi
}
fetch_remote_updates(){
  TMP=$(mktemp -d)
  log "Fetching remote updates..."
  if git clone --depth 1 "$GITHUB_REPO" "$TMP" >/dev/null 2>&1; then
    cp -u "$TMP"/*.mod "$DYN_DIR/" 2>/dev/null || true
    cp -u "$TMP"/upgrades/*.mod "$DYN_DIR/" 2>/dev/null || true
    log "Fetched remote .mod files"
  else log "Git clone failed"; fi
  rm -rf "$TMP"
}
generate_derivative(){ local name="derived_$(date +%s).mod"; local path="$UPG_DIR/$name"; echo -e "#!/data/data/com.termux/files/usr/bin/bash\nVERSION=1.0\necho 'Running $name'" > "$path"; chmod +x "$path"; log "Generated derivative $name"; }
run_cycle(){
  log "=== Starting cycle ==="
  fetch_remote_updates
  shopt -s nullglob
  for f in "$UPG_DIR"/*.mod; do execute_mod "$f"; done
  for f in "$DYN_DIR"/*.mod; do cp -u "$f" "$UPG_DIR/"; execute_mod "$UPG_DIR/$(basename $f)"; done
  for f in "$UPG_DIR"/derived_*.mod; do execute_mod "$f"; done
  shopt -u nullglob
  log "=== Cycle complete ==="
}
if ! ls "$UPG_DIR"/*.mod >/dev/null 2>&1; then
cat > "$UPG_DIR/sample.mod" <<'EOM'
#!/data/data/com.termux/files/usr/bin/bash
VERSION=1.0
echo "Hello from sample.mod"
EOM
chmod +x "$UPG_DIR/sample.mod"
cat > "$UPG_DIR/test_upgrade.mod" <<'EOM'
#!/data/data/com.termux/files/usr/bin/bash
VERSION=1.0
echo "Executing test_upgrade.mod"
EOM
chmod +x "$UPG_DIR/test_upgrade.mod"
log "Sample modules created"
fi
if [ "$1" = "--run-cycle" ]; then run_cycle; exit 0; fi
if [ "$1" = "--fetch-and-run" ]; then fetch_remote_updates; run_cycle; exit 0; fi
run_cycle
if ! pgrep -f "$CORE" >/dev/null 2>&1; then nohup bash "$CORE" >/dev/null 2>&1 & log "Core started in background"; fi
cat > "$BOOT_SCRIPT" <<'EOM'
#!/data/data/com.termux/files/usr/bin/bash
bash "$HOME/recursion/core.sh" &
EOM
chmod +x "$BOOT_SCRIPT"
log "Boot script installed"
EOF

chmod +x setup_engine.sh

# --- Core Daemon ---
cat > "$CORE" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
while true; do
  bash "$HOME/recursion/setup_engine.sh" --fetch-and-run
  sleep 3600
done
EOF
chmod +x core.sh

# Run one cycle to verify
bash setup_engine.sh --run-cycle

echo "=== Full Recursion Engine Setup Complete ==="
