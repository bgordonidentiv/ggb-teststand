import pyvisa
import time

rm = pyvisa.ResourceManager()

inst=rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")
inst.write_termination='\n'
inst.read_termination='\n'
# print(rm.list_resources())
# for i in range(10):
time.sleep(0.04)
inst.write('*IDN?')
# inst.write('INST?')
time.sleep(0.25) # I guess the power supply needs a bit of time before reading
qStr = inst.read()
print(str(qStr))
