#!/bin/bash
set -e

echo "=========================================="
echo " Grafana Hardware Dashboard Installer"
echo "=========================================="

INSTALL_DIR="$HOME/grafana-dashboard"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# OS Detection
OS="$(uname -s)"
case "$OS" in
    Linux*)     OS_NAME="linux";;
    Darwin*)    OS_NAME="darwin";;
    *)          echo "Unsupported OS: $OS"; exit 1;;
esac

# Architecture Detection
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)     ARCH_NAME="amd64"; ARCH_ALT="x86_64";;
    aarch64)    ARCH_NAME="arm64"; ARCH_ALT="arm64";;
    arm64)      ARCH_NAME="arm64"; ARCH_ALT="arm64";;
    armv7l)     ARCH_NAME="armv7"; ARCH_ALT="armv7";;
    *)          echo "Unsupported Architecture: $ARCH"; exit 1;;
esac

echo "Detected OS: $OS_NAME, Arch: $ARCH_NAME"

for cmd in tar curl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed. Please install it first."
        exit 1
    fi
done

echo "-> Creating installation directory at $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "-> Downloading Grafana v11.1.0..."
curl -sL "https://dl.grafana.com/oss/release/grafana-11.1.0.${OS_NAME}-${ARCH_NAME}.tar.gz" | tar -xz
mv grafana-v11.1.0 grafana

echo "-> Downloading Prometheus v2.53.0..."
curl -sL "https://github.com/prometheus/prometheus/releases/download/v2.53.0/prometheus-2.53.0.${OS_NAME}-${ARCH_NAME}.tar.gz" | tar -xz
mv prometheus-2.53.0.${OS_NAME}-${ARCH_NAME} prometheus

echo "-> Downloading Node Exporter v1.8.1..."
curl -sL "https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.${OS_NAME}-${ARCH_NAME}.tar.gz" | tar -xz
mv node_exporter-1.8.1.${OS_NAME}-${ARCH_NAME} node_exporter
mkdir -p node_exporter/textfile_collector

echo "-> Copying configuration files..."
cp -r "$REPO_DIR/config/"* "$INSTALL_DIR/"

mv "$INSTALL_DIR/prometheus.yml" "$INSTALL_DIR/prometheus/prometheus.yml"
mkdir -p "$INSTALL_DIR/grafana/conf/provisioning/datasources"
mkdir -p "$INSTALL_DIR/grafana/conf/provisioning/dashboards"
cp -r "$INSTALL_DIR/datasources/"* "$INSTALL_DIR/grafana/conf/provisioning/datasources/"
cp -r "$INSTALL_DIR/dashboards/"* "$INSTALL_DIR/grafana/conf/provisioning/dashboards/"
rm -rf "$INSTALL_DIR/datasources" "$INSTALL_DIR/dashboards"

# Inject the correct dashboard path for this specific machine
DASHBOARDS_PATH="$INSTALL_DIR/grafana/conf/provisioning/dashboards"
sed -i "s|DASHBOARDS_PATH_PLACEHOLDER|$DASHBOARDS_PATH|g" \
    "$INSTALL_DIR/grafana/conf/provisioning/dashboards/dashboards.yml"

# ==========================================
#  GPU DETECTION & EXPORTER INSTALL
# ==========================================
GPU_EXPORTER_ENABLED=false
AMD_TEXTFILE_ENABLED=false

if [ "$OS_NAME" = "linux" ]; then
    echo "-> Detecting GPU hardware..."

    if lspci 2>/dev/null | grep -qi "nvidia"; then
        echo "   NVIDIA GPU detected — installing nvidia_gpu_exporter v1.5.0..."
        curl -sL "https://github.com/utkuozdemir/nvidia_gpu_exporter/releases/download/v1.5.0/nvidia_gpu_exporter_1.5.0_linux_${ARCH_ALT}.tar.gz" | tar -xz
        # Move the binary into place
        find . -maxdepth 1 -name "nvidia_gpu_exporter" -type f -exec mv {} "$INSTALL_DIR/nvidia_gpu_exporter" \; 2>/dev/null || \
        find . -maxdepth 2 -name "nvidia_gpu_exporter" -type f -exec mv {} "$INSTALL_DIR/nvidia_gpu_exporter" \; 2>/dev/null
        chmod +x "$INSTALL_DIR/nvidia_gpu_exporter"
        GPU_EXPORTER_ENABLED=true
        echo "   nvidia_gpu_exporter installed. Metrics will appear on port 9835."

    elif lspci 2>/dev/null | grep -qi "amd\|radeon\|advanced micro" || ls /sys/class/drm/card*/device/gpu_busy_percent >/dev/null 2>&1; then
        echo "   AMD GPU/APU detected — setting up sysfs textfile collector..."
        AMD_TEXTFILE_ENABLED=true

        cat << 'AMDSCRIPT' > "$INSTALL_DIR/amd_gpu_metrics.sh"
#!/bin/bash
# AMD GPU sysfs textfile collector
# Writes Prometheus-format metrics from the kernel amdgpu driver to the Node Exporter textfile directory
TEXTFILE_DIR="$(dirname "$0")/node_exporter/textfile_collector"
mkdir -p "$TEXTFILE_DIR"
OUTPUT="$TEXTFILE_DIR/amd_gpu.prom"
echo "# HELP amd_gpu_temperature_celsius AMD GPU temperature in Celsius" > "$OUTPUT"
echo "# TYPE amd_gpu_temperature_celsius gauge" >> "$OUTPUT"
echo "# HELP amd_gpu_vram_used_bytes AMD GPU VRAM used in bytes" >> "$OUTPUT"
echo "# TYPE amd_gpu_vram_used_bytes gauge" >> "$OUTPUT"
echo "# HELP amd_gpu_vram_total_bytes AMD GPU VRAM total in bytes" >> "$OUTPUT"
echo "# TYPE amd_gpu_vram_total_bytes gauge" >> "$OUTPUT"
echo "# HELP amd_gpu_busy_percent AMD GPU utilization percentage" >> "$OUTPUT"
echo "# TYPE amd_gpu_busy_percent gauge" >> "$OUTPUT"

