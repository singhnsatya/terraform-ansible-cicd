# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
	access_key = var.aws_access_key
  secret_key = var.aws_access_secret
}

# create default vpc if one does not exit
resource "aws_default_vpc" "default_vpc" {

  tags    = {
    Name  = "default vpc"
  }
}


# use data source to get all avalablility zones in region
data "aws_availability_zones" "available_zones" {}


# create default subnet if one does not exit
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available_zones.names[0]

  tags   = {
    Name = "default subnet"
  }
}


resource "aws_security_group" "jenkins-secgroup" {
  name        = "jenkins-secgroup"
  description = "Allow ssh and HTTP traffic"
  vpc_id      = aws_default_vpc.default_vpc.id

	ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

	ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}

# use data source to get a registered amazon linux 2 ami
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_instance" "jenkins_ec2" {
  ami 										= data.aws_ami.amazon_linux_2.id
  instance_type						= "t2.micro"
	subnet_id								= aws_default_subnet.default_az1.id
	vpc_security_group_ids	= [aws_security_group.jenkins-secgroup.id]
	key_name								= "ec2-pem"

  tags = {
    Name = "Jenkins Server"
  }

	user_data = <<-EOF
	#!bin/bash
	sudo yum update –y
	sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
	sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
	sudo yum upgrade
	sudo amazon-linux-extras install java-openjdk11 -y
	sudo dnf install java-11-amazon-corretto -y
	sudo yum install jenkins -y
	sudo systemctl enable jenkins
	sudo systemctl start jenkins
	sudo cat /var/lib/jenkins/secrets/initialAdminPassword
	EOF
}

# resource "null_resource" "name" {

# 	# ssh into the ec2 instance 
# }

# an empty resource block
# resource "null_resource" "name" {

#   # ssh into the ec2 instance 
#   connection {
#     type        = "ssh"
#     user        = "ec2-user"
#     private_key = file("./ec2-pem.pem")
#     host        = aws_instance.jenkins_ec2.public_ip
#   }

#   # copy the install_jenkins.sh file from your computer to the ec2 instance 
#   provisioner "file" {
#     source      = "install_jenkins.sh"
#     destination = "/tmp/install_jenkins.sh"
#   }

#   # set permissions and run the install_jenkins.sh file
#   provisioner "remote-exec" {
#     inline = [
# 			"sudo chmod+x /tmp/install_jenkins.sh",
# 			"sh /tmp/install_jenkins.sh"
#     ]
#   }

#   # wait for ec2 to be created
#   depends_on = [aws_instance.jenkins_ec2]
# }

resource "aws_s3_bucket" "singhnsatya-jenkins-s3-bucket" {
  bucket = "singhnsatya-jenkins-s3-bucket"

  tags = {
    Name        = "Jenkins artifact s3"
  }
}

output "website_url" {
  value     = join ("", ["http://", aws_instance.jenkins_ec2.public_dns, ":", "8080"])
}