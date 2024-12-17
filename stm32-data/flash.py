import subprocess

result = subprocess.run(['/usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI', '-c port=swd -r32 0x8000000 64'], capture_output=True, text=True)

print("Output:")
print(result.stdout)
print("Errors:")
print(result.stderr)
print("Return Code:")
print(result.returncode)