#!/data/data/com.termux/files/usr/bin/bash
VERSION=1.0
echo "Executing recursive_example.mod - generating derivative modules..."
DERIV="$HOME/recursion/upgrades/derived_$(date +%s).mod"
echo -e "#!/data/data/com.termux/files/usr/bin/bash\nVERSION=1.0\necho 'Running derived module $DERIV'" > "$DERIV"
chmod +x "$DERIV"
