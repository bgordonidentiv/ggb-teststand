@echo off
REM Path to programmer executable
set PROGRAMMER="C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe"

REM ID of ST-Link device. Will be zero if only one ST-Link connected.
REM If more than one connected, will need to find the ID of ther correct device by uncommenting 
REM the line below and looking for "ST-LINK Probe #" in the output:-
REM %PROGRAMMER% -l && exit /b

set STLINK_NUM=0
set STLINK_CONNECT=-c port=SWD index=%STLINK_NUM%

if "%~1"=="" (
  echo [101m Usage: %0 application_file-signed.bin [bootloader_file.elf] [0m
  set success=0
  exit /b
)

set SIGNED_BIN=%~1
set BOOTLOADER=%~2

REM Reset 
echo [104m Please ensure the board is powered on, then press any key [0m
timeout /t -1

REM Erase not necessary
REM %PROGRAMMER% -c port=SWD index=%STLINK_NUM%  -e all

REM Download application to active slot and backup slots
echo [104m Downloading App to XIP Slot.. [0m
%PROGRAMMER% %STLINK_CONNECT%  -w %SIGNED_BIN% 0x08020000
set RcAppXIP=%ERRORLEVEL%

echo [104m Downloading App to Backup Slot A... [0m
%PROGRAMMER% %STLINK_CONNECT%  -w %SIGNED_BIN% 0x080BA000
set RcAppA=%ERRORLEVEL%

echo [104m Downloading App to Backup Slot B... [0m
%PROGRAMMER% %STLINK_CONNECT%  -w %SIGNED_BIN% 0x08154000
set RcAppB=%ERRORLEVEL%

REM Download bootloader
set RcBoot=0

if NOT "%BOOTLOADER%"=="" (
  echo [104m Downloading Bootloader... [0m
  %PROGRAMMER% %STLINK_CONNECT%  -w %BOOTLOADER%
  set RcBoot=%ERRORLEVEL%
)

%PROGRAMMER% %STLINK_CONNECT%  -hardRst

echo Complete
set success=1
if NOT %RcAppA%==0 (
  echo [101m Failed programming Application to Slot A [0m
  set success=0
)
if NOT %RcAppXIP%==0 (
  echo [101m Failed programming Application to XIP Slot [0m
  set success=0
)
if NOT %RcAppB%==0 (
  echo [101m Failed programming Application to Slot B [0m
  set success=0
)
if NOT %RcBoot%==0 (
  echo [101m Failed programming Bootloader [0m
  set success=0
)

if %success%==1 (
  echo [102m All binaries downloaded successfully [0m
)
