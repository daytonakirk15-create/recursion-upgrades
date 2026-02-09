import os, time, requests, threading, subprocess

# Paths
UPGRADE_DIR = "upgrades"
UPGRADE_LOG = "upgrade_log.txt"
GIT_REPO = "https://raw.githubusercontent.com/yourusername/your-repo/main/mods/"  # Replace with your repo

# Logging
def log_upgrade(event):
    with open(UPGRADE_LOG, "a") as f:
        f.write(f"{time.ctime()} — {event}\n")

# Execute .mod files
def execute_upgrade(file_path):
    try:
        with open(file_path, "r") as f:
            code = f.read()
        exec(code, globals())
        log_upgrade(f"Executed {file_path}")
        print(f"Executed {file_path}")
    except Exception as e:
        log_upgrade(f"Error executing {file_path}: {e}")
        print(f"Error executing {file_path}: {e}")

# Check local upgrades
def check_local_upgrades():
    if not os.path.exists(UPGRADE_DIR):
        os.makedirs(UPGRADE_DIR)
        log_upgrade("Created upgrade directory")
    for f in os.listdir(UPGRADE_DIR):
        if f.endswith(".mod"):
            print(f"Installing {f}...")
            execute_upgrade(os.path.join(UPGRADE_DIR, f))

# Pull upgrades from Git
def pull_remote_upgrades():
    files = ["sample.mod"]  # List of upgrade files in repo
    for f in files:
        url = GIT_REPO + f
        local_path = os.path.join(UPGRADE_DIR, f)
        try:
            r = requests.get(url)
            if r.status_code == 200:
                with open(local_path, "w") as file:
                    file.write(r.text)
                log_upgrade(f"Downloaded {f} from repo")
                print(f"Downloaded {f}")
            else:
                log_upgrade(f"Failed to download {f}: HTTP {r.status_code}")
        except Exception as e:
            log_upgrade(f"Error downloading {f}: {e}")

# Daemon thread for auto-upgrades
def auto_upgrade_daemon(interval=60):
    def loop():
        while True:
            pull_remote_upgrades()
            check_local_upgrades()
            time.sleep(interval)
    t = threading.Thread(target=loop, daemon=True)
    t.start()

# Main
if __name__ == "__main__":
    auto_upgrade_daemon()
    check_local_upgrades()
    print("Upgrade system active. Press Ctrl+C to stop.")
    while True:
        time.sleep(1)
