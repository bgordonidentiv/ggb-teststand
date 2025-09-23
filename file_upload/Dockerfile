FROM python:3.10-slim

WORKDIR /app

# Install Flask
RUN pip install Flask

# Copy app code
COPY app.py /app/app.py

# Expose port 5005
EXPOSE 5005

# Run the application
CMD ["python", "app.py"]

