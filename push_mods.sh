#!/bin/bash
cd ~/recursion
git add upgrades/*.mod
git commit -m "Auto-upload recursion modules: $(date +'%Y-%m-%d %H:%M:%S')" 2>/dev/null
git push origin main 2>/dev/null
