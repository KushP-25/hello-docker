FROM ubuntu:22.04

# Set environment variables to prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Update system and install Python and pip
RUN apt-get update && \
    apt-get install -y python3 python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Flask
RUN pip3 install Flask

# Copy the application
COPY app.py .

# Expose port 80
EXPOSE 80

# Run the application
CMD ["python3", "app.py"]
