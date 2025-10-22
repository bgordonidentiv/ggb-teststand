#!/bin/bash

# Path to programmer executable
# PROGRAMMER="/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin/STM32_Programmer_CLI"
PROGRAMMER="/usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI"

# ID of ST-Link device. Will be zero if only one ST-Link connected.
# If more than one connected, will need to find the ID of the correct device by uncommenting 
# the line below and looking for "ST-LINK Probe #" in the output:
# $PROGRAMMER -l && exit 1

STLINK_NUM=0
STLINK_CONNECT="-c port=SWD index=$STLINK_NUM"

if [ $# -eq 0 ]; then
    echo -e "\e[101m Usage: $0 application_file-signed.bin [bootloader_file.elf] \e[0m"
    success=0
    exit 1
fi

SIGNED_BIN="$1"
BOOTLOADER="$2"

# Reset 
#echo -e "\e[104m Please power-cycle the board, or turn the board on, then press any key \e[0m"
#read -r -n 1 -s

# Erase not necessary
# $PROGRAMMER -c port=SWD index=$STLINK_NUM -e all

# Download application to active slot and backup slots
echo -e "\e[104m Downloading App to XIP Slot.. \e[0m"
$PROGRAMMER "$STLINK_CONNECT" -w "$SIGNED_BIN" 0x08020000
RcAppXIP=$?

echo -e "\e[104m Downloading App to Backup Slot A... \e[0m"
$PROGRAMMER "$STLINK_CONNECT" -w "$SIGNED_BIN" 0x080BA000
RcAppA=$?

echo -e "\e[104m Downloading App to Backup Slot B... \e[0m"
$PROGRAMMER "$STLINK_CONNECT" -w "$SIGNED_BIN" 0x08154000
RcAppB=$?

# Download bootloader
RcBoot=0

if [ -n "$BOOTLOADER" ]; then
    echo -e "\e[104m Downloading Bootloader... \e[0m"
    $PROGRAMMER "$STLINK_CONNECT" -w "$BOOTLOADER"
    RcBoot=$?
fi

$PROGRAMMER "$STLINK_CONNECT" -hardRst

echo "Complete"
success=1

if [ $RcAppA -ne 0 ]; then
    echo -e "\e[101m Failed programming Application to Slot A \e[0m"
    success=0
fi

if [ $RcAppXIP -ne 0 ]; then
    echo -e "\e[101m Failed programming Application to XIP Slot \e[0m"
    success=0
fi

if [ $RcAppB -ne 0 ]; then
    echo -e "\e[101m Failed programming Application to Slot B \e[0m"
    success=0
fi

if [ $RcBoot -ne 0 ]; then
    echo -e "\e[101m Failed programming Bootloader \e[0m"
    success=0
fi

if [ $success -eq 1 ]; then
    echo -e "\e[102m All binaries downloaded successfully \e[0m"
fi

exit $success