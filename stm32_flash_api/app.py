import subprocess
import pyvisa 
import time
import re
from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

@app.route('/read')
def read_flash():
    result = subprocess.run(['/usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI', '-c port=swd -r32 0x8000000 64'], capture_output=True, text=True)
    output = result.stdout

    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean_output = ansi_escape.sub('', output)    
    formatted_output = f"<pre>{clean_output}</pre>"

    # return render_template_string(formatted_output)
    return jsonify({"output": clean_output, "error": result.stderr, "returncode": result.returncode})

@app.route('/ps')
def read_ps():
    rm = pyvisa.ResourceManager()

    inst=rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")
    inst.write_termination='\n'
    inst.read_termination='\n'
    time.sleep(0.04)
    inst.write('*IDN?')
    time.sleep(0.25) # I guess the power supply needs a bit of time before reading
    qStr = inst.read()
    return qStr 

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
