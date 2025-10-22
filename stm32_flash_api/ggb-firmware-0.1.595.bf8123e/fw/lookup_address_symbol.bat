@echo off

rem Arguments:
rem $1: Address (hex with 0x prefix)
rem $2: ELF file path
rem $3: objdump path (optional)
REM Path to programmer executable

set OBJDUMP=c:\ST\STM32CubeIDE_1.12.1\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.gnu-tools-for-stm32.12.3.rel1.win32_1.0.200.202406191623\tools\bin\arm-none-eabi-objdump.exe

if "%~2"=="" (  
  echo [101m Usage: %~0 ElfFile SymbolAddress [ObjdumpPath] [0m
  set success=0
  exit /b
)

if NOT "%~3"=="" (
  set OBJDUMP="%~3"
)

rem Look in C:\ST for exe if not correct
if NOT exist "%OBJDUMP%" (
  echo [104m Searching C:\ST for arm-none-eabi-objdump.exe [0m
  for /r C:\ST %%a in (*) do if "%%~nxa"=="arm-none-eabi-objdump.exe" set OBJDUMP=%%~dpnxa
)

if NOT exist "%OBJDUMP%" (
  echo [101m Couldn't find arm-none-eabi-objdump.exe [0m
)

echo Using "%OBJDUMP%"

set address=%~2
set elf_file=%~1

set /a "end_address = %address% + 1"

echo Address=%address% End=%end_address% ELF=%elf_file%

rem echo "%OBJDUMP%" -d  --start-address "%address%" --stop-address "%end_address%" "%elf_file%"
"%OBJDUMP%" -d  --start-address "%address%" --stop-address "%end_address%" "%elf_file%"

exit /b
