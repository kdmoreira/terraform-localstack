# a provider must be specified, e.g. aws
# 'terraform init' installs the providers' modules
provider "aws" {
    region = "us-east-1"

    access_key = var.aws_credentials.access_key
    secret_key = var.aws_credentials.access_key
}

# mocked aws credentials to use with localstack
# in prod, do not hardcode credentials in the config file
variable "aws_credentials" {
    description = "access and secret keys"
    type = object({access_key = string,
                   secret_key = string})
    default = {access_key = "mock_access_key",
               secret_key = "mock_secret_key"}
}

resource "aws_s3_bucket" "my-bucket" {
    bucket = "my-bucket"

    tags = {
        Name = "my-bucket"
        Environment = "dev"
    }
}

variable "vpc_prefix" {
    description = "cidr block for the vpc"
    type = string
    default = "10.0.0.0/16"
}

resource "aws_vpc" "prod-vpc" {
    cidr_block = var.vpc_prefix
    tags = {
        Name = "vpc"
    }
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_route_table" "prod-route-table" {
    vpc_id = aws_vpc.prod-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = {
        Name = "route-table"
    }
}

# if default is not specified, it will prompt during 'apply' or 'destroy'
# passing it directly via CLI is also supported:
# 'terraform apply -var "subnet_prefix=10.0.1.0/24"' also works
variable "subnet_prefix" {
    description = "cidr block for the subnet"
    default = [{cidr_block = "10.0.1.0/24", name = "prod_subnet"},
               {cidr_block = "10.0.2.0/24", name = "dev_subnet"}]
}

# terraform.tfvars can also be used as well as <filename>.tfvars
# but in the latter case terraform should be instructed to look 
# for vars in the specific file: 
# 'terraform apply -var-file <filename>.tfvars'
# if there's no var overriding it, 'default' will be used
variable "private_ip" {
    description = "private ip for ENI"
    default = "10.0.1.40"
    type = string
}


resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = var.subnet_prefix[0].cidr_block
    availability_zone = "us-east-1a"

    tags = {
        Name = var.subnet_prefix[0].name
    }
}

resource "aws_subnet" "subnet-2" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = var.subnet_prefix[1].cidr_block
    availability_zone = "us-east-1a"

    tags = {
        Name = var.subnet_prefix[1].name
    }
}

resource "aws_route_table_association" "rt_association" {
    subnet_id = aws_subnet.subnet-1.id
    route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffict"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = [var.private_ip]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
  network_interface = aws_network_interface.web-server-nic.id
  associate_with_private_ip = var.private_ip
  depends_on = [aws_internet_gateway.gw]
}

output "server_public_ip" {
    value = aws_eip.one.public_ip
}

resource "aws_instance" "web-server-instance" {
    ami = "ami-00001"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "main-key"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.web-server-nic.id
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF

    tags = {
        Name = "web-server"
    } 
}

output "server_private_ip" {
    value = aws_instance.web-server-instance.private_ip
}

output "server_id" {
    value = aws_instance.web-server-instance.id
}