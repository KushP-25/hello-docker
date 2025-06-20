provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_instance" "hello_ec2" {
  ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2
  instance_type = "t2.micro"
  key_name      = "test"

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              docker login -u AWS -p $(aws ecr get-login-password --region ap-southeast-1) 950224715748.dkr.ecr.ap-southeast-1.amazonaws.com
              docker pull 950224715748.dkr.ecr.ap-southeast-1.amazonaws.com/hello-docker
              docker run -d --name hello-container 950224715748.dkr.ecr.ap-southeast-1.amazonaws.com/hello-docker
              EOF

  tags = {
    Name = "hello-docker-instance"
  }
}
