provider "aws" {
    region = var.aws_region
}
data "aws_availability_zones" "available" {
    state = "available"
}
resource "aws_vpc" "stdb_vpc" {
    cidr_block = var.vpc_cidr_block
    enable_dns_hostnames = true
    tags = {
      Name = "stdb_vpc"
    }
}
resource "aws_internet_gateway" "stdb_igw" {
    vpc_id = aws_vpc.stdb_vpc.id
    tags = {
        Name = "stdb_igw"
    }
}
resource "aws_subnet" "stdb_public_subnet" {
    count = var.subnet_count.public
    vpc_id = aws_vpc.stdb_vpc.id
    cidr_block = var.public_subnet_cidr_blocks[count.index]
    availability_zone = data.aws_availability_zones.available.names[count.index]
    tags = {
        Name = "stdb_public_subnet"
    }
}
resource "aws_subnet" "stdb_private_subnet" {
    count = var.subnet_count.private
    vpc_id = aws_vpc.stdb_vpc.id
    cidr_block = var.private_subnet_cidr_blocks[count.index]
    availability_zone = data.aws_availability_zones.available.names[count.index]
    tags = {
        Name = "std_private_subnet"
    }
}
resource "aws_route_table" "stdb_public_rt" {
    vpc_id = aws_vpc.stdb_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.stdb_igw.id
    }
}
resource "aws_route_table_association" "public" {
    count = var.subnet_count.public
    route_table_id = aws_route_table.stdb_public_rt.id
    subnet_id = aws_subnet.stdb_public_subnet[count.index].id
}
resource "aws_route_table" "stdb_private_rt" {
    vpc_id = aws_vpc.stdb_vpc.id
}
resource "aws_route_table_association" "private" {
    count = var.subnet_count.private
    route_table_id = aws_route_table.stdb_private_rt.id
    subnet_id = aws_subnet.stdb_private_subnet[count.index].id
}
resource "aws_security_group" "stdb_sg" {
    name = "stdb_sg"
    description = "Security group for database"
    vpc_id = aws_vpc.stdb_vpc.id
    ingress {
        description = "Allow MySQL traffic from only the ec2 instance"
        from_port = "3306"
        to_port = "3306"
        protocol = "tcp"
        cidr_blocks = [format("%s/%s", aws_instance.std_ec2[0].public_ip, "32")]
    }
    tags = {
        Name = "stdb_sg"
    }
}
resource "aws_security_group" "std_ec2_sg" {
    name = "std_ec2_sg"
    description = "EC2_security group"
    vpc_id = aws_vpc.stdb_vpc.id
    ingress {
        description = "Allow all traffic through HTTP"
        from_port = "80"
        to_port = "80"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "allow SSH from anywhere"
        from_port = "22"
        to_port = "22"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        description = "Allow all outbound traffic"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "std_ec2_sg"
    }
}
resource "aws_security_group" "rds_default_sg" {
    name = "rds_default_egress"
    description = "Default security group for RDS instances"
    vpc_id = aws_vpc.stdb_vpc.id
    ingress {
        description = "Allow all traffic from the VPC"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [aws_vpc.stdb_vpc.cidr_block]
    }
    egress {
        description = "Allow all outbound traffic"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "rds_default_sg"
    }
}
resource "aws_db_subnet_group" "stdb_subnet_group" {
    name = "stdb_subnet_group"
    description = "DB subnet group"
    subnet_ids = [for subnet in aws_subnet.stdb_private_subnet : subnet.id]
}
resource "aws_db_instance" "studentdb" {
    allocated_storage = var.settings.database.allocated_storage
    engine = var.settings.database.engine
    engine_version = var.settings.database.engine_version
    instance_class = var.settings.database.instance_class
    db_name = var.settings.database.db_name
    identifier = var.settings.database.db_name
    username = var.db_username
    password = var.db_password
    db_subnet_group_name = aws_db_subnet_group.stdb_subnet_group.id
    vpc_security_group_ids = [aws_security_group.rds_default_sg.id, aws_security_group.stdb_sg.id]
    skip_final_snapshot = var.settings.database.skip_final_snapshot
}
resource "aws_instance" "std_ec2" {
    count = var.settings.std_ec2.count
    ami = "ami-049a62eb90480f276"
    instance_type = var.settings.std_ec2.instance_type
    subnet_id = aws_subnet.stdb_public_subnet[count.index].id
    key_name = "ubuntu_mumbai_keypair"
    vpc_security_group_ids = [aws_security_group.std_ec2_sg.id]
    tags = {
        Name = "std_ec2"
    }
}
resource "aws_eip" "std_ec2_eip" {
    count = var.settings.std_ec2.count
    instance = aws_instance.std_ec2[count.index].id
    domain = "vpc"
    tags = {
        Name = "std_ec2_eip"
    }
}