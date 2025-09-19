# Flutter SNAPPY Plugin - Setup Guide

This guide covers system-level setup and prerequisites for the Flutter SNAPPY Plugin.

## System Requirements

- **Flutter SDK**: 3.0 or higher
- **Operating System**: Windows 11, Linux (Ubuntu 20.04+, other distributions), or macOS (10.15+)
- **Hardware**: SNAPPY device with USB connection
- **Network**: Available ports in range 8436-8535

## Prerequisites Setup

### 1. SNAPPY Web Agent Daemon

The Flutter plugin communicates with SNAPPY devices through the `snappy_web_agent` daemon, which handles all USB/serial communication.

#### Windows Setup

**Step 1: Download and Install**
```bash
# Download the Windows MSI installer
# snappy-web-agent-[version]-setup.msi

# Run as Administrator
Right-click → "Run as administrator"
```

**Step 2: Verify Installation**
```cmd
# Check if service is installed and running
sc query "Snappy Web Agent"

# Should show:
# SERVICE_NAME: Snappy Web Agent
# STATE: 4 RUNNING

# Check listening ports
netstat -an | findstr "843"

# Should show something like:
# TCP    127.0.0.1:8436    0.0.0.0:0    LISTENING
```

**Step 3: Service Management**
```cmd
# Start service (if not running)
sc start "Snappy Web Agent"

# Stop service
sc stop "Snappy Web Agent"

# Restart service
sc stop "Snappy Web Agent" && sc start "Snappy Web Agent"

# Check service status
sc query "Snappy Web Agent"
```

**Step 4: Windows Firewall**
```cmd
# The installer should automatically add firewall rules
# If needed, manually allow the service:
netsh advfirewall firewall add rule name="Snappy Web Agent" dir=in action=allow protocol=TCP localport=8436-8535
```

#### Linux Setup

**Step 1: Download and Install**
```bash
# Ubuntu/Debian
wget https://releases.example.com/snappy-web-agent_[version]_amd64.deb
sudo dpkg -i snappy-web-agent_[version]_amd64.deb

# CentOS/RHEL/Fedora
sudo rpm -i snappy-web-agent-[version].x86_64.rpm
```

**Step 2: Device Access Setup**
```bash
# Add udev rules for SNAPPY device access
sudo tee /etc/udev/rules.d/99-snappy-web-agent.rules << EOF
# SNAPPY Device Rules
SUBSYSTEM=="usb", ATTRS{idVendor}=="b1b0", ATTRS{idProduct}=="5508", MODE="0666", GROUP="dialout"
SUBSYSTEM=="tty", ATTRS{idVendor}=="b1b0", ATTRS{idProduct}=="5508", MODE="0666", GROUP="dialout"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Add current user to dialout group
sudo usermod -a -G dialout $USER

# Log out and back in for group changes to take effect
```

**Step 3: Service Setup**
```bash
# Create systemd service file
sudo tee /etc/systemd/system/snappy-web-agent.service << EOF
[Unit]
Description=Snappy Web Agent Daemon
After=network.target

[Service]
Type=simple
User=snappy
Group=snappy
ExecStart=/usr/local/bin/snappy-web-agent
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Create service user
sudo useradd -r -s /bin/false snappy

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable snappy-web-agent.service
sudo systemctl start snappy-web-agent.service
```

**Step 4: Verify Linux Installation**
```bash
# Check service status
systemctl status snappy-web-agent.service

# Check listening ports
netstat -ln | grep "843"
# Or with ss:
ss -ln | grep "843"

# Check logs
journalctl -u snappy-web-agent.service -f

# Test device detection
lsusb | grep -i "b1b0:5508"

# Check device permissions
ls -la /dev/ttyACM* /dev/ttyUSB* 2>/dev/null | grep dialout
```

#### macOS Setup

**Step 1: Download and Install**
```bash
# Download the macOS PKG installer
# snappy-web-agent-[version]-universal.pkg

# Install using Installer.app (double-click) or command line:
sudo installer -pkg snappy-web-agent-[version]-universal.pkg -target /
```

**Step 2: Verify Installation**
```bash
# Check if daemon is loaded and running
sudo launchctl list | grep com.snappy.webagent

# Should show something like:
# -	0	com.snappy.webagent

# Check listening ports
netstat -an | grep "843"

# Should show something like:
# tcp4       0      0  127.0.0.1.8436         *.*                    LISTEN

# Alternative using lsof
lsof -i :8436
```

**Step 3: Service Management**
```bash
# Start daemon (if not running)
sudo launchctl start com.snappy.webagent

# Stop daemon
sudo launchctl stop com.snappy.webagent

# Reload daemon configuration
sudo launchctl unload /Library/LaunchDaemons/com.snappy.webagent.plist
sudo launchctl load /Library/LaunchDaemons/com.snappy.webagent.plist

# Check daemon status
sudo launchctl list com.snappy.webagent
```

**Step 4: Device Access Setup**
```bash
# macOS handles USB device access automatically for most devices
# If you encounter permission issues:

# Check USB device detection
system_profiler SPUSBDataType | grep -A5 -B5 "b1b0"

# For serial device access, ensure your user has access:
ls -la /dev/cu.* | grep -i usb

# If needed, add user to specific groups (usually not required on macOS):
sudo dseditgroup -o edit -a $USER -t user wheel
```

**Step 5: Verify macOS Installation**
```bash
# Check daemon status
sudo launchctl list | grep com.snappy.webagent

# Check logs
tail -f /var/log/snappy-web-agent/stdout.log
tail -f /var/log/snappy-web-agent/stderr.log

# Check listening ports
lsof -i :8436-8535

# Test device detection (with device connected)
# Look for device in system profiler
system_profiler SPUSBDataType | grep -A10 -B5 "Snappy\|b1b0"

# Check serial devices
ls -la /dev/cu.* /dev/tty.* | grep -i usb
```

**Step 6: macOS Firewall (if needed)**
```bash
# macOS firewall typically allows local connections automatically
# If you need to explicitly allow (rare):
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/snappy-web-agent
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/local/bin/snappy-web-agent
```

**Uninstallation (macOS)**
```bash
# Stop and unload the daemon
sudo launchctl stop com.snappy.webagent
sudo launchctl unload /Library/LaunchDaemons/com.snappy.webagent.plist

# Remove files
sudo rm -f /usr/local/bin/snappy-web-agent
sudo rm -f /Library/LaunchDaemons/com.snappy.webagent.plist
sudo rm -rf /usr/local/share/snappy-web-agent
sudo rm -rf /var/log/snappy-web-agent

echo "✅ Snappy Web Agent uninstalled from macOS"
```

### 2. SNAPPY Device Setup

**Hardware Requirements**
- SNAPPY remote device
- USB cable (device-specific)
- Device must have VID: `0xb1b0` and PID: `0x5508`

**Connection Steps**
1. **Power on** your SNAPPY device
2. **Connect via USB** to your computer
3. **Wait for detection** (usually 5-10 seconds)
4. **Verify detection** using system tools

**Device Verification**

Windows:
```cmd
# Check Device Manager
devmgmt.msc

# Look for "Snappy Device" under "Ports (COM & LPT)" or "Universal Serial Bus devices"

# Using PowerShell
Get-PnpDevice | Where-Object {$_.InstanceId -like "*VID_B1B0&PID_5508*"}
```

Linux:
```bash
# Check USB devices
lsusb | grep "b1b0:5508"

# Check dmesg for device messages
dmesg | grep -i snappy

# Check serial devices
ls -la /dev/tty* | grep -E "(ACM|USB)"

# Test device access
sudo chmod 666 /dev/ttyACM0  # Replace with actual device
echo "test" > /dev/ttyACM0    # Should not give permission error
```

## Network Configuration

### Port Requirements
The snappy_web_agent daemon uses ports **8436-8535** for communication:
- **8436**: Primary port (most common)
- **8437-8535**: Fallback ports if primary is busy

### Firewall Configuration

**Windows Firewall:**
```cmd
# Allow port range for snappy_web_agent
netsh advfirewall firewall add rule name="Snappy Web Agent Ports" dir=in action=allow protocol=TCP localport=8436-8535
```

**Linux iptables:**
```bash
# Allow incoming connections on daemon ports
sudo iptables -A INPUT -p tcp --dport 8436:8535 -j ACCEPT

# Save rules (Ubuntu/Debian)
sudo iptables-save > /etc/iptables/rules.v4

# For firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=8436-8535/tcp
sudo firewall-cmd --reload
```

### Network Testing
```bash
# Test daemon connectivity
curl -i http://localhost:8436/socket.io/
# Should return HTTP response, not connection refused

# Test specific port
telnet localhost 8436
# Should connect successfully

# Scan for active daemon ports
nmap -p 8436-8445 localhost
```

