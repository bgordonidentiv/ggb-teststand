# Start with the Ubuntu image with the stm32CubeProgrammer CLI already installed
FROM stm32_flash_cli:1.1  

# Set environment variables to avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update the package manager and install Python3 and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && apt-get clean

# Set the working directory in the container
WORKDIR /app

# Install Flask using pip
RUN pip3 install flask

# Install pyvisa to talk to the Siglent Power Supply
RUN pip3 install pyvisa-py
RUN pip3 install PyUSB

# Copy the application files to the container
COPY . .

# Expose the port that Flask app will run on
EXPOSE 5000

# Run the Flask app
CMD ["python3", "app.py"]
