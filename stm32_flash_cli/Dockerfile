# Start with a clean Ubuntu image
FROM ubuntu:20.04

# Copy the SMT32 Cube Programmer install
COPY en.stm32cubeprg-lin-v2-18-0 /home/ubuntu/en.stm32cubeprg-lin-v2-18-0

RUN apt-get update

# Required from the SMT32CubeProgrammer
RUN apt-get install libusb-1.0-0-dev -y
RUN apt-get install libglib2.0-0 -y
RUN apt-get install libkrb5-dev -y

# Adding so I can check that ST-Link device is connected (lsusb)
RUN apt-get install usbutils -y