## Troubleshooting Setup Issues

### Common Windows Issues

**Service Won't Start:**
```cmd
# Check Windows Event Log
eventvwr.msc
# Navigate to Windows Logs → Application
# Look for Snappy Web Agent errors

# Try manual start
"C:\Program Files\Snappy Web Agent\snappy-web-agent.exe"

# Check dependencies
sfc /scannow
```

**Device Not Detected:**
```cmd
# Update USB drivers
# Device Manager → Right-click device → Update driver

# Check USB power management
# Device Manager → USB Root Hub → Properties → Power Management
# Uncheck "Allow computer to turn off this device"
```

### Common Linux Issues

**Permission Denied:**
```bash
# Check user groups
groups $USER
# Should include 'dialout'

# If not in dialout group
sudo usermod -a -G dialout $USER
# Then log out and back in

# Check device ownership
ls -la /dev/ttyACM0
# Should show group 'dialout'
```

**Service Fails to Start:**
```bash
# Check service logs
journalctl -u snappy-web-agent.service --no-pager

# Check binary permissions
ls -la /usr/local/bin/snappy-web-agent
chmod +x /usr/local/bin/snappy-web-agent

# Test manual start
sudo -u snappy /usr/local/bin/snappy-web-agent
```

**No Device Found:**
```bash
# Check USB subsystem
lsusb -v | grep -A 10 -B 10 "b1b0"

# Check kernel messages
dmesg | tail -20

# Reload USB drivers
sudo modprobe -r usbserial
sudo modprobe usbserial
```

## Validation Checklist

Before using the Flutter plugin, verify:

### System Validation
- [ ] **Operating System**: Windows 11 or Linux
- [ ] **Flutter SDK**: Version 3.0+ installed
- [ ] **Network**: Ports 8436-8535 available
- [ ] **Permissions**: User has device access rights

### Daemon Validation
- [ ] **Service Running**: snappy_web_agent service active
- [ ] **Port Listening**: Daemon listening on 8436-8535 range
- [ ] **Version Check**: Daemon responds to version requests
- [ ] **Logs Clean**: No error messages in daemon logs

### Device Validation
- [ ] **Hardware Connected**: SNAPPY device plugged in via USB
- [ ] **Device Detected**: System recognizes device (VID/PID correct)
- [ ] **Permissions**: User can access device file/port
- [ ] **Communication**: Daemon can communicate with device

### Network Validation
- [ ] **Firewall**: Ports not blocked by firewall
- [ ] **Connectivity**: Can connect to http://localhost:8436
- [ ] **Socket.IO**: Daemon responds to Socket.IO requests
- [ ] **No Conflicts**: No other services using same ports

### Quick Validation Script

**Windows (PowerShell):**
```powershell
# Quick validation script
Write-Host "=== Snappy Web Agent Validation ==="

# Check service
$service = Get-Service "Snappy Web Agent" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "✓ Service is running"
} else {
    Write-Host "✗ Service not running"
}

# Check port
$port = Test-NetConnection -ComputerName localhost -Port 8436 -WarningAction SilentlyContinue
if ($port.TcpTestSucceeded) {
    Write-Host "✓ Port 8436 is listening"
} else {
    Write-Host "✗ Port 8436 not accessible"
}

# Check device
$device = Get-PnpDevice | Where-Object {$_.InstanceId -like "*VID_B1B0&PID_5508*"}
if ($device) {
    Write-Host "✓ SNAPPY device detected"
} else {
    Write-Host "✗ SNAPPY device not found"
}
```

**Linux (Bash):**
```bash
#!/bin/bash
echo "=== Snappy Web Agent Validation ==="

# Check service
if systemctl is-active --quiet snappy-web-agent.service; then
    echo "✓ Service is running"
else
    echo "✗ Service not running"
fi

# Check port
if nc -z localhost 8436 2>/dev/null; then
    echo "✓ Port 8436 is listening"
else
    echo "✗ Port 8436 not accessible"
fi

# Check device
if lsusb | grep -q "b1b0:5508"; then
    echo "✓ SNAPPY device detected"
else
    echo "✗ SNAPPY device not found"
fi

# Check permissions
if groups $USER | grep -q dialout; then
    echo "✓ User has device permissions"
else
    echo "✗ User not in dialout group"
fi
```

Once all validations pass, you're ready to proceed with the Flutter plugin integration!