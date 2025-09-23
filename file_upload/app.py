from flask import Flask, request, render_template_string
import os

app = Flask(__name__)

UPLOAD_FOLDER = '/shared_data'

@app.route('/', methods=['GET', 'POST'])
def upload_file():
    if request.method == 'POST':
        if 'file' not in request.files:
            return "No file part", 400
        file = request.files['file']
        if file.filename == '':
            return "No selected file", 400
        filepath = os.path.join(UPLOAD_FOLDER, file.filename)
        file.save(filepath)
        return f"File {file.filename} uploaded successfully to {UPLOAD_FOLDER}!"
    return render_template_string("""
        <!doctype html>
        <title>Upload File</title>
        <h1>Upload a file</h1>
        <form method=post enctype=multipart/form-data>
          <input type=file name=file>
          <input type=submit value=Upload>
        </form>
    """)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5005)
