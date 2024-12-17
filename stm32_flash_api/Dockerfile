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

# Copy the application files to the container
COPY . .

# Install Flask using pip
RUN pip3 install flask

# Expose the port that Flask app will run on
EXPOSE 5000

# Run the Flask app
CMD ["python3", "app.py"]
