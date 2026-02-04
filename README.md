# GGB Teststand

A containerized test stand system for STM32 microcontroller programming, power supply control, and automated testing using Node-RED, MongoDB, and Flask APIs.

## Table of Contents

- [Overview](#overview)
- [Hardware Requirements](#hardware-requirements)
- [Software Prerequisites](#software-prerequisites)
- [Quick Start](#quick-start)
- [Detailed Setup Instructions](#detailed-setup-instructions)
  - [1. Clone Repository](#1-clone-repository)
  - [2. Hardware Setup](#2-hardware-setup)
  - [3. STM32 Cube Programmer Setup](#3-stm32-cube-programmer-setup)
  - [4. Serial Device Configuration](#4-serial-device-configuration)
  - [5. Power Supply Configuration](#5-power-supply-configuration)
  - [6. Build Docker Images](#6-build-docker-images)
  - [7. Install Node-RED Dependencies](#7-install-node-red-dependencies)
  - [8. Start Services](#8-start-services)
- [Service Access](#service-access)
- [API Reference](#api-reference)
- [Configuration](#configuration)
- [Verification & Testing](#verification--testing)
- [Troubleshooting](#troubleshooting)

## Overview

The GGB Teststand is a comprehensive automated testing system that includes:

- **Node-RED** - Visual flow-based programming for test automation
- **STM32 Flash API** - Flask-based REST API for STM32 programming via ST-Link
- **Power Supply Control** - VISA-based control of Siglent power supplies
- **MongoDB** - Test data storage and logging
- **Filebrowser** - Web-based file management interface

**Architecture:**

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Node-RED   │────▶│ STM32 Flash  │────▶│  ST-Link    │
│  (1880)     │     │  API (5000)  │     │ Programmer  │
└─────────────┘     └──────────────┘     └─────────────┘
      │                     │
      │                     ▼
      │             ┌─────────────┐
      │             │  Siglent    │
      │             │  Power PSU  │
      │             └─────────────┘
      ▼
┌─────────────┐     ┌──────────────┐
│  MongoDB    │────▶│   Mongo      │
│  (27017)    │     │  Express     │
└─────────────┘     │   (8081)     │
                    └──────────────┘
```

## Hardware Requirements

### Required Hardware

| Component | Description | Connection | Notes |
|-----------|-------------|------------|-------|
| **Host Computer** | Linux (recommended) or macOS | - | Windows WSL2 also supported |
| **ST-Link V2/V3** | STM32 programmer | USB | For flashing STM32 devices |
| **Siglent SPD3303C** | Programmable power supply | USB (VISA) | Model may vary |
| **LabJack T7** | Data acquisition device | Ethernet | Static IP: 192.168.8.148 |
| **FTDI Cables (3x)** | USB-to-serial adapters | USB | Appear as `/dev/ttyUSB0-2` |
| **ESP32 Serial Cable** | USB-to-serial for ESP32 | USB | Appears as `/dev/ttyACM0` |

### Serial Port Mapping

The system expects the following serial device assignments:

- `/dev/ttyUSB0` - Serial Debug
- `/dev/ttyUSB1` - Reader1 RS485
- `/dev/ttyUSB2` - Reader2 RS485
- `/dev/ttyACM0` - ESP32

**Important:** Connection order matters! Connect USB devices in the order listed above for consistent enumeration.

## Software Prerequisites

- **Docker Engine** 20.10 or later
- **Docker Compose** V2 (plugin) or V1.29+
- **Git** for cloning the repository
- **Python 3** (for setup script and hardware detection)
- **10GB+ free disk space**
- **Network access** for pulling Docker images
- **USB device access permissions** (user must be in `dialout` group on Linux)

### Verify Prerequisites

```bash
# Check Docker
docker --version
docker compose version

# Check disk space
df -h

# Check USB permissions (Linux)
groups | grep dialout
```

## Quick Start

For experienced users with all hardware connected:

```bash
# Run automated setup script
./setup.sh

# Or manually:
cd node-red-data && npm install && cd ..
docker compose -f docker_compose.yml up
```

## Detailed Setup Instructions

### 1. Clone Repository

```bash
git clone <repository-url> ggb-teststand
cd ggb-teststand/ggb-teststand
```

### 2. Hardware Setup

Connect hardware in this order:

1. **Connect ST-Link** - Plug in ST-Link V2/V3 programmer to USB port
2. **Connect FTDI Cables** - Connect three FTDI USB-to-serial adapters in order:
   - First cable → `/dev/ttyUSB0` (Serial Debug)
   - Second cable → `/dev/ttyUSB1` (Reader1)
   - Third cable → `/dev/ttyUSB2` (Reader2)
3. **Connect ESP32 Cable** - Connect ESP32 serial adapter → `/dev/ttyACM0`
4. **Connect Power Supply** - Connect Siglent power supply via USB
5. **Connect LabJack T7** - Connect via Ethernet, configure static IP: `192.168.8.148`

**Verify connections:**

```bash
# List USB devices
lsusb

# Check serial ports
ls -l /dev/ttyUSB* /dev/ttyACM*

# Alternative: Check by ID (stable names)
ls -l /dev/serial/by-id/
```

See `docs/HARDWARE_SETUP.md` for detailed connection diagrams.

### 3. STM32 Cube Programmer Setup

The STM32 Cube Programmer is required for flashing STM32 devices.

#### Download Installer

1. Download **STM32 Cube Programmer v2.18.0** for Linux from:
   - https://www.st.com/en/development-tools/stm32cubeprog.html
   - File: `en.stm32cubeprg-lin-v2-18-0.zip`

2. Extract to `stm32_flash_cli/` directory:

```bash
cd stm32_flash_cli
unzip ~/Downloads/en.stm32cubeprg-lin-v2-18-0.zip
# Should create: stm32_flash_cli/en.stm32cubeprg-lin-v2-18-0/
```

**Note:** The setup script (`setup.sh`) can attempt to download this automatically.

### 4. Serial Device Configuration

The system uses numbered device paths (`/dev/ttyUSB0-2`, `/dev/ttyACM0`) which depend on USB connection order.

#### Verify Device Mapping

```bash
# List all serial devices
ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null

# Identify FTDI devices
lsusb | grep -i ftdi

# Check stable device IDs
ls -l /dev/serial/by-id/
```

#### If Devices Map Incorrectly

If your devices appear in a different order, you have two options:

**Option 1: Reconnect in Correct Order** (Recommended)
- Disconnect all USB serial devices
- Reconnect in the order specified above

**Option 2: Update Node-RED Flow Configuration**
- Edit `node-red-data/flows.json`
- Update serial port paths at lines 2698-2775
- Match your actual device assignments

**Example:**

```json
{
  "id": "415c042d5c9edcd4",
  "type": "serial-port",
  "name": "Serial Debug",
  "serialport": "/dev/ttyUSB0",  // Change this if needed
  "serialbaud": "115200"
}
```

**Security Note:** Docker containers run in privileged mode with full `/dev` access to enable USB communication. This is required for ST-Link and serial port access.

### 5. Power Supply Configuration

The Siglent power supply VISA address is hardcoded in `stm32_flash_api/app.py`.

#### Detect Your Power Supply

```bash
# Install PyVISA (if not in container)
pip3 install pyvisa pyvisa-py

# List VISA resources
python3 -c "import pyvisa; print(pyvisa.ResourceManager().list_resources())"
```

Expected output:

```
('USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR',)
```

#### Update Configuration (if different)

If your power supply has a different serial number, update `stm32_flash_api/app.py`:

**Find and replace on lines:** 172, 193, 236, 272, 286, 300, 330

```python
# Old:
inst=rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")

# New (example):
inst=rm.open_resource("USB0::0x0483::0x7540::YOUR_SERIAL_HERE::INSTR")
```

**Note:** The setup script (`setup.sh`) can detect and update this automatically.

### 6. Build Docker Images

The system uses a multi-stage Docker build process.

#### Step 6.1: Build Base STM32 Flash CLI Container

```bash
cd stm32_flash_cli
docker build -t stm32_flash_cli:0.1 .
```

#### Step 6.2: Install STM32 Cube Programmer Inside Container

```bash
# Start container interactively
docker run -it stm32_flash_cli:0.1

# Inside container, run:
cd /home/ubuntu/en.stm32cubeprg-lin-v2-18-0
./SetupSTM32CubeProgrammer-2.18.0.linux
# Accept all defaults

# Verify installation
ls /usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI

# Do NOT exit the container yet!
```

#### Step 6.3: Commit the Container

**In a NEW terminal** (keep the container running):

```bash
# Find container ID
docker ps

# Commit the container with STM32 Programmer installed
docker commit <CONTAINER_ID> stm32_flash_cli:1.1

# Now you can exit the running container
```

#### Step 6.4: Build STM32 Flash API Container

```bash
cd ../stm32_flash_api
docker build -t stm32_flash_api:2.2 .
cd ..
```

**Important:** The `docker_compose.yml` expects image `stm32_flash_api:2.2`. If you use a different tag, update the compose file.

### 7. Install Node-RED Dependencies

```bash
cd node-red-data
npm install
cd ..
```

This installs required Node-RED packages:
- `@flowfuse/node-red-dashboard` - Dashboard UI
- `node-red-contrib-modbus` - Modbus protocol support
- `node-red-contrib-mongodb3` - MongoDB integration
- `node-red-node-serialport` - Serial port communication

### 8. Start Services

```bash
# Start all services
docker compose -f docker_compose.yml up

# Or run in background
docker compose -f docker_compose.yml up -d

# View logs
docker compose -f docker_compose.yml logs -f

# Stop services
docker compose -f docker_compose.yml down
```

## Service Access

Once all services are running, access them via:

| Service | URL | Description |
|---------|-----|-------------|
| **Node-RED** | http://localhost:1880 | Flow-based automation interface |
| **STM32 Flash API** | http://localhost:5000 | REST API for STM32 programming |
| **MongoDB** | `localhost:27017` | Database (no web UI) |
| **Mongo Express** | http://localhost:8081 | MongoDB web admin interface |
| **Filebrowser** | http://localhost:8080 | File browser for firmware files |

## API Reference

### STM32 Flash API Endpoints

Base URL: `http://localhost:5000`

#### ST-Link Programmer

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/st_link/cli` | GET | Get ST-Link CLI info |
| `/api/st_link/read` | POST | Read flash memory |
| `/api/st_link/write` | GET | Write test binary to flash |
| `/api/st_link/write_prod` | GET | Write production firmware |
| `/api/st_link/erase` | GET | Erase flash memory |

**Example - Read Flash:**

```bash
curl -X POST http://localhost:5000/api/st_link/read \
  -H "Content-Type: application/json" \
  -d '{"start_address": "0x8000000", "no_of_bytes": 64}'
```

#### Power Supply Control

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/ps/device_list` | GET | List connected VISA devices |
| `/api/ps/info` | GET | Get power supply information |
| `/api/ps/ch1/set_voltage` | GET/POST | Get/Set channel 1 voltage |
| `/api/ps/ch1/set_current` | GET/POST | Get/Set channel 1 current |
| `/api/ps/ch1/measured_voltage` | GET | Read measured voltage |
| `/api/ps/ch1/measured_current` | GET | Read measured current |
| `/api/ps/ch1/on` | GET/POST | Turn channel 1 on |
| `/api/ps/ch1/off` | GET/POST | Turn channel 1 off |

**Example - Set Voltage:**

```bash
curl -X POST http://localhost:5000/api/ps/ch1/set_voltage \
  -H "Content-Type: application/json" \
  -d '{"set_volt": "12.0"}'
```

**Example - Turn Output On:**

```bash
curl -X POST http://localhost:5000/api/ps/ch1/on
```

#### File Upload

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/upload` | GET/POST | Upload firmware files (.bin, .hex, .txt) |

## Configuration

### Environment Variables

Currently, most configuration is hardcoded. See `.env.example` for reference configuration that may be supported in the future.

### Modifying Configuration

**Serial Ports:** Edit `node-red-data/flows.json` (lines 2698-2775)

**Power Supply VISA Address:** Edit `stm32_flash_api/app.py` (lines 172, 193, 236, 272, 286, 300, 330)

**LabJack IP Address:** Configured in Node-RED flows (IP: 192.168.8.148, Port: 502)

**MongoDB Authentication:** Currently disabled (commented out in `docker_compose.yml`)

## Verification & Testing

### 1. Check Container Status

```bash
docker compose ps
```

All services should show `Up` status.

### 2. Test ST-Link Connection

```bash
curl http://localhost:5000/api/st_link/cli
```

Should return ST-Link programmer information.

### 3. Test Power Supply

```bash
# List VISA devices
curl http://localhost:5000/api/ps/device_list

# Get power supply info
curl http://localhost:5000/api/ps/info
```

### 4. Test Serial Ports

In Node-RED (http://localhost:1880), check serial port nodes for connection status.

### 5. Test MongoDB

```bash
# Using mongo-express
# Open http://localhost:8081 in browser

# Or using command line
docker exec -it <mongodb_container_id> mongosh
```

## Troubleshooting

### Common Issues

#### 1. Serial Devices Not Found

**Problem:** `/dev/ttyUSB*` or `/dev/ttyACM*` not found

**Solutions:**
- Verify USB devices are connected: `lsusb`
- Check device permissions: `ls -l /dev/ttyUSB*`
- Add user to dialout group: `sudo usermod -aG dialout $USER` (logout/login required)
- Reconnect devices in correct order
- Check dmesg: `dmesg | tail -20`

#### 2. ST-Link Not Detected

**Problem:** ST-Link programmer not found

**Solutions:**
- Verify ST-Link connected: `lsusb | grep -i stm`
- Check container has USB access (privileged mode enabled)
- Try different USB port
- Update ST-Link firmware using STM32 Cube Programmer on host

#### 3. Power Supply Communication Errors

**Problem:** Cannot communicate with Siglent power supply

**Solutions:**
- Verify power supply is powered on
- Check USB connection: `lsusb | grep -i siglent`
- List VISA resources: `curl http://localhost:5000/api/ps/device_list`
- Update VISA address in `stm32_flash_api/app.py` if serial number differs
- Restart stm32_flash_api container

#### 4. Docker Permission Errors

**Problem:** Permission denied when accessing USB devices

**Solutions:**
- Ensure containers run in privileged mode (already configured in `docker_compose.yml`)
- Verify `/dev` mounted correctly
- Check SELinux/AppArmor policies (may need adjustment)

#### 5. STM32 Cube Programmer Not Found

**Problem:** Container cannot find STM32_Programmer_CLI

**Solutions:**
- Verify installer was extracted correctly in `stm32_flash_cli/en.stm32cubeprg-lin-v2-18-0/`
- Check installation completed inside container
- Verify committed correct container: `docker images | grep stm32_flash_cli`
- Rebuild from step 6.1

#### 6. Node-RED Dependencies Missing

**Problem:** Node-RED nodes show errors or missing packages

**Solutions:**
- Ensure `npm install` was run in `node-red-data/`
- Check `node-red-data/package.json` exists
- View Node-RED logs: `docker compose logs node-red`
- Restart Node-RED container

#### 7. Cannot Access Services

**Problem:** Cannot access web interfaces on localhost

**Solutions:**
- Check all containers running: `docker compose ps`
- Verify port mappings: `docker compose port node-red 1880`
- Check firewall rules
- Try `127.0.0.1` instead of `localhost`

For more detailed troubleshooting, see `docs/TROUBLESHOOTING.md`.

---

## Additional Documentation

- `docs/HARDWARE_SETUP.md` - Detailed hardware connection guide
- `docs/TROUBLESHOOTING.md` - Extended troubleshooting guide
- `.env.example` - Environment variable reference

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review Node-RED flow documentation in the UI
3. Check container logs: `docker compose logs <service-name>`

---

**Last Updated:** 2026-02-04

