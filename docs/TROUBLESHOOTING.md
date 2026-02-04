# Troubleshooting Guide

This guide provides solutions to common issues encountered when setting up and running the GGB Teststand.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Serial Device Issues](#serial-device-issues)
- [ST-Link Programmer Issues](#st-link-programmer-issues)
- [Power Supply Issues](#power-supply-issues)
- [Docker and Container Issues](#docker-and-container-issues)
- [MongoDB Issues](#mongodb-issues)
- [Node-RED Issues](#node-red-issues)
- [Network and LabJack Issues](#network-and-labjack-issues)
- [Performance Issues](#performance-issues)
- [Advanced Debugging](#advanced-debugging)

## Quick Diagnostics

Run these commands first to identify issues:

```bash
# 1. Check Docker status
docker ps
docker compose ps

# 2. Check USB devices
lsusb

# 3. Check serial ports
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null

# 4. Check logs
docker compose logs --tail=50

# 5. Run setup verification
./setup.sh --check-only
```

## Serial Device Issues

### Issue: Serial devices not found (`/dev/ttyUSB*` or `/dev/ttyACM*` missing)

**Symptoms:**
- `ls /dev/ttyUSB*` shows "No such file or directory"
- Node-RED serial nodes show "port not found" errors

**Solutions:**

1. **Verify USB devices are connected:**
```bash
lsusb | grep -E "FTDI|Silicon|CH340"
```
If no devices shown, check physical USB connections.

2. **Check kernel messages:**
```bash
dmesg | tail -20
# Look for USB device detection messages
# Example: "FTDI USB Serial Device converter now attached to ttyUSB0"
```

3. **Check user permissions (Linux):**
```bash
# Check if user is in dialout group
groups | grep dialout

# If not, add user to dialout group
sudo usermod -aG dialout $USER

# Logout and login for changes to take effect
```

4. **Reload USB device:**
```bash
# Unplug and replug the USB device
# Or reset USB port (advanced):
# Find USB device bus and device number
lsusb
# sudo usbreset /dev/bus/usb/XXX/YYY
```

5. **Check for driver issues (macOS):**
```bash
# Install drivers if needed
# FTDI: https://ftdichip.com/drivers/vcp-drivers/
# CP210x: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
```

### Issue: Serial devices in wrong order

**Symptoms:**
- `/dev/ttyUSB0` exists but is the wrong device
- Serial communication to wrong endpoint

**Solutions:**

1. **Reconnect in correct order:**
```bash
# Disconnect all serial devices
# Reconnect one at a time in order:
# 1. FTDI #1 (Debug) → should become ttyUSB0
# 2. FTDI #2 (Reader1) → should become ttyUSB1
# 3. FTDI #3 (Reader2) → should become ttyUSB2
# 4. ESP32 → should become ttyACM0
```

2. **Use stable device IDs:**
```bash
# List devices by-id (stable names based on serial number)
ls -l /dev/serial/by-id/

# Update node-red-data/flows.json to use by-id paths
# Example: /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A50285BI-if00-port0
```

3. **Create udev rules (Linux only):**
```bash
# Identify device serial numbers
udevadm info -a -n /dev/ttyUSB0 | grep serial

# Create udev rule file
sudo nano /etc/udev/rules.d/99-ggb-teststand.rules

# Add rules (replace SERIAL_NUMBER with actual values):
SUBSYSTEM=="tty", ATTRS{serial}=="A50285BI", SYMLINK+="ttyUSB_DEBUG"
SUBSYSTEM=="tty", ATTRS{serial}=="A12345CD", SYMLINK+="ttyUSB_READER1"
SUBSYSTEM=="tty", ATTRS{serial}=="B67890EF", SYMLINK+="ttyUSB_READER2"

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Update flows.json to use /dev/ttyUSB_DEBUG, etc.
```

### Issue: Permission denied when accessing serial ports

**Symptoms:**
- Error: "Error: Permission denied, cannot open /dev/ttyUSB0"

**Solutions:**

1. **Add user to dialout group (Linux):**
```bash
sudo usermod -aG dialout $USER
# Logout and login required
```

2. **Temporary permission fix (testing only):**
```bash
sudo chmod 666 /dev/ttyUSB0
# Note: This resets on reboot, proper fix is dialout group
```

3. **Check Docker container permissions:**
```bash
# Ensure container runs in privileged mode
# In docker_compose.yml:
services:
  node-red:
    privileged: true
    devices:
      - /dev:/dev
    group_add:
      - dialout
```

## ST-Link Programmer Issues

### Issue: ST-Link not detected

**Symptoms:**
- `STM32_Programmer_CLI -l` shows no devices
- Error: "No ST-LINK detected"

**Solutions:**

1. **Verify ST-Link connected:**
```bash
lsusb | grep -i "stm\|0483:374"
# Should show: STMicroelectronics ST-LINK
```

2. **Check Docker USB access:**
```bash
# Test ST-Link from host (outside Docker)
# If it works on host but not in container, check container config

docker run -it --privileged -v /dev:/dev stm32_flash_api:2.2 \
  lsusb | grep STM
```

3. **Update ST-Link firmware:**
   - Download STM32 Cube Programmer (GUI version)
   - Connect ST-Link
   - Click "Firmware Upgrade" button
   - Update to latest version

4. **Try different USB port:**
   - Some USB 3.0 ports have issues with ST-Link
   - Try USB 2.0 port instead

5. **Check USB cable:**
   - Try different USB cable
   - Ensure cable supports data transfer (not charge-only)

### Issue: Cannot connect to target STM32

**Symptoms:**
- ST-Link detected but cannot connect to target
- Error: "Error: Target not found"

**Solutions:**

1. **Verify target power:**
```bash
# Ensure DUT is powered
# Check power supply output:
curl http://localhost:5000/api/ps/ch1/measured_voltage
```

2. **Check SWD connections:**
   - SWCLK connected to target SWCLK
   - SWDIO connected to target SWDIO
   - GND connected to target GND
   - Check for loose connections

3. **Check target reset:**
   - Try connecting with reset held
   - Release reset after connection attempt

4. **Try different connection mode:**
```bash
# Try under reset mode
STM32_Programmer_CLI -c port=SWD mode=UR reset=HWrst

# Try with lower frequency
STM32_Programmer_CLI -c port=SWD freq=4000
```

5. **Check target NRST pin:**
   - Ensure NRST is not held low
   - Check for solder bridges on target board

### Issue: Programming fails midway

**Symptoms:**
- Programming starts but fails during write
- Error: "Error: Programming failed"

**Solutions:**

1. **Check target power stability:**
   - Verify power supply current limit not exceeded
   - Check voltage doesn't drop during programming

2. **Erase flash first:**
```bash
curl http://localhost:5000/api/st_link/erase
# Then try programming again
```

3. **Try slower programming speed:**
   - Reduce SWD clock frequency in programming script

4. **Check for flash protection:**
   - Read option bytes
   - Disable read/write protection if enabled

## Power Supply Issues

### Issue: Cannot detect power supply

**Symptoms:**
- `curl http://localhost:5000/api/ps/device_list` returns empty or error
- Error: "No VISA resources found"

**Solutions:**

1. **Verify USB connection:**
```bash
lsusb | grep -i "siglent\|0483:7540"
```

2. **Check if power supply is on:**
   - Ensure power supply is powered on
   - Front panel should be illuminated

3. **Install PyVISA dependencies:**
```bash
# On host system
pip3 install pyvisa pyvisa-py PyUSB

# In container (already installed)
docker exec -it <container> pip3 list | grep pyvisa
```

4. **Test VISA connection directly:**
```bash
python3 << EOF
import pyvisa
rm = pyvisa.ResourceManager('@py')
print("Backend:", rm)
print("Resources:", rm.list_resources())
EOF
```

5. **Check for USB permission issues:**
```bash
# List USB devices with permissions
ls -l /dev/bus/usb/*/*

# Should be accessible by user or group
```

### Issue: Power supply VISA address mismatch

**Symptoms:**
- Error: "Resource not found: USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR"

**Solutions:**

1. **Find actual VISA address:**
```bash
python3 -c "import pyvisa; print(pyvisa.ResourceManager().list_resources())"
```

2. **Update app.py with correct address:**
```bash
# Edit stm32_flash_api/app.py
# Find all occurrences (lines 172, 193, 236, 272, 286, 300, 330)
# Replace with your actual VISA address

# Or run setup script to auto-detect:
./setup.sh
```

3. **Backup and restore configuration:**
```bash
# Backup
cp stm32_flash_api/app.py stm32_flash_api/app.py.backup

# Edit using sed
OLD_ADDR="USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR"
NEW_ADDR="USB0::0x0483::0x7540::YOUR_SERIAL::INSTR"
sed -i "s|$OLD_ADDR|$NEW_ADDR|g" stm32_flash_api/app.py

# Rebuild container
docker compose build stm32_flash_api
docker compose up -d
```

### Issue: Power supply communication timeout

**Symptoms:**
- API calls to power supply timeout
- Error: "Timeout error"

**Solutions:**

1. **Increase delay in app.py:**
```python
# Edit stm32_flash_api/app.py
# Change delay variable (currently 0.5 seconds)
delay = 1.0  # Increase to 1 second
```

2. **Check USB bus load:**
   - Too many USB devices can cause timeouts
   - Try powered USB hub

3. **Reset power supply:**
   - Power cycle the supply
   - Restart container: `docker compose restart stm32_flash_api`

## Docker and Container Issues

### Issue: Docker daemon not running

**Symptoms:**
- Error: "Cannot connect to Docker daemon"

**Solutions:**

1. **Start Docker (Linux):**
```bash
sudo systemctl start docker
sudo systemctl enable docker  # Auto-start on boot
```

2. **Start Docker Desktop (macOS/Windows):**
   - Open Docker Desktop application
   - Wait for "Docker is running" status

### Issue: Docker build fails

**Symptoms:**
- `docker build` command fails
- Error during image build

**Solutions:**

1. **Check disk space:**
```bash
df -h
# Need 10GB+ free

# Clean up old images if needed
docker system prune -a
```

2. **Check network connectivity:**
```bash
# Docker needs internet to pull base images
ping -c 4 8.8.8.8
```

3. **Clear Docker build cache:**
```bash
docker builder prune -a
```

4. **Check Dockerfile syntax:**
```bash
# Ensure no typos in Dockerfile
cat stm32_flash_cli/Dockerfile
cat stm32_flash_api/Dockerfile
```

### Issue: Container exits immediately

**Symptoms:**
- `docker compose ps` shows container status as "Exit 1" or "Exit 137"

**Solutions:**

1. **Check container logs:**
```bash
docker compose logs <service-name>
# Examples: node-red, stm32_flash_api, mongodb
```

2. **Run container interactively for debugging:**
```bash
docker run -it stm32_flash_api:2.2 /bin/bash
# Try running the application manually inside
```

3. **Check memory limits:**
```bash
# Exit 137 often means out-of-memory
docker stats

# Increase Docker memory limit in Docker Desktop settings
```

4. **Check for missing dependencies:**
```bash
# Verify all dependencies installed in container
docker exec -it <container> pip3 list  # Python deps
docker exec -it <container> npm list   # Node deps
```

### Issue: Cannot access container services

**Symptoms:**
- Cannot reach http://localhost:1880 (Node-RED)
- Connection refused errors

**Solutions:**

1. **Verify container is running:**
```bash
docker compose ps
# All services should show "Up"
```

2. **Check port mappings:**
```bash
docker compose port node-red 1880
# Should show: 0.0.0.0:1880
```

3. **Check firewall:**
```bash
# Linux
sudo ufw status
sudo ufw allow 1880/tcp

# macOS
# Check System Preferences → Security & Privacy → Firewall
```

4. **Try 127.0.0.1 instead of localhost:**
```bash
curl http://127.0.0.1:1880
```

5. **Check logs for binding errors:**
```bash
docker compose logs node-red | grep -i "error\|fail"
```

## MongoDB Issues

### Issue: MongoDB container won't start

**Symptoms:**
- MongoDB container exits with error
- Error: "AVX instruction set not supported"

**Solutions:**

1. **Use MongoDB 4.4 (no AVX required):**
```yaml
# Already configured in docker_compose.yml
services:
  mongodb:
    image: mongo:4.4.29-focal
```

2. **Check data directory permissions:**
```bash
ls -ld ./mongodb_data
# Should be writable

# Fix permissions if needed
sudo chown -R $(id -u):$(id -g) ./mongodb_data
```

3. **Remove old MongoDB data (if corrupted):**
```bash
# WARNING: This deletes all MongoDB data
docker compose down
rm -rf ./mongodb_data/*
docker compose up -d
```

### Issue: Cannot connect to MongoDB

**Symptoms:**
- Node-RED or applications cannot connect to MongoDB
- Error: "MongoNetworkError"

**Solutions:**

1. **Verify MongoDB is running:**
```bash
docker compose ps mongodb
# Should show "Up"
```

2. **Check MongoDB logs:**
```bash
docker compose logs mongodb
```

3. **Test connection from another container:**
```bash
docker exec -it <node-red-container> nc -zv mongodb 27017
# Should show: Connection to mongodb 27017 port [tcp/*] succeeded!
```

4. **Check authentication settings:**
```bash
# Authentication is currently disabled in docker_compose.yml
# If enabled, verify credentials match in all services
```

## Node-RED Issues

### Issue: Node-RED dependencies missing

**Symptoms:**
- Node-RED shows "missing node" warnings
- Serial port nodes unavailable

**Solutions:**

1. **Install Node-RED dependencies:**
```bash
cd node-red-data
npm install
cd ..
docker compose restart node-red
```

2. **Verify package.json exists:**
```bash
cat node-red-data/package.json
```

3. **Install specific missing package:**
```bash
cd node-red-data
npm install node-red-node-serialport
cd ..
docker compose restart node-red
```

### Issue: Node-RED flows not loading

**Symptoms:**
- Blank Node-RED interface
- Flows.json errors in logs

**Solutions:**

1. **Check flows.json syntax:**
```bash
# Validate JSON syntax
python3 -m json.tool node-red-data/flows.json > /dev/null
# No output = valid JSON
```

2. **Backup and restore flows:**
```bash
# Backup current flows
cp node-red-data/flows.json node-red-data/flows.json.backup

# Restore from backup if corrupted
cp node-red-data/flows.json.backup node-red-data/flows.json

# Restart Node-RED
docker compose restart node-red
```

3. **Check Node-RED logs:**
```bash
docker compose logs node-red | tail -50
```

### Issue: Serial port nodes show disconnected

**Symptoms:**
- Serial port nodes in Node-RED show disconnected status
- Red dot on serial nodes

**Solutions:**

1. **Verify device exists:**
```bash
docker exec -it <node-red-container> ls -l /dev/ttyUSB0
```

2. **Check Node-RED has device access:**
```bash
# Verify container has privileged mode and device access
grep -A5 "node-red:" docker_compose.yml | grep -E "privileged|devices"
```

3. **Restart serial node:**
   - Double-click serial port node in Node-RED
   - Click "Done" to re-initialize
   - Deploy flows

4. **Check reconnect time:**
```bash
# Edit node-red-data/settings.js
# serialReconnectTime: 15000  # milliseconds
```

## Network and LabJack Issues

### Issue: Cannot ping LabJack T7

**Symptoms:**
- `ping 192.168.8.148` fails
- Error: "Destination Host Unreachable"

**Solutions:**

1. **Verify LabJack is powered on:**
   - Check red power LED on LabJack

2. **Check Ethernet cable:**
   - Ensure cable is securely connected
   - Try different Ethernet cable

3. **Verify IP configuration:**
   - Use LabJack Kipling software to check/set IP
   - Download from: https://labjack.com/pages/support

4. **Check network subnet:**
```bash
# Your computer must be on same subnet
ip addr show  # Linux
ifconfig      # macOS

# If computer is on 192.168.1.x network, LabJack at 192.168.8.148 won't work
# Either change LabJack IP or use router/switch
```

5. **Check firewall:**
```bash
# Linux
sudo ufw status
sudo iptables -L

# Temporarily disable to test
sudo ufw disable  # Re-enable after: sudo ufw enable
```

### Issue: Modbus connection to LabJack fails

**Symptoms:**
- Node-RED Modbus nodes show error
- Cannot read/write LabJack registers

**Solutions:**

1. **Verify TCP port 502 is open:**
```bash
nc -zv 192.168.8.148 502
# Should show: Connection to 192.168.8.148 502 port [tcp/mbap] succeeded!
```

2. **Test Modbus connection:**
```bash
pip3 install pymodbus

python3 << EOF
from pymodbus.client import ModbusTcpClient
client = ModbusTcpClient('192.168.8.148', port=502)
if client.connect():
    print("✓ Modbus connected")
    result = client.read_holding_registers(0, 1, unit=1)
    print("Result:", result)
    client.close()
else:
    print("✗ Connection failed")
EOF
```

3. **Check Modbus configuration in flows.json:**
   - Verify IP address: 192.168.8.148
   - Verify port: 502
   - Verify unit ID (usually 1)

4. **Check LabJack firmware:**
   - Update to latest firmware using Kipling
   - Old firmware may have Modbus bugs

## Performance Issues

### Issue: System running slowly

**Solutions:**

1. **Check system resources:**
```bash
docker stats
# Check CPU and memory usage
```

2. **Increase Docker resources (Docker Desktop):**
   - Settings → Resources
   - Increase CPUs and Memory allocation

3. **Reduce Node-RED flow complexity:**
   - Disable unused flows
   - Reduce debug node outputs

4. **Check disk I/O:**
```bash
iostat -x 1  # Linux
# High %util indicates disk bottleneck
```

### Issue: High CPU usage

**Solutions:**

1. **Identify which container:**
```bash
docker stats --no-stream
```

2. **Check for infinite loops in Node-RED:**
   - Review flows for feedback loops
   - Add rate limiting nodes

3. **Restart problematic container:**
```bash
docker compose restart <service-name>
```

## Advanced Debugging

### Enable Debug Logging

**Node-RED:**
```bash
# Edit node-red-data/settings.js
logging: {
    console: {
        level: "debug",  # Change from "info" to "debug"
        metrics: false,
        audit: false
    }
}
```

**Docker Containers:**
```bash
# View real-time logs
docker compose logs -f <service-name>

# View last N lines
docker compose logs --tail=100 <service-name>

# Save logs to file
docker compose logs > debug_logs.txt
```

### Interactive Container Shell

```bash
# Enter running container
docker exec -it <container-name> /bin/bash

# Or for Alpine-based images:
docker exec -it <container-name> /bin/sh

# Check processes inside container
ps aux

# Check network from inside container
ping google.com
nc -zv mongodb 27017
```

### Network Debugging

```bash
# Check Docker networks
docker network ls

# Inspect specific network
docker network inspect <network-name>

# Test connectivity between containers
docker exec -it <container1> ping <container2>
```

### USB Debugging

```bash
# Detailed USB device information
lsusb -v

# Monitor USB events
sudo udevadm monitor

# Check device attributes
udevadm info -a -n /dev/ttyUSB0

# Kernel messages
dmesg -w  # Watch real-time
```

## Getting Help

### Information to Collect

When reporting issues, collect:

1. **System Information:**
```bash
uname -a                    # OS version
docker --version            # Docker version
docker compose version      # Compose version
```

2. **Hardware Status:**
```bash
lsusb                       # USB devices
ls -l /dev/ttyUSB*          # Serial ports
./setup.sh --check-only     # Hardware check
```

3. **Container Status:**
```bash
docker compose ps           # Container status
docker compose logs > logs.txt  # All logs
```

4. **Configuration Files:**
   - `docker_compose.yml`
   - `node-red-data/package.json`
   - Hardware config: `hardware_config.json`

### Reset to Known State

If all else fails, reset the system:

```bash
# Stop all containers
docker compose down

# Remove all data (WARNING: Deletes MongoDB data!)
rm -rf mongodb_data/*

# Rebuild containers
docker compose build

# Start fresh
docker compose up -d
```

---

## Still Having Issues?

1. Check the main README for setup instructions
2. Review HARDWARE_SETUP.md for connection details
3. Run the setup script: `./setup.sh --check-only`
4. Check Docker logs: `docker compose logs`

---

**Document Version:** 1.0  
**Last Updated:** 2026-02-04
