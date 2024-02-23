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

# create a route table for the public subnets
resource "aws_route_table" "terraform-backend-tier-vpc-public-route-table" {
    vpc_id = aws_vpc.terraform-backend-tier-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.terraform-backend-tier-vpc-igw.id
    }
    tags = {
        Name = "terraform-backend-tier-vpc-public-route-table"
    }
}

# associate the public route table with the public subnets
resource "aws_route_table_association" "terraform-backend-tier-vpc-public-route-table-association-1" {
    subnet_id = aws_subnet.terraform-web-server-tier-public-subnet-1.id
    route_table_id = aws_route_table.terraform-backend-tier-vpc-public-route-table.id
}

resource "aws_route_table_association" "terraform-backend-tier-vpc-public-route-table-association-2" {
    subnet_id = aws_subnet.terraform-web-server-tier-public-subnet-2.id
    route_table_id = aws_route_table.terraform-backend-tier-vpc-public-route-table.id
}

# create elastic ip
resource "aws_eip" "lb" {
    domain = "vpc"
}

# create NAT gateway
resource "aws_nat_gateway" "terraform-backend-tier-vpc-nat-gateway" {
    allocation_id = aws_eip.lb.id
    subnet_id = aws_subnet.terraform-web-server-tier-public-subnet-1.id
    depends_on = [ aws_internet_gateway.terraform-backend-tier-vpc-igw ]
    tags = {
        Name = "terraform-backend-tier-vpc-nat-gateway"
    }
}

# create a route table for the private subnets
resource "aws_route_table" "terraform-backend-tier-vpc-private-route-table" {
    vpc_id = aws_vpc.terraform-backend-tier-vpc.id
    route = {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.terraform-backend-tier-vpc-nat-gateway.id
    }
    tags = {
        Name = "terraform-backend-tier-vpc-private-route-table"
    }
}

# associate the private route table with the private subnets
resource "aws_route_table_association" "terraform-backend-tier-vpc-private-route-table-association-1" {
    subnet_id = aws_subnet.terraform-database-tier-private-subnet-1.id
    route_table_id = aws_route_table.terraform-backend-tier-vpc-private-route-table.id
    depends_on = [ aws_route_table.terraform-backend-tier-vpc-private-route-table ]
}

resource "aws_route_table_association" "terraform-backend-tier-vpc-private-route-table-association-2" {
    subnet_id = aws_subnet.terraform-database-tier-private-subnet-2.id
    route_table_id = aws_route_table.terraform-backend-tier-vpc-private-route-table.id
    depends_on = [ aws_route_table.terraform-backend-tier-vpc-private-route-table ]
}


# create a security group for the web server tier
resource "aws_security_group" "terraform-web-server-tier-security-group" {
    name = "terraform-web-server-tier-security-group"
    vpc_id = aws_vpc.terraform-backend-tier-vpc.id
    description = "Security group for the web server tier"

    # allow http traffic from the web server tier
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # allow https traffic from the web server tier
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # allow ssh traffic from the web server tier
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # allow outbound traffic from the web server tier
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# create a security group for the database tier
resource "aws_security_group" "terraform-database-tier-security-group" {
    name = "terraform-database-tier-security-group"
    vpc_id = aws_vpc.terraform-backend-tier-vpc.id
    description = "Security group for the database tier"

    # allow mysql traffic from the database tier
    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = [ aws_security_group.terraform-web-server-tier-security-group.id ]
    }

    # allow ssh traffic from the database tier
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    # allow outbound traffic from the database tier
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# create a launch template for the web server tier
resource "aws_launch_template" "terraform-web-server-tier-launch-template" {
    name = "terraform-web-server-tier-launch-template"
    image_id = "ami-00000000000000000"
    instance_type = "t2.micro"
    vpc_security_group_ids = [ aws_security_group.terraform-web-server-tier-security-group.id ]
    # key_name = var.key_name
    user_data = base64decode(<<EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    EOF
    )
}

# create autoscaling group for the web server tier
resource "aws_autoscaling_group" "terraform-web-server-tier-asg" {
    name = "terraform-web-server-tier-asg"
    min_size = 2
    max_size = 4
    desired_capacity = 2
    availability_zones = [ "us-east-1a", "us-east-1b" ]
    launch_template {
        id = aws_launch_template.terraform-web-server-tier-launch-template.id
        version = "$Latest"
    }
}

# create a subnet group for the database tier
resource "aws_db_subnet_group" "terraform-database-tier-db-subnet-group" {
    name = "terraform-database-tier-db-subnet-group"
    subnet_ids = [ aws_subnet.terraform-database-tier-private-subnet-1.id, aws_subnet.terraform-database-tier-private-subnet-2.id ]
    tags = {
        Name = "terraform-database-tier-db-subnet-group"
    }
}
# create an RDS instance for the database tier
resource "aws_db_instance" "terraform-database-tier-rds-instance" {
    allocated_storage = 20
    engine = "mysql"
    engine_version = "5.7"
    instance_class = "db.t2.micro"
    db_name = "terraform-database-tier-rds-instance"
    username = "admin"
    password = "<PASSWORD>"
    skip_final_snapshot = true
    parameter_group_name = "default.mysql5.7"
    db_subnet_group_name = aws_db_subnet_group.terraform-database-tier-db-subnet-group.name
    depends_on = [ aws_db_subnet_group.terraform-database-tier-db-subnet-group ]
}
