#!/bin/bash
# recursion full installer
# Creates full recursion engine with brain + derivative modules, logging, auto-push

# ----------------------
# CONFIG
# ----------------------
RECURSION_DIR="$HOME/recursion"
UPG_DIR="$RECURSION_DIR/upgrades"
DYN_DIR="$RECURSION_DIR/dynamic_updates"
BK_DIR="$RECURSION_DIR/backups"
MODULE_DIR="$RECURSION_DIR/modules"
LOG_FILE="$RECURSION_DIR/recursion_log.txt"
EXEC_DB="$RECURSION_DIR/executed_db.txt"
GITHUB_REPO="git@github.com:daytonakirk15-create/recursion-upgrades.git"
BRANCH="main"

# ----------------------
# DIR SETUP
# ----------------------
mkdir -p "$UPG_DIR" "$DYN_DIR" "$BK_DIR" "$MODULE_DIR"
touch "$LOG_FILE" "$EXEC_DB"

# ----------------------
# HELPER FUNCTIONS
# ----------------------
execute_mod() {
    local file="$1"
    local base=$(basename "$file")
    local version="1.0"
    
    # skip if already executed
    if grep -q "^$base==$version" "$EXEC_DB"; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - Skip $base (version $version already executed)" | tee -a "$LOG_FILE"
        return
    fi
    
    # execute
    chmod +x "$file"
    "$file"
    
    # log execution
    echo "$base==$version" >> "$EXEC_DB"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Executed $base" | tee -a "$LOG_FILE"
}

run_cycle() {
    shopt -s nullglob
    # execute upgrades
    for f in "$UPG_DIR"/*.mod; do
        execute_mod "$f"
    done
    # execute dynamic modules and copy to upgrades
    for f in "$DYN_DIR"/*.mod; do
        cp -u "$f" "$UPG_DIR/"
        execute_mod "$UPG_DIR/$(basename "$f")"
    done
    # execute modules folder
    for f in "$MODULE_DIR"/*.mod; do
        cp -u "$f" "$UPG_DIR/"
        execute_mod "$UPG_DIR/$(basename "$f")"
    done
    # push all changes
    if [ -x "$RECURSION_DIR/push_mods.sh" ]; then
        "$RECURSION_DIR/push_mods.sh"
    fi
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Cycle complete" | tee -a "$LOG_FILE"
}

# ----------------------
# CREATE BRAIN MODULE
# ----------------------
cat > "$MODULE_DIR/brain.mod" <<'EOF'
#!/bin/bash
# brain.mod - generates recursive prompts
echo "Module: brain.mod executed at $(date)" >> ~/recursion/recursion_log.txt
PROMPT="Generate a new idea for recursion module based on previous outputs."
echo "$PROMPT"
EOF
chmod +x "$MODULE_DIR/brain.mod"

# ----------------------
# CREATE DERIVE MODULE
# ----------------------
cat > "$MODULE_DIR/derive.mod" <<'EOF'
#!/bin/bash
# derive.mod - creates new modules
UPG_DIR="$HOME/recursion/upgrades"
OUTPUT="derived_$(date +%s).mod"
echo -e "#!/bin/bash\n# Auto-generated module\n echo \"Hello from $OUTPUT\" " > "$UPG_DIR/$OUTPUT"
chmod +x "$UPG_DIR/$OUTPUT"
echo "Generated $OUTPUT at $(date)" >> ~/recursion/recursion_log.txt
EOF
chmod +x "$MODULE_DIR/derive.mod"

# ----------------------
# CREATE PUSH SCRIPT
# ----------------------
cat > "$RECURSION_DIR/push_mods.sh" <<'EOF'
#!/bin/bash
cd ~/recursion
git add upgrades/*.mod
git commit -m "Auto-upload recursion modules: $(date +'%Y-%m-%d %H:%M:%S')" 2>/dev/null
git push origin main 2>/dev/null
EOF
chmod +x "$RECURSION_DIR/push_mods.sh"

# ----------------------
# INITIALIZE GIT IF NOT EXISTS
# ----------------------
cd "$RECURSION_DIR"
if [ ! -d ".git" ]; then
    git init
    git remote add origin "$GITHUB_REPO"
    git checkout -b "$BRANCH"
fi

echo "Recursion engine installed successfully!"
echo "Run cycles with:"
echo "bash $RECURSION_DIR/setup_engine.sh --run-cycle"

# ----------------------
# SETUP ENGINE SCRIPT
# ----------------------
cat > "$RECURSION_DIR/setup_engine.sh" <<'EOF'
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

if [[ "$1" == "--run-cycle" ]]; then run_cycle; fi
EOF

chmod +x "$RECURSION_DIR/setup_engine.sh"

echo "All modules, engine, and auto-push scripts installed."
