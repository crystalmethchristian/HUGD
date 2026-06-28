# Grafana Hardware Dashboard

An automated, self-hosted hardware dashboard stack that monitors your system's battery life, power draw, CPU, RAM, network, and temperatures. It uses Prometheus and Node Exporter to gather metrics and Grafana to visualize them perfectly.

## Hardware Compatibility
This stack automatically detects your hardware. It will dynamically show all of your CPU cores, RAM modules, hard drives, batteries, and network interfaces.

## Included Dashboards
- **Main Comprehensive Overview**: The "God Mode" dashboard combining the most critical high-level stats from CPU, Memory, Disk, Network, and GPU into a single dense view.
- **CPU Metrics Deep Dive**: Total and per-core utilization, clock speeds, interrupts, and context switches.
- **GPU Metrics Deep Dive**: VRAM usage, core utilization, power draw, and temperatures.
- **Network Metrics Deep Dive**: Bandwidth I/O, active TCP/UDP connections, and network errors/drops.
- **System Temperatures**: Consolidated thermal readings for CPU, GPU, Motherboard, and Disks.


## GPU Monitoring Support

The installer **automatically detects your GPU hardware** and installs the right tools:

| GPU | Linux | Windows |
|---|---|---|
| **NVIDIA (any card)** | ✅ Full — VRAM, utilization, temperature, power draw per GPU | ✅ Full — same metrics via `nvidia_gpu_exporter.exe` |
| **AMD consumer (RX 6000/7000)** | 🟡 Partial — VRAM + temperature via kernel sysfs | 🟡 Basic — VRAM + utilization via WMI |
| **Multiple GPUs** | ✅ Each GPU shown individually in a dropdown | ✅ Each GPU shown via `phys` label |
| **Intel iGPU** | 🟡 Partial — requires `intel-gpu-tools` | 🔴 Basic WMI only |

> **Note:** For NVIDIA, `nvidia-smi` must be installed (it ships with the standard NVIDIA driver). The installer checks for it automatically.

## Windows — Graphical Installer (.exe)

For the easiest Windows installation, download the **pre-compiled setup wizard** from the [Releases page](https://github.com/YOUR_USERNAME/grafana-dashboard/releases).

It provides a standard **Next → Next → Finish** installation wizard that:
- Lets you choose the install directory
- Automatically downloads all required binaries
- Detects your GPU and installs the right exporter
- Creates Start Menu shortcuts to start/stop the dashboard
- Optionally adds the dashboard to Windows startup


## Installation

This installer works on **Linux (x86_64)** and **Windows (x64)**!

### For Linux
First, clone the repository, then run the installer:
```bash
git clone https://github.com/YOUR_USERNAME/grafana-dashboard.git
cd grafana-dashboard
chmod +x install.sh
./install.sh
```

### For Windows
Simply double-click the `install.bat` file!
(If Windows SmartScreen complains, click "More Info" and "Run anyway").

### What does the installer do?
1. Downloads tested, stable standalone binaries for Grafana, Prometheus, and Node Exporter.
2. Installs everything to `~/grafana-dashboard`.
3. Sets up Prometheus scraping rules.
4. Auto-provisions the Grafana data sources and our custom dashboards.
5. Generates a Systemd `user` service so it automatically starts quietly in the background every time you boot your computer.

## Accessing the Dashboard

After installation, simply open your web browser and go to:
[http://localhost:3000](http://localhost:3000)

By default, it will take you to Grafana. Navigate to **Dashboards** > **Laptop Health Overview** to see your stats!

---

*Note: GPU metrics are not natively collected by `node_exporter`. If you wish to track GPU usage, you will need to install an exporter specific to your GPU vendor (e.g. `nvidia-gpu-exporter`) and add it to `config/prometheus.yml`.*

## Setting up Alerts (Discord, Email, etc.)

Grafana makes it incredibly easy to set up visual alerts (like warning you if your battery is low or CPU is hot) without writing any code.

1. Open your Grafana dashboard at `http://localhost:3000`.
2. On the left sidebar, click **Alerting** > **Alert rules** > **New alert rule**.
3. Point and click to select the metric you want to track (e.g. `node_hwmon_temp_celsius`).
4. Drag the visual slider to set your threshold (e.g., `90`).
5. Go to **Contact Points** to paste in your Discord Webhook URL or Email address. Grafana will automatically send a message whenever the threshold is crossed!
