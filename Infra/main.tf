provider "aws" {
  region = "ap-southeast-1"
}

# Security group to allow HTTP and SSH traffic
resource "aws_security_group" "web_sg" {
  name        = "hello-docker-sg"
  description = "Allow HTTP and SSH traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hello-docker-sg"
  }
}

resource "aws_instance" "hello_ec2" {
  ami                         = "ami-0fa377108253bf620" 
  instance_type               = "t2.micro"
  key_name                    = "test"
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1

echo "Starting user-data script at $(date)"

# Update system
apt-get update -y

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Wait for Docker to be ready
sleep 10

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Create the Flask app
cat > /home/ubuntu/app.py << 'PYEOF'
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return "Hello from Docker on EC2!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
PYEOF

# Create Dockerfile
cat > /home/ubuntu/Dockerfile << 'DOCKEREOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y python3 python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip3 install Flask

COPY app.py .

EXPOSE 80

CMD ["python3", "app.py"]
DOCKEREOF

# Build and run the Docker container
cd /home/ubuntu

echo "Building Docker image..."
docker build -t hello-docker .

if [ $? -eq 0 ]; then
    echo "Docker build successful, starting container..."
    
    # Stop and remove any existing container
    docker stop hello-container 2>/dev/null || true
    docker rm hello-container 2>/dev/null || true
    
    # Run the container
    docker run -d -p 80:80 --name hello-container --restart unless-stopped hello-docker
    
    # Wait and verify
    sleep 5
    docker ps
    
    echo "Setup completed successfully at $(date)"
else
    echo "Docker build failed!"
fi
EOF

  tags = {
    Name = "hello-docker-instance"
  }
}
