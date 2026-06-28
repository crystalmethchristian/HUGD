#!/bin/bash
echo "Uninstalling Grafana Dashboard Stack..."
INSTALL_DIR="$HOME/grafana-dashboard"

if [ -f "$HOME/.config/systemd/user/grafana-dashboard.service" ]; then
    systemctl --user stop grafana-dashboard.service 2>/dev/null || true
    systemctl --user disable grafana-dashboard.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/grafana-dashboard.service"
    systemctl --user daemon-reload 2>/dev/null || true
fi

if [ -d "$INSTALL_DIR" ]; then
    if [ -x "$INSTALL_DIR/stop.sh" ]; then
        "$INSTALL_DIR/stop.sh"
    fi
    rm -rf "$INSTALL_DIR"
fi

echo "Uninstallation complete."
