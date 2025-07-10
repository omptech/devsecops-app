terraform {
  backend "s3" {
    bucket         = "devsecops-demo-tfstate"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "app_sg" {
  name        = "app_sg"
  description = "Allow SSH and HTTP"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_server" {
  ami                    = "ami-07d02ee1eeb0c996c"  # Ubuntu 22.04 LTS (us-east-1)
  instance_type          = "t2.medium"
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  root_block_device {
    volume_size = 12
    volume_type = "gp2"
  }

  tags = {
    Name = "devsecops-demo-app"
  }

  user_data = file("${path.module}/user_data.sh")
}
