# Hardware Setup Guide

This document provides detailed instructions for connecting and configuring all hardware components for the GGB Teststand.

## Table of Contents

- [Overview](#overview)
- [Hardware Checklist](#hardware-checklist)
- [Connection Sequence](#connection-sequence)
- [Detailed Component Setup](#detailed-component-setup)
  - [Host Computer Setup](#host-computer-setup)
  - [ST-Link Programmer](#st-link-programmer)
  - [FTDI USB-to-Serial Cables](#ftdi-usb-to-serial-cables)
  - [ESP32 Serial Connection](#esp32-serial-connection)
  - [Siglent Power Supply](#siglent-power-supply)
  - [LabJack T7 Data Acquisition](#labjack-t7-data-acquisition)
- [Physical Layout Recommendations](#physical-layout-recommendations)
- [Cable Management](#cable-management)
- [Verification Procedures](#verification-procedures)
- [Hardware Specifications](#hardware-specifications)

## Overview

The GGB Teststand requires multiple hardware components that must be connected in a specific order to ensure proper device enumeration and stable operation.

**Connection Diagram:**

```
┌─────────────────────────────────────────────────────────────┐
│                     Host Computer                           │
│                  (Linux/macOS/WSL2)                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            Docker Containers                         │  │
│  │  ┌──────────┐  ┌───────────┐  ┌──────────────┐     │  │
│  │  │ Node-RED │  │ STM32 API │  │  MongoDB     │     │  │
│  │  └──────────┘  └───────────┘  └──────────────┘     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │           │           │           │          │
         │           │           │           │          │
    USB  │      USB  │      USB  │      USB  │     Ethernet
         │           │           │           │          │
         ▼           ▼           ▼           ▼          ▼
   ┌─────────┐ ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐
   │FTDI #1  │ │FTDI #2 │  │FTDI #3 │  │ESP32   │  │LabJack │
   │ttyUSB0  │ │ttyUSB1 │  │ttyUSB2 │  │ttyACM0 │  │  T7    │
   │ Debug   │ │Reader1 │  │Reader2 │  │        │  │        │
   └─────────┘ └────────┘  └────────┘  └────────┘  └────────┘
                                           
         ┌──────────┐              ┌──────────────┐
         │ ST-Link  │              │  Siglent PSU │
         │  USB     │              │  USB VISA    │
         └──────────┘              └──────────────┘
              │                            │
              │ SWD                        │ Power
              ▼                            ▼
         ┌──────────┐              ┌──────────────┐
         │   DUT    │◄─────────────┤    Test      │
         │  STM32   │    Power     │   Fixture    │
         └──────────┘              └──────────────┘
```

## Hardware Checklist

### Required Components

- [ ] **Host Computer**
  - Linux (Ubuntu 20.04+, Debian 11+, etc.)
  - macOS (10.15+)
  - Windows 10/11 with WSL2
  - Minimum 4 USB ports available
  - 8GB+ RAM recommended
  - 10GB+ free disk space

- [ ] **ST-Link V2 or V3 Programmer**
  - USB cable included
  - Compatible with STM32 microcontrollers
  - Firmware updated to latest version

- [ ] **3x FTDI USB-to-Serial Cables**
  - FTDI FT232R or FT232H chipset
  - 3.3V or 5V TTL levels
  - TX, RX, GND connections minimum

- [ ] **ESP32 USB Serial Adapter**
  - Usually built into ESP32 dev board
  - CP210x or CH340 USB-to-serial chip

- [ ] **Siglent SPD3303C Power Supply** (or compatible)
  - USB cable (Type-B typically)
  - VISA/SCPI command support
  - Channel 1 configured for DUT power

- [ ] **LabJack T7 or T7-PRO**
  - Ethernet cable (Cat5e or better)
  - Power supply (included with LabJack)
  - Static IP configured: 192.168.8.148

### Optional Components

- [ ] USB hub (powered, 7+ ports recommended)
- [ ] Ethernet switch (if LabJack not on main network)
- [ ] Cable labels/markers
- [ ] ESD protection mat
- [ ] Cable ties/management

## Connection Sequence

**IMPORTANT:** Connect devices in this exact order for consistent device enumeration.

### Step 1: Network Setup

1. **Connect LabJack T7 to Network**
   - Connect Ethernet cable from LabJack to your network
   - Power on LabJack T7
   - Configure static IP: 192.168.8.148
   - Verify connectivity: `ping 192.168.8.148`

**LabJack Configuration:**
```bash
# Access LabJack configuration
# Open browser: https://192.168.8.148

# Or use LabJack Kipling software:
# 1. Download from: https://labjack.com/pages/support
# 2. Install Kipling
# 3. Connect to device
# 4. Set static IP: 192.168.8.148
# 5. Subnet: 255.255.255.0
# 6. Gateway: (your network gateway)
```

### Step 2: FTDI Serial Cables (in order)

2. **Connect FTDI Cable #1 (Serial Debug) → /dev/ttyUSB0**
   - Connect to USB port
   - Wait for device enumeration
   - Verify: `ls -l /dev/ttyUSB0`

3. **Connect FTDI Cable #2 (Reader1 RS485) → /dev/ttyUSB1**
   - Connect to USB port
   - Wait for device enumeration
   - Verify: `ls -l /dev/ttyUSB1`

4. **Connect FTDI Cable #3 (Reader2 RS485) → /dev/ttyUSB2**
   - Connect to USB port
   - Wait for device enumeration
   - Verify: `ls -l /dev/ttyUSB2`

**Verification:**
```bash
# All three FTDI devices should be present
ls -l /dev/ttyUSB*
# Should show: ttyUSB0, ttyUSB1, ttyUSB2

# Check FTDI devices via USB
lsusb | grep -i ftdi
```

### Step 3: ESP32 Serial Connection

5. **Connect ESP32 Serial Adapter → /dev/ttyACM0**
   - Connect ESP32 dev board or serial adapter
   - Wait for device enumeration
   - Verify: `ls -l /dev/ttyACM0`

### Step 4: ST-Link Programmer

6. **Connect ST-Link Programmer**
   - Connect ST-Link to USB port
   - ST-Link does not need specific device order
   - Verify: `lsusb | grep -i stm`

**ST-Link Verification:**
```bash
# Check if ST-Link is detected
lsusb | grep "0483:374" || lsusb | grep "STMicro"

# If using STM32 Cube Programmer CLI:
STM32_Programmer_CLI -l
# Should list connected ST-Link devices
```

### Step 5: Siglent Power Supply

7. **Connect Siglent Power Supply**
   - Connect USB cable (Type-B) from power supply to computer
   - Power on the supply
   - Wait for VISA device enumeration
   - Verify: `lsusb | grep -i siglent`

**Power Supply Verification:**
```bash
# Install PyVISA if not already installed
pip3 install pyvisa pyvisa-py

# List VISA resources
python3 -c "import pyvisa; print(pyvisa.ResourceManager().list_resources())"

# Expected output:
# ('USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR',)
```

## Detailed Component Setup

### Host Computer Setup

#### Linux

1. **Install Docker and Docker Compose**
```bash
# Update package manager
sudo apt update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose (if not included)
sudo apt install docker-compose-plugin
```

2. **Configure USB Permissions**
```bash
# Add user to dialout group for serial port access
sudo usermod -aG dialout $USER

# Logout and login for changes to take effect
```

3. **Install USB Tools**
```bash
sudo apt install usbutils  # for lsusb
sudo apt install python3 python3-pip  # for power supply detection
```

#### macOS

1. **Install Docker Desktop**
   - Download from: https://www.docker.com/products/docker-desktop
   - Install and start Docker Desktop
   - Enable Docker Compose

2. **Install Homebrew** (if not installed)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

3. **Install USB Tools**
```bash
brew install python3
brew install usbutils  # Optional, provides lsusb
```

#### Windows WSL2

1. **Install WSL2 with Ubuntu**
```powershell
# Run in PowerShell as Administrator
wsl --install
wsl --set-default-version 2
```

2. **Install Docker Desktop for Windows**
   - Enable WSL2 backend in Docker Desktop settings
   - Enable integration with your WSL2 Ubuntu distribution

3. **Configure USB Passthrough** (Advanced)
   - Follow: https://learn.microsoft.com/en-us/windows/wsl/connect-usb
   - Install usbipd-win on Windows
   - Attach USB devices to WSL2

### ST-Link Programmer

#### Physical Connection

1. **ST-Link Pinout (SWD Interface)**
   - Pin 1: VCC (3.3V target power reference)
   - Pin 2: SWCLK (Serial Wire Clock)
   - Pin 3: GND (Ground)
   - Pin 4: SWDIO (Serial Wire Data I/O)
   - Pin 5: NRST (Reset, optional)
   - Pin 6: SWO (Serial Wire Output, optional)

2. **Connect to Target (STM32 DUT)**
   ```
   ST-Link          STM32 Target
   -------          ------------
   SWCLK    ──────► SWCLK
   SWDIO    ──────► SWDIO
   GND      ──────► GND
   NRST     ──────► NRST (optional)
   ```

3. **Power Considerations**
   - ST-Link VCC is for voltage reference only
   - Target must be powered separately (via test fixture/power supply)
   - Do not power target from ST-Link

#### Software Configuration

**Update ST-Link Firmware** (recommended):
1. Download STM32 Cube Programmer
2. Connect ST-Link
3. Open STM32 Cube Programmer GUI
4. Click "Firmware Upgrade" button
5. Follow prompts to update

**Test Connection:**
```bash
# Inside stm32_flash_api container:
STM32_Programmer_CLI -l

# Should show:
# ST-LINK Probe 0:
#   ST-Link SN  : [serial number]
#   ST-Link FW  : V2.J43.S7 or similar
```

### FTDI USB-to-Serial Cables

#### Cable Identification

Each FTDI cable has a unique serial number. To identify:

```bash
# List all USB devices with details
lsusb -v | grep -A 5 "FTDI"

# Or use udevadm for specific device
udevadm info -a -n /dev/ttyUSB0 | grep serial

# Example output:
# ATTRS{serial}=="A50285BI"
```

**Record Serial Numbers:**

| Cable # | Serial Number | Assignment | Device Path |
|---------|---------------|------------|-------------|
| 1       | _________     | Debug      | /dev/ttyUSB0 |
| 2       | _________     | Reader1    | /dev/ttyUSB1 |
| 3       | _________     | Reader2    | /dev/ttyUSB2 |

#### Physical Connections

**FTDI Cable Pinout** (typical 6-pin):
```
┌────────────────┐
│ 1: GND  (Black)│
│ 2: CTS  (Brown)│──── Usually not connected
│ 3: VCC  (Red)  │──── 5V or 3.3V (check cable spec)
│ 4: TXD  (Orange)│──► Connect to target RX
│ 5: RXD  (Yellow)│◄─── Connect to target TX
│ 6: RTS  (Green)│──── Usually not connected
└────────────────┘
```

**Connection to Target:**
- FTDI TXD → Target RXD
- FTDI RXD → Target TXD
- FTDI GND → Target GND
- VCC: Only connect if target needs external power

**RS485 Connections (Reader1 & Reader2):**
If using RS485, you'll need an FTDI-to-RS485 adapter:
- A (Data+) → RS485 A
- B (Data-) → RS485 B
- GND → RS485 GND

#### Permissions

```bash
# Check current permissions
ls -l /dev/ttyUSB*

# Should show: crw-rw---- 1 root dialout
# Your user must be in 'dialout' group

# Add user to dialout group (if not already)
sudo usermod -aG dialout $USER

# Logout/login required for group change to take effect
```

### ESP32 Serial Connection

The ESP32 typically uses a CP210x or CH340 USB-to-serial chip, which appears as `/dev/ttyACM0` on Linux.

#### Connection

1. **Connect ESP32 Development Board**
   - Use standard USB cable (typically USB-C or Micro-USB)
   - ESP32 dev boards have built-in USB-to-serial conversion
   - No additional wiring needed if using dev board

2. **Verify Connection**
```bash
# Check device
ls -l /dev/ttyACM0

# Check USB info
lsusb | grep -E "CP210|CH340|Silicon Labs"

# Test communication (optional)
screen /dev/ttyACM0 115200
# Press Ctrl-A, K to exit screen
```

#### Driver Installation

**Linux:** Usually automatic

**macOS:** May require driver:
- CP210x: https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers
- CH340: https://github.com/adrianmihalko/ch340g-ch34g-ch34x-mac-os-x-driver

**Windows/WSL2:** Install Windows drivers, then attach to WSL

### Siglent Power Supply

#### USB Connection

1. **Connect USB Cable**
   - Use USB Type-B cable (printer-style)
   - Connect from power supply rear panel to computer USB port
   - Power on the supply

2. **Verify VISA Connection**
```bash
# List VISA resources
python3 -c "import pyvisa; rm = pyvisa.ResourceManager(); print(rm.list_resources())"

# Expected:
# ('USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR',)
```

3. **Test Communication**
```bash
# Query power supply identity
python3 << EOF
import pyvisa
rm = pyvisa.ResourceManager()
inst = rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")
inst.write_termination = '\n'
inst.read_termination = '\n'
inst.write('*IDN?')
print(inst.read())
EOF

# Expected output:
# Siglent Technologies,SPD3303C,[serial],[version]
```

#### Front Panel Configuration

1. **Initial Setup**
   - Set Channel 1 voltage limit (e.g., 24V max)
   - Set Channel 1 current limit (e.g., 3A max)
   - Enable OCP (Over-Current Protection)
   - Enable OVP (Over-Voltage Protection)

2. **Remote Control Mode**
   - Press "System" → "Remote" → "USB"
   - Power supply will be controlled via API

### LabJack T7 Data Acquisition

#### Network Connection

1. **Physical Connection**
   - Connect Ethernet cable from LabJack to network switch/router
   - Connect power supply to LabJack
   - Power on LabJack (red power LED should illuminate)

2. **Configure Static IP**

**Method 1: Using Kipling Software**
   - Download Kipling: https://labjack.com/pages/support
   - Install and launch Kipling
   - Device should auto-discover
   - Go to Network settings
   - Set Static IP: 192.168.8.148
   - Subnet: 255.255.255.0
   - Gateway: (your network gateway IP)
   - Click "Write"

**Method 2: Using Web Interface**
   - Discover device IP using Kipling or check DHCP lease
   - Open browser to current IP
   - Navigate to Network settings
   - Configure as above

3. **Verify Connection**
```bash
# Ping LabJack
ping 192.168.8.148

# Test Modbus TCP connection (port 502)
nc -zv 192.168.8.148 502
# Should show: Connection to 192.168.8.148 502 port [tcp/mbap] succeeded!
```

#### Modbus Configuration

The LabJack T7 uses Modbus TCP protocol on port 502.

**Common Modbus Registers** (from flows.json):
- Modbus address: 192.168.8.148:502
- Unit ID: 1 (typically)
- Function codes: Read/write registers

**Test Modbus Connection:**
```bash
# Using Python modbus library
pip3 install pymodbus

python3 << EOF
from pymodbus.client import ModbusTcpClient
client = ModbusTcpClient('192.168.8.148', port=502)
if client.connect():
    print("✓ Modbus connection successful")
    client.close()
else:
    print("✗ Modbus connection failed")
EOF
```

## Physical Layout Recommendations

### Workbench Organization

```
┌────────────────────────────────────────────────────┐
│                  Wall/Back                         │
│                                                    │
│  ┌──────────┐     ┌─────────────┐                 │
│  │ Monitor  │     │   Siglent   │                 │
│  │          │     │  Power PSU  │                 │
│  └──────────┘     └─────────────┘                 │
│                                                    │
│  ┌──────────────────────────────┐                 │
│  │      Host Computer           │                 │
│  │   (USB ports accessible)     │                 │
│  └──────────────────────────────┘                 │
│                                                    │
│         ┌────────────────┐                        │
│         │  Test Fixture  │                        │
│         │   with DUT     │                        │
│         └────────────────┘                        │
│                                                    │
│  ST-Link    FTDI Cables     ESP32                 │
│  (on desk, accessible)                            │
└────────────────────────────────────────────────────┘
```

### Cable Routing

1. **USB Cables**
   - Keep USB cables < 3 meters (< 10 feet) for reliable operation
   - Use quality cables with ferrite beads for noise reduction
   - Route away from power cables and AC sources
   - Label each cable clearly

2. **Network Cable**
   - Use Cat5e or better for LabJack
   - Keep away from AC power and fluorescent lighting
   - Secure cable to prevent accidental disconnection

3. **Power Supply Cables**
   - Use appropriate gauge wire for current load
   - Twist positive and negative wires together
   - Keep power cables separate from signal cables
   - Use banana plug connectors for secure connection

## Cable Management

### Labeling System

Create labels for all cables:

| Cable Type | Label Format | Example |
|------------|-------------|---------|
| FTDI #1    | "USB0-DEBUG" | Red label |
| FTDI #2    | "USB1-RDR1" | Yellow label |
| FTDI #3    | "USB2-RDR2" | Green label |
| ESP32      | "ACM0-ESP32" | Blue label |
| ST-Link    | "STLINK" | White label |
| Power Supply | "PSU-USB" | Orange label |

### Cable Ties and Organization

1. Use Velcro cable ties (reusable)
2. Bundle cables by type
3. Leave slack for device removal/reconnection
4. Secure bundles to desk edge or cable tray

## Verification Procedures

### Complete System Check

After connecting all hardware, run these verification steps:

```bash
# 1. Check all USB devices
lsusb
# Should show: ST-Link, FTDI (x3), ESP32, Siglent

# 2. Check serial ports
ls -l /dev/ttyUSB* /dev/ttyACM*
# Should show: ttyUSB0, ttyUSB1, ttyUSB2, ttyACM0

# 3. Check VISA devices
python3 -c "import pyvisa; print(pyvisa.ResourceManager().list_resources())"
# Should show: USB0::0x0483::0x7540::...::INSTR

# 4. Check LabJack connectivity
ping -c 4 192.168.8.148
# Should show: 4 packets transmitted, 4 received

# 5. Run setup script verification
./setup.sh --check-only
```

### Individual Device Tests

**Test ST-Link:**
```bash
docker run -it --privileged -v /dev:/dev stm32_flash_api:2.2 \
  /usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI -l
```

**Test Serial Ports:**
```bash
# Install screen if not available
sudo apt install screen  # Linux
brew install screen      # macOS

# Test each port (press Ctrl-A, K to exit)
screen /dev/ttyUSB0 115200
screen /dev/ttyUSB1 115200
screen /dev/ttyUSB2 115200
screen /dev/ttyACM0 115200
```

**Test Power Supply:**
```bash
curl http://localhost:5000/api/ps/device_list  # After starting containers
curl http://localhost:5000/api/ps/info
```

## Hardware Specifications

### ST-Link V2 Specifications

- Interface: USB 2.0 Full Speed
- Target voltage: 3.0V to 3.6V
- Programming speed: Up to 8 MHz SWD clock
- Supported: STM32, STM8 microcontrollers
- Cable length: 20cm typically
- Power consumption: <100mA from USB

### FTDI FT232R Specifications

- Interface: USB 2.0 Full Speed
- Data rate: Up to 3 Mbaud (RS232)
- Supply voltage: 4.35V to 5.25V from USB
- I/O voltage: 3.3V or 5V (cable dependent)
- Transmit/Receive buffers: 256 bytes
- Operating temp: 0°C to 70°C

### Siglent SPD3303C Specifications

- Channels: 3 (2 x 30V/3A + 1 x 2.5V/3.3V/5V fixed)
- Resolution: 10mV, 10mA
- Accuracy: ±(0.03% + 10mV)
- Communication: USB, RS232, LAN (optional)
- SCPI command compatible
- Protection: OVP, OCP, OTP

### LabJack T7 Specifications

- Analog inputs: 14 single-ended (7 differential)
- Resolution: 16-bit (up to 24-bit with averaging)
- Sample rate: Up to 100 kS/s
- Digital I/O: 23 flexible I/O
- Communication: Ethernet, USB, WiFi (optional)
- Modbus TCP/UDP support
- Supply voltage: 5V via USB or external

---

## Troubleshooting Hardware Issues

For common hardware problems, see `TROUBLESHOOTING.md`.

## Additional Resources

- ST-Link: https://www.st.com/en/development-tools/st-link-v2.html
- FTDI Drivers: https://ftdichip.com/drivers/
- Siglent Manual: https://siglentna.com/product/spd3303c/
- LabJack Support: https://labjack.com/pages/support

---

**Document Version:** 1.0  
**Last Updated:** 2026-02-04
