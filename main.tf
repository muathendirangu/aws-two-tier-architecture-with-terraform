# configure aws provider
terraform {
  required_providers {
    aws = {
        source  = "hashicorp/aws"
    }
  }
}


# create a vpc
resource "aws_vpc" "terraform-backend-tier-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "terraform-backend-tier-vpc"
        Environment = "dev"
        Team = "backend-team"
        Owner = "admin@companydomain.com"
    }
}

# public subnets in the vpc for the web server tier
resource "aws_subnet" "terraform-web-server-tier-public-subnet-1" {
    vpc_id = aws_vpc.terraform-backend-tier-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true # set to true to enable this subnet to be publicly accessible
    tags = {
        Name = "terraform-web-server-tier-public-subnet-1"

    }
}

resource "aws_subnet" "terraform-web-server-tier-public-subnet-2" {
    vpc_id = aws_vpc.terraform-backend-tier-vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true # set to true to enable this subnet to be publicly accessible
    tags = {
        Name = "terraform-web-server-tier-public-subnet-2"
    }
}

# private subnets in the vpc for the database tier
resource "aws_subnet" "terraform-database-tier-private-subnet-1" {
    vpc_id = aws_vpc.terraform-backend-tier-vpc.id
    cidr_block = "10.0.101.0/24"
    availability_zone = "us-east-1a"
    tags = {
        Name = "terraform-database-tier-private-subnet-1"
    }
}
resource "aws_subnet" "terraform-database-tier-private-subnet-2" {
    vpc_id = aws_vpc.terraform-backend-tier-vpc.id
    cidr_block = "10.0.102.0/24"
    availability_zone = "us-east-1b"
    tags = {
        Name = "terraform-database-tier-private-subnet-2"
    }

}

# create an internet gateway for the vpc
resource "aws_internet_gateway" "terraform-backend-tier-vpc-igw" {
    vpc_id = aws_vpc.terraform-backend-tier-vpc.id
    tags = {
        Name = "terraform-backend-tier-vpc-igw"
    }
}
