import subprocess
import pyvisa 
import time
import re
from flask import Flask, jsonify, request

app = Flask(__name__)

delay = 0.5 # Delay for while communicating over USB to the power supply

@app.route('/read')
def read_flash():
    result = subprocess.run(['/usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI', '-c port=swd -r32 0x8000000 64'], capture_output=True, text=True)
    output = result.stdout

    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean_output = ansi_escape.sub('', output)    
    formatted_output = f"<pre>{clean_output}</pre>"

    # return render_template_string(formatted_output)
    return jsonify({"output": clean_output, "error": result.stderr, "returncode": result.returncode})

@app.route('/ps/list')
def list_ps():
    rm = pyvisa.ResourceManager()
    data = {
        "device" : rm.list_resources()
    }
    return jsonify(data)


@app.route('/ps/info')
def read_ps():
    rm = pyvisa.ResourceManager()

    inst=rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")
    inst.write_termination='\n'
    inst.read_termination='\n'
    time.sleep(0.04)
    inst.write('*IDN?')
    time.sleep(0.25) # I guess the power supply needs a bit of time before reading
    qStr = inst.read()
    info_list = qStr.split(",")
    data = {
        "Manufacturer" : info_list[0],
        "Product Model" : info_list[1],
        "Serial Number" : info_list[2],
        "Software Version" : info_list[3]
    }
    data_out = jsonify(data)
    # inst.close()
    return data_out 

@app.route('/ps/ch1/voltage', methods=["POST", "GET"])
def read_volt_ch1():
    rm = pyvisa.ResourceManager()
    inst=rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")
    inst.write_termination='\n'
    inst.read_termination='\n'
    time.sleep(0.04)

    if request.method == "POST":
        # setVoltage = request.form["set_volt"]
        # return f"POST Received for CH1 Voltage ({setVoltage})"

        # Get the JSON data from the request body
        data = request.get_json()

        if not data:
            return jsonify({"error" : "No JSON data provided"}), 400

        # Access fields in the JSON payload
        setVoltage = data.get('set_volt')

        psMsg = f'CH1:VOLTage {setVoltage}'

        inst.write(psMsg)
        time.sleep(delay) # I guess the power supply needs a bit of time before reading
        inst.write('CH1:VOLTage?') # Added this read because each time I did only the write above the USB would hang
        time.sleep(delay)
        qStr = inst.read()

        return jsonify({"status": "success", "set_voltage" : float(setVoltage), "channel" : "1", "voltage" : float(qStr)}), 200
    else:
        inst.write('CH1:VOLTage?')
        time.sleep(0.25) # I guess the power supply needs a bit of time before reading
        qStr = inst.read()
        data = {
            "channel" : "1",
            "voltage" : qStr
        }
        data_out = jsonify(data)
        # inst.close()
        return data_out 

@app.route('/ps/ch1/current', methods=["POST", "GET"])
def read_curr_ch1():
    rm = pyvisa.ResourceManager()

    inst=rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")
    inst.write_termination='\n'
    inst.read_termination='\n'
    time.sleep(0.04)
    if request.method == "POST":
        # Get the JSON data from the request body
        data = request.get_json()

        if not data:
            return jsonify({"error" : "No JSON data provided"}), 400
        
        # Access fields in the JSON payload
        setCurrent = data.get('set_current')

        psMsg = f'CH1:CURRent {setCurrent}'
        inst.write(psMsg)
        time.sleep(delay) # I guess the power supply needs a bit of time before reading
        inst.write('CH1:CURRent?') # Added this read because each time I did only the write above the USB would hang
        time.sleep(delay)
        qStr = inst.read()
        return jsonify({"status": "success", "set_current" : float(setCurrent), "channel" : "1", "current" : float(qStr)}), 200
    else:
        inst.write('CH1:CURRent?')
        time.sleep(0.25)
        qStr = inst.read()
        data = {
            "channel" : "1",
            "current" : qStr
        }
        data_out = jsonify(data)
        return data_out

@app.route('/ps/ch1/on', methods=["POST", "GET"])
def set_ch1_on():
    rm = pyvisa.ResourceManager()

    inst=rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")
    inst.write_termination='\n'
    inst.read_termination='\n'
    time.sleep(0.04)
    if request.method == "POST":
        psMsg = 'OUTPut CH1,ON'
        inst.write(psMsg)
        time.sleep(0.25)
        inst.write('SYSTem:STATus?')
        time.sleep(0.25)
        qStr = inst.read()
        if (int(qStr,16) & 0x0010) != 0:
            state = 'on'
        else:
            state = 'off'
        return jsonify({"status": "success", "msg": state}), 200
    else:
        inst.write('SYSTem:STATus?')
        time.sleep(0.25)
        qStr = inst.read()
        if (int(qStr,16) & 0x0010) != 0:
            state = 'on'
        else:
            state = 'off'
        return jsonify({"status": "success", "msg": state}), 200

@app.route('/ps/ch1/off', methods=["POST", "GET"])
def set_ch1_off():
    rm = pyvisa.ResourceManager()

    inst=rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")
    inst.write_termination='\n'
    inst.read_termination='\n'
    time.sleep(0.04)
    if request.method == "POST":
        psMsg = 'OUTPut CH1,OFF'
        inst.write(psMsg)
        time.sleep(0.25)
        inst.write('SYSTem:STATus?')
        time.sleep(0.25)
        qStr = inst.read()
        if (int(qStr,16) & 0x0010) != 0:
            state = 'on'
        else:
            state = 'off'
        return jsonify({"status": "success", "msg": state}), 200
    else:
        inst.write('SYSTem:STATus?')
        time.sleep(0.25)
        qStr = inst.read()
        if (int(qStr,16) & 0x0010) != 0:
            state = 'on'
        else:
            state = 'off'
        return jsonify({"status": "success", "msg" : state}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
