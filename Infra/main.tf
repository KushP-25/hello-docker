provider "aws" {
  region = "ap-southeast-1"
}

# Use existing security group
data "aws_security_group" "web_sg" {
  name = "hello-docker-sg"
}

resource "aws_instance" "hello_ec2" {
  ami                         = "ami-0fa377108253bf620" 
  instance_type               = "t2.micro"
  key_name                    = "test"
  vpc_security_group_ids      = [data.aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
set -e  # Exit on any error

echo "=== Starting user-data script at $(date) ==="

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for service to be ready
wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if systemctl is-active --quiet $service; then
            echo "$service is active"
            return 0
        fi
        echo "Waiting for $service to be active... (attempt $attempt/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "ERROR: $service failed to start after $max_attempts attempts"
    return 1
}

# Update system
echo "Updating system packages..."
apt-get update -y

# Install Docker from Ubuntu repos
echo "Installing Docker..."
DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io

# Start and enable Docker service
echo "Starting Docker service..."
systemctl start docker
systemctl enable docker

# Wait for Docker service to be ready
wait_for_service docker

# Verify Docker installation
echo "Verifying Docker installation..."
if ! command_exists docker; then
    echo "ERROR: Docker command not found after installation"
    exit 1
fi

# Test Docker
echo "Testing Docker..."
docker --version || { echo "ERROR: Docker version check failed"; exit 1; }

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Create app directory
mkdir -p /opt/flask-app
cd /opt/flask-app

# Create the Flask app
echo "Creating Flask application..."
cat > app.py << 'PYEOF'
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return "Hello from Docker on EC2!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
PYEOF

# Create Dockerfile
echo "Creating Dockerfile..."
cat > Dockerfile << 'DOCKEREOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y python3 python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/flask-app

RUN pip3 install Flask

COPY app.py .

EXPOSE 80

CMD ["python3", "app.py"]
DOCKEREOF

# List created files
echo "Files created:"
ls -la /opt/flask-app/

# Build Docker image
echo "Building Docker image..."
if ! docker build -t hello-docker . 2>&1; then
    echo "ERROR: Docker build failed"
    exit 1
fi

echo "Docker build successful!"

# Stop and remove any existing container
echo "Cleaning up existing containers..."
docker stop hello-container 2>/dev/null || true
docker rm hello-container 2>/dev/null || true

# Run the container
echo "Starting container..."
if ! docker run -d -p 80:80 --name hello-container --restart unless-stopped hello-docker; then
    echo "ERROR: Failed to start container"
    exit 1
fi

# Wait for container to start
sleep 10

# Verify container is running
echo "=== Container Status ==="
docker ps -a

# Check container logs
echo "=== Container Logs ==="
docker logs hello-container

# Test if port 80 is listening
echo "=== Port 80 Status ==="
netstat -tlnp | grep :80 || echo "WARNING: Port 80 not listening yet"

# Final verification
CONTAINER_ID=$(docker ps -q -f name=hello-container)
if [ -n "$CONTAINER_ID" ]; then
    echo "✅ SUCCESS: Container is running with ID: $CONTAINER_ID"
    
    # Test the app locally
    echo "Testing app locally..."
    sleep 5
    curl -s http://localhost:80 || echo "WARNING: Local test failed, but container is running"
    
else
    echo "❌ ERROR: Container is not running"
    docker ps -a
    docker logs hello-container
    exit 1
fi

echo "=== Setup completed successfully at $(date) ==="
echo "🚀 Your Flask app should be accessible at http://[EC2-PUBLIC-IP]"
EOF

  tags = {
    Name = "hello-docker-instance"
  }
}
