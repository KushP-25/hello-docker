provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_instance" "hello_ec2" {
  ami           = "ami-0fa377108253bf620" 
  instance_type = "t2.micro"
  key_name      = "test"

  user_data = <<-EOF
#!/bin/bash
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

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Install AWS CLI for ECR login
apt-get install -y awscli

# Login to ECR and run container
docker login -u AWS -p $(aws ecr get-login-password --region ap-southeast-1) 950224715748.dkr.ecr.ap-southeast-1.amazonaws.com
docker pull 950224715748.dkr.ecr.ap-southeast-1.amazonaws.com/hello-docker
docker run -d -p 80:80 --name hello-container 950224715748.dkr.ecr.ap-southeast-1.amazonaws.com/hello-docker
EOF

  tags = {
    Name = "hello-docker-instance"
  }
}
