# AWS Provider
provider "aws" {
  region = "${var.vpc_region}"
}

# VPC name
variable "vpc_name" {
  type = "string"
}

# key_path
variable "my_public_key" {
  type = "string"
}

# Profile
variable "profile" {
  type = "string"
}

# VPC region
variable "vpc_region" {
  type = "string"
}

# Database name
variable "db_name" {
  type = "string"
}

# VPC_cidr
variable "vpc_cidr" {
  type = "string"
}

# Public Subnet_cidrs
variable "public_cidrs" {
  type = "list"
}

# # Private Subnet_cidrs
# variable "private_cidrs" {
#   type = "list"
# }

# AMI
variable "ami" {
  type = "string"
}

#  Avilable Availibility Zone
data "aws_availability_zones" "available" {

}


# VPC Creation
resource "aws_vpc" "vpc" {
  cidr_block                     = "${var.vpc_cidr}"
  enable_dns_hostnames           = true
  enable_dns_support             = true
  enable_classiclink_dns_support = true
  tags = {
    Name = "${var.vpc_name}"
  }
}

# Public Subnet
resource "aws_subnet" "public_subnet" {
  count                   = length(data.aws_availability_zones.available.names) > 2 ? 3 : 2
  cidr_block              = "${var.public_cidrs[count.index]}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"

  tags = {
    Name = "public-subnet.${count.index + 1}"
  }
}

# # Private Subnet
# resource "aws_subnet" "private_subnet" {
#   count             = 2
#   cidr_block        = "${var.private_cidrs[count.index]}"
#   vpc_id            = "${aws_vpc.vpc.id}"
#   availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

#   tags = {
#     Name = "private-subnet.${count.index + 1}"
#   }
# }

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags = {
    Name = "gateway"
  }
}

# Public Route Table
resource "aws_route_table" "public_route" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = {
    Name = "public-route-table"
  }
}

# # Private Route Table
# resource "aws_default_route_table" "private_route" {
#   default_route_table_id = "${aws_vpc.vpc.default_route_table_id}"

#   tags = {
#     Name = "private-route-table"
#   }
# }

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_subnet_assoc" {
  count          = length(data.aws_availability_zones.available.names) > 2 ? 3 : 2
  route_table_id = "${aws_route_table.public_route.id}"
  subnet_id      = "${aws_subnet.public_subnet.*.id[count.index]}"
}

# # Associate Private Subnet with Private Route Table
# resource "aws_route_table_association" "private_subnet_assoc" {
#   count          = 2
#   route_table_id = "${aws_default_route_table.private_route.id}"
#   subnet_id      = "${aws_subnet.private_subnet.*.id[count.index]}"
#  }

# Application Security Group
resource "aws_security_group" "application_security_group" {
  name        = "application_security_group"
  description = "Allow inbound traffic for application"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "80 from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "8080 from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "application_security_group"
  }

}

# RDS instance
resource "aws_db_instance" "csye6225-su2020" {
  identifier             = "csye6225-su2020"
  instance_class         = "db.t2.micro"
  engine                 = "mysql"
  multi_az               = "false"
  storage_type           = "gp2"
  allocated_storage      = 20
  name                   = "${var.db_name}"
  username               = "root"
  password               = "password"
  # apply_immediately      = "true"
  skip_final_snapshot    = "true"
  db_subnet_group_name   = "${aws_db_subnet_group.rds-db-subnet.name}"
  vpc_security_group_ids = ["${aws_security_group.database_security_group.id}"]
}


# Database security group
resource "aws_security_group" "database_security_group" {
  name        = "database_security_group"
  description = "Allow inbound traffic for database"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    description = "3306 from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    # cidr_blocks = ["0.0.0.0/0"]
    security_groups = ["${aws_security_group.application_security_group.id}"]
  }

  tags = {
    Name = "database_security_group"
  }

}

# RDS subnet
resource "aws_db_subnet_group" "rds-db-subnet" {
  name       = "rds-db-subnet"
  subnet_ids = ["${aws_subnet.public_subnet[1].id}", "${aws_subnet.public_subnet[2].id}"]
}
# Bucket encryption
resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

# S3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket        = "webapp.naresh.agrawal"
  acl           = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.mykey.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }

  lifecycle_rule {
    enabled = true

    transition {
      storage_class = "STANDARD_IA"
      days          = 30
    }
  }

  tags = {
    Name = "bucket"
  }
}
# Key pair
resource "aws_key_pair" "ssh_key" {
  key_name   = "aws"
  public_key = "${var.my_public_key}"
}

# EC2 instance
resource "aws_instance" "web" {
  depends_on = [ aws_db_instance.csye6225-su2020 ]
  ami                    = "${var.ami}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.ssh_key.id}"
  vpc_security_group_ids = ["${aws_security_group.application_security_group.id}"]
  subnet_id              = "${aws_subnet.public_subnet[0].id}"
  iam_instance_profile   = "${aws_iam_instance_profile.EC2-CSYE6225-instance-profile.name}"

  root_block_device {
    volume_type = "gp2"
    volume_size = "20"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo echo export "Bucketname=${aws_s3_bucket.bucket.bucket}" >> /etc/environment
              sudo echo export "Bucketendpoint=${aws_s3_bucket.bucket.bucket_regional_domain_name}" >> /etc/environment
              sudo echo export "DBhost=${aws_db_instance.csye6225-su2020.address}" >> /etc/environment
              sudo echo export "DBendpoint=${aws_db_instance.csye6225-su2020.endpoint}" >> /etc/environment
              sudo echo export "DBname=${var.db_name}" >> /etc/environment
              sudo echo export "DBusername=${aws_db_instance.csye6225-su2020.username}" >> /etc/environment
              sudo echo export "DBpassword=${aws_db_instance.csye6225-su2020.password}" >> /etc/environment
              sudo echo export "Profile=${var.profile}" >> /etc/environment
              sudo echo export "Region=${var.vpc_region}" >> /etc/environment
              EOF

  tags = {
    Name = "Webapp_EC2"
  }
}

# IAM Pocily
resource "aws_iam_policy" "WebAppS3" {
  name = "WebAppS3"
  
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::webapp.naresh.agrawal",
        "arn:aws:s3:::webapp.naresh.agrawal/*"
        ]
    }
  ]
}
EOF
}

# IAM Role
resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"

  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
{
"Action": "sts:AssumeRole",
"Principal": {
 "Service": "ec2.amazonaws.com",
 "Service": "s3.amazonaws.com"
},
"Effect": "Allow"
}
]
}
EOF

  tags = {
    tag-key = "EC2-CSYE6225"
  }
}

# IAM Policy attachment
resource "aws_iam_policy_attachment" "WebAppS3-attach" {
  name       = "WebAppS3-attachment"
  roles      = ["${aws_iam_role.EC2-CSYE6225.name}"]
  policy_arn = "${aws_iam_policy.WebAppS3.arn}"
}

# IAM Profile Instance
resource "aws_iam_instance_profile" "EC2-CSYE6225-instance-profile" {
  name = "EC2-CSYE6225-instance-profile"
  role = "${aws_iam_role.EC2-CSYE6225.name}"
}

# Dynamodb Table
resource "aws_dynamodb_table" "dynamodb-table" {
  name     = "csye6225"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

