import subprocess
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def hello_world():
    result = subprocess.run(['/usr/local/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI', '-c port=swd -r32 0x8000000 64'], capture_output=True, text=True)
    return jsonify({"output": result.stdout}) 

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)