provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "dev-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  
  tags = {
      Name = "dev-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
    vpc_id = aws_vpc.dev-vpc.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone = "us-east-1a"

    tags = {
        Name = "dev-public-subnet"
    }
}

resource "aws_subnet" "private_subnet" {
    vpc_id = aws_vpc.dev-vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "dev-private-subnet"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.dev-vpc.id
    
    tags = {
        Name = "internet-gateway"
    }
}

resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.dev-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }

    tags = {
        Name = "public-route-table"
    }
}

resource "aws_route_table_association" "public_route_association" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "nat_eip" {
    vpc = true
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_subnet.id

  tags = {
      Name = "nat-gateway"
  }
}

resource "aws_route_table" "private_route_table" {
    vpc_id = aws_vpc.dev-vpc.id
    
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat_gateway.id
    }

    tags = {
        Name = "private-route-table"
    }
}

resource "aws_route_table_association" "private_route_association" {
    subnet_id = aws_subnet.private_subnet.id
    route_table_id = aws_route_table.private_route_table.id
}

resource "aws_security_group" "public_sg" {
    vpc_id = aws_vpc.dev-vpc

    ingress {
        form_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] 
    }

    ingress {
        form_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] 
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "public-sg"
    }
}

resource "aws_security_group" "privatec_sg" {
    vpc_id = aws_vpc.dev-vpc

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "private-sg"
    }
}

resource "aws_iam_role" "ec2_ssm_role" {
    name = "ec2_ssm_role"
    assume_role_policy = jsondecode({
        Version = "2012-10-17"
        Statement = [{
            Effect = "Allow"
            Principal = {
                Service = "ec2.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        }]
    })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
    role = aws_iam_role.ec2_ssm_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_role_profile" {
    role = aws_iam_role.ec2_ssm_role.name
}

resource "aws_instance" "ec2_public" {
    ami = "ami-0866a3c8686eaeeba"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.public_subnet.id
    security_groups = [aws_security_group.public_sg.name]
    iam_instance_profile = aws_iam_instance_profile.ec2_ssm_role_profile.name

    tags = {
        Name = "ec2-public"
    }
}

resource "aws_instance" "ec2_private" {
    ami = "ami-0866a3c8686eaeeba"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.private_subnet.id
    security_groups = [aws_security_group.private_sg.name]
    iam_instance_profile = aws_iam_instance_profile.ec2_ssm_role_profile.name

    tags = {
        Name = "ec2-private"
    }
}