provider "aws" {
  region = "eu-west-3"
}

resource "aws_security_group" "rbk_sg" {
  name        = "rbk_labs_sg"
  description = "Allow HTTP, HTTPS, SSH and Custom Ports"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "rbk_server" {
  ami           = "ami-05b5a865c3579bbc4" # Ubuntu 20.04 LTS (Paris) - Example
  instance_type = "t3.medium"
  key_name      = "your-ssh-key"

  vpc_security_group_ids = [aws_security_group.rbk_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y docker.io docker-compose git
              systemctl start docker
              systemctl enable docker
              EOF

  tags = {
    Name = "RBK-Labs-Production"
  }
}

output "public_ip" {
  value = aws_instance.rbk_server.public_ip
}
