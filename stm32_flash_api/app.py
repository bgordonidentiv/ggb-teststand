##############################################################
#
# ST-LINK
# /read
#
# POWER SUPPLY
# /api/ps/device_list           = Get a list of connected devices
# /api/ps/info                  = Get Power Supply Info
# /api/ps/ch1/set_voltage       = Read/Write Set Voltage 
# /api/ps/ch1/set_current       = Read/Write Set Current
# /api/ps/ch1/measured_voltage  = Read Measured Voltage
# /api/ps/ch1/measured_current  = Read Measured Current
# /api/ps/ch1/on                = Read/Write ON 
# /api/ps/ch1/off               = Read/Write OFF
#
##############################################################

import subprocess
import pyvisa 
import time
import re
import os
from flask import Flask, jsonify, request, render_template, redirect, url_for, flash

app = Flask(__name__)
app.secret_key = "your_secret_key"

UPLOAD_FOLDER = '/home/ubuntu/ggb_test_bins/'
ALLOWED_EXTENSIONS = {'bin', 'hex', 'txt'}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and \
        filename.rsplit('.',1)[1].lower() in ALLOWED_EXTENSIONS

delay = 0.5 # Delay for while communicating over USB to the power supply

@app.route('/upload', methods=['GET', 'POST'])
def upload_page():
    if request.method == 'POST':
        # Check if file part exists
        if 'file' not in request.files:
            flash('No file part')
            return redirect(request.url)

        file = request.files['file']

        if file.filename == '':
            flash('No file selected')
            return redirect(request.url)

        if file and allowed_file(file.filename):
            filename = file.filename
            save_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
            file.save(save_path)
            flash(f"File uploaded successfully: {filename}")
            return redirect(request.url)

        flash('Invalid file type')
        return redirect(request.url)

    return render_template('upload.html')

@app.route('/api/st_link/cli')
def cli_info():
    result = subprocess.run(['/usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI'], capture_output=True, text=True)
    output = result.stdout

    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean_output = ansi_escape.sub('', output)    

    # return render_template_string(formatted_output)
    return jsonify({"output": clean_output, "error": result.stderr, "returncode": result.returncode})

@app.route('/api/st_link/read', methods=["POST"])
def read_flash():

    # Get the JSON data from the request body
    data = request.get_json()

    startAddress = data.get('start_address')
    numberOfBytes = data.get('no_of_bytes')

    st_link_cli = '/usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI'
    params = f'-c port=swd -r32 {startAddress} {numberOfBytes}'

    # result = subprocess.run([st_link_cli, '-c port=swd -r32 0x8000000 64'], capture_output=True, text=True)
    result = subprocess.run([st_link_cli, params], capture_output=True, text=True)
    output = result.stdout

    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean_output = ansi_escape.sub('', output)    
    formatted_output = f"<pre>{clean_output}</pre>"

    # return render_template_string(formatted_output)
    return jsonify({"output": clean_output, "error": result.stderr, "returncode": result.returncode})

@app.route('/api/st_link/erase')
def erase_flash():

    st_link_cli = '/usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI'
    params = f'-c port=swd -e all'

    # result = subprocess.run([st_link_cli, '-c port=swd -r32 0x8000000 64'], capture_output=True, text=True)
    result = subprocess.run([st_link_cli, params], capture_output=True, text=True)
    output = result.stdout

    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean_output = ansi_escape.sub('', output)    
    formatted_output = f"<pre>{clean_output}</pre>"

    # return render_template_string(formatted_output)
    return jsonify({"output": clean_output, "error": result.stderr, "returncode": result.returncode})

@app.route('/api/st_link/write')
def write_flash():

    st_link_cli = '/usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI'
    # port = '-c port=swd -w /home/ubuntu/GGB_LED_TEST.bin 0x8000000 -v -q -rst'
    port = '-c port=swd'
    bin_file = '-w /home/ubuntu/GGB_LED_TEST.bin'

    result = subprocess.run([st_link_cli,
                             "-c","port=swd",
                             "-w","/home/ubuntu/ggb_teststand.elf","0x8000000",
                             "-v", "-q", "-rst"
                            ], capture_output=True, text=True)
    # result = subprocess.run(["ls", "/home/ubuntu"], capture_output=True, text=True, check=True)
    output = result.stdout

    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    clean_output = ansi_escape.sub('', output)    
    formatted_output = f"<pre>{clean_output}</pre>"

    return jsonify({"output": clean_output, "error": result.stderr, "returncode": result.returncode})

@app.route('/api/ps/device_list')
def list_ps():
    rm = pyvisa.ResourceManager()
    data = {
        "device" : rm.list_resources()
    }
    return jsonify(data)

@app.route('/api/ps/info')
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

@app.route('/api/ps/ch1/set_voltage', methods=["POST", "GET"])
def set_volt_ch1():
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

        return jsonify({"status": "success", "set_voltage" : setVoltage, "channel" : "1", "voltage" : float(qStr)}), 200
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

@app.route('/api/ps/ch1/set_current', methods=["POST", "GET"])
def set_curr_ch1():
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
        return jsonify({"status": "success", "set_current" : setCurrent, "channel" : "1", "current" : float(qStr)}), 200
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

@app.route('/api/ps/ch1/measured_voltage')
def get_measured_voltage():
    rm = pyvisa.ResourceManager()

    inst=rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")
    inst.write_termination='\n'
    inst.read_termination='\n'
    time.sleep(0.04)
    psMsg = 'MEASure:VOLTage? CH1'
    inst.write(psMsg)
    time.sleep(0.25)
    qStr = inst.read()
    return jsonify({"status": "success", "msg": "measured_voltage", "voltage" : float(qStr)}), 200

@app.route('/api/ps/ch1/measured_current')
def get_measured_current():
    rm = pyvisa.ResourceManager()

    inst=rm.open_resource("USB0::0x0483::0x7540::SPD3ECAC3R0303::INSTR")
    inst.write_termination='\n'
    inst.read_termination='\n'
    time.sleep(0.04)
    psMsg = 'MEASure:CURRent? CH1'
    inst.write(psMsg)
    time.sleep(0.25)
    qStr = inst.read()
    return jsonify({"status": "success", "msg": "measured_current", "current" : float(qStr)}), 200

@app.route('/api/ps/ch1/on', methods=["POST", "GET"])
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

@app.route('/api/ps/ch1/off', methods=["POST", "GET"])
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
