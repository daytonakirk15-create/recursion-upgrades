import os
import time

LOG_FILE = "recursion_log.txt"

def log_event(event):
    with open(LOG_FILE, "a") as f:
        f.write(f"{time.ctime()} — {event}\n")

def self_check():
    print("Running self-check...")
    log_event("Self-check executed")

def upgrade_scan():
    print("Scanning for upgrades...")

    # Run the upgrade module loader
    if os.path.exists("upgrades/upgrade_module.py"):
        os.system("python upgrades/upgrade_module.py")
        log_event("Upgrade module executed")
    else:
        print("No upgrade module found.")
        log_event("Upgrade module missing")

def main_loop():
    while True:
        self_check()
        upgrade_scan()

        print("Cycle complete. Sleeping...\n")
        log_event("Cycle complete")

        time.sleep(60)

if __name__ == "__main__":
    main_loop()