CARD_INDEX=0
for CARD_DIR in /sys/class/drm/card*/device; do
    [ -d "$CARD_DIR" ] || continue
    CARD=$(basename $(dirname "$CARD_DIR"))

    # Temperature
    TEMP_FILE=$(find "$CARD_DIR/hwmon" -name "temp1_input" 2>/dev/null | head -1)
    if [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ]; then
        RAW=$(cat "$TEMP_FILE" 2>/dev/null)
        TEMP=$(echo "scale=1; $RAW / 1000" | bc 2>/dev/null || echo "0")
        echo "amd_gpu_temperature_celsius{card=\"$CARD\",index=\"$CARD_INDEX\"} $TEMP" >> "$OUTPUT"
    fi

    # VRAM
    VRAM_USED="$CARD_DIR/mem_info_vram_used"
    VRAM_TOTAL="$CARD_DIR/mem_info_vram_total"
    if [ -f "$VRAM_USED" ] && [ -f "$VRAM_TOTAL" ]; then
        echo "amd_gpu_vram_used_bytes{card=\"$CARD\",index=\"$CARD_INDEX\"} $(cat $VRAM_USED)" >> "$OUTPUT"
        echo "amd_gpu_vram_total_bytes{card=\"$CARD\",index=\"$CARD_INDEX\"} $(cat $VRAM_TOTAL)" >> "$OUTPUT"
    fi

    # Utilization
    GPU_BUSY="$CARD_DIR/gpu_busy_percent"
    if [ -f "$GPU_BUSY" ]; then
        echo "amd_gpu_busy_percent{card=\"$CARD\",index=\"$CARD_INDEX\"} $(cat $GPU_BUSY)" >> "$OUTPUT"
    fi

    CARD_INDEX=$((CARD_INDEX + 1))
done
AMDSCRIPT
        chmod +x "$INSTALL_DIR/amd_gpu_metrics.sh"
        echo "   AMD sysfs collector script created."
    else
        echo "   No discrete GPU detected — skipping GPU exporter."
    fi
elif [ "$OS_NAME" = "darwin" ]; then
    echo "   macOS detected — GPU monitoring not available via this stack."
fi

# ==========================================
#  GENERATE start.sh
# ==========================================
echo "-> Creating start.sh script..."
cat << STARTSCRIPT > "$INSTALL_DIR/start.sh"
#!/bin/bash
DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
cd "\$DIR"

nohup ./node_exporter/node_exporter \\
    --collector.textfile.directory=./node_exporter/textfile_collector \\
    > node_exporter.log 2>&1 & echo \$! > node_exporter.pid

cd prometheus
nohup ./prometheus --config.file=prometheus.yml --storage.tsdb.retention.time=1y \\
    > prometheus.log 2>&1 & echo \$! > prometheus.pid
cd ..

cd grafana
nohup ./bin/grafana server --homepath . > ../grafana.log 2>&1 & echo \$! > ../grafana.pid
cd ..

if [ -f "./nvidia_gpu_exporter" ]; then
    nohup ./nvidia_gpu_exporter > nvidia_gpu_exporter.log 2>&1 & echo \$! > nvidia_gpu_exporter.pid
    echo "nvidia_gpu_exporter started on port 9835."
fi

if [ -f "./amd_gpu_metrics.sh" ]; then
    # Run AMD collector on a 15-second loop in the background
    (while true; do ./amd_gpu_metrics.sh; sleep 15; done) > amd_gpu_metrics.log 2>&1 &
    echo \$! > amd_gpu_metrics.pid
    echo "AMD GPU sysfs collector started."
fi

echo "Services started."
echo "  Node Exporter: http://localhost:9100"
echo "  Prometheus:    http://localhost:9090 (1-year retention)"
echo "  Grafana:       http://localhost:3000"
STARTSCRIPT
chmod +x "$INSTALL_DIR/start.sh"

# ==========================================
#  GENERATE stop.sh
# ==========================================
echo "-> Creating stop.sh script..."
cat << 'STOPSCRIPT' > "$INSTALL_DIR/stop.sh"
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
for pidfile in node_exporter.pid prometheus/prometheus.pid grafana/grafana.pid nvidia_gpu_exporter.pid amd_gpu_metrics.pid; do
    if [ -f "$pidfile" ]; then
        kill $(cat "$pidfile") 2>/dev/null || true
        rm "$pidfile"
    fi
done
sleep 2
echo "All services stopped."
STOPSCRIPT
chmod +x "$INSTALL_DIR/stop.sh"

# ==========================================
#  SYSTEMD AUTOSTART (Linux only)
# ==========================================
echo "-> Creating Systemd Autostart Service..."
if [ "$OS_NAME" = "linux" ]; then
    mkdir -p "$HOME/.config/systemd/user"
    cat << EOF > "$HOME/.config/systemd/user/grafana-dashboard.service"
[Unit]
Description=Grafana Hardware Dashboard Stack
After=network.target

[Service]
Type=forking
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/start.sh
ExecStop=$INSTALL_DIR/stop.sh
Restart=on-failure

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload || echo "Warning: Could not reload systemd."
    systemctl --user enable grafana-dashboard.service || echo "Warning: Could not enable service."
fi

echo "=========================================="
echo " Installation Complete!"
echo "------------------------------------------"
echo " Run: $INSTALL_DIR/start.sh"
echo " Dashboard: http://localhost:3000"
echo "=========================================="
