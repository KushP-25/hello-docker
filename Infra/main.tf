provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_instance" "hello_ec2" {
  ami           = "ami-0fa377108253bf620" 
  instance_type = "t2.micro"
  key_name      = "test"

  user_data = <<-EOF
  #!/bin/bash
  apt update -y
  apt install -y docker.io
  systemctl start docker
  systemctl enable docker

  docker login -u AWS -p $(aws ecr get-login-password --region ap-southeast-1) 950224715748.dkr.ecr.ap-southeast-1.amazonaws.com
  docker pull 950224715748.dkr.ecr.ap-southeast-1.amazonaws.com/hello-docker
  docker run -d -p 80:80 --name hello-container 950224715748.dkr.ecr.ap-southeast-1.amazonaws.com/hello-docker
EOF


  tags = {
    Name = "hello-docker-instance"
  }
}
