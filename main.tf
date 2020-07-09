# AWS Provider
provider "aws" {
  region = "${var.vpc_region}"
}

# -----------------Variables-----------------------------------------------------------------------------------------

# VPC name
variable "vpc_name" {
  type = "string"
}

# key_path
variable "my_public_key" {
  type = "string"
}

# deploy_bucket_name
variable "deploy_bucket_name" {
  type = "string"
}

# image_bucket_name
variable "image_bucket_name" {
  type = "string"
}

# aws_account_ID
variable "aws_account_ID" {
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

# Circle CI user
variable "circleci_user" {
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

#-----------------Network--------------------------------------------------------------------------------------------------

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

# -------------------RDS----------------------------------------------------------------------------------------

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

#------------------ Bucket----------------------------------------------------------------------------------------

# S3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket        = "${var.image_bucket_name}"
  acl           = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "AES256"
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
# ----------------------------- EC2-------------------------------------------------------------------------------------

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
  iam_instance_profile   = "${aws_iam_instance_profile.CodeDeployEC2ServiceRole-instance-profile.name}"

  ebs_block_device {
    device_name = "/dev/sda1"
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
              EOF

  tags = {
    Name = "Webapp_EC2"
   }
}
# --------------------- IAM Policy-------------------------------------------------------------------------------------

# IAM S3 image Pocily
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
        "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}",
        "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*"
        ]
    }
  ]
}
EOF
}

# IAM CircleCI-Upload-To-S3 Pocily
resource "aws_iam_policy" "CircleCI-Upload-To-S3" {
  name = "CircleCI-Upload-To-S3"
  
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject",
        "s3:Get*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${var.deploy_bucket_name}",
        "arn:aws:s3:::${var.deploy_bucket_name}/*"
        ]
    }
  ]
}
EOF
}

# IAM CircleCI-Code-Deploy Pocily
resource "aws_iam_policy" "CircleCI-Code-Deploy" {
  name = "CircleCI-Code-Deploy"
  
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.vpc_region}:${var.aws_account_ID}:application:csye6225-webapp"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.vpc_region}:${var.aws_account_ID}:deploymentconfig:CodeDeployDefault.OneAtATime",
        "arn:aws:codedeploy:${var.vpc_region}:${var.aws_account_ID}:deploymentconfig:CodeDeployDefault.HalfAtATime",
        "arn:aws:codedeploy:${var.vpc_region}:${var.aws_account_ID}:deploymentconfig:CodeDeployDefault.AllAtOnce"
      ]
    }
  ]
}
EOF
}

# IAM circleci-ec2-ami Pocily
resource "aws_iam_policy" "circleci-ec2-ami" {
  name = "circleci-ec2-ami"
  
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# IAM CodeDeploy-EC2-S3 Pocily
resource "aws_iam_policy" "CodeDeploy-EC2-S3" {
  name = "CodeDeploy-EC2-S3"
  
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:Get*",
        "s3:List*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${var.deploy_bucket_name}",
        "arn:aws:s3:::${var.deploy_bucket_name}/*"
        ]
    }
  ]
}
EOF
}

# -------------------------------------------------------IAM Role--------------------------------------------------------------------------------------------------

# # IAM S3 image Role
# resource "aws_iam_role" "EC2-CSYE6225" {
#   name = "EC2-CSYE6225"

#   assume_role_policy = <<EOF
# {
# "Version": "2012-10-17",
# "Statement": [
# {
# "Action": "sts:AssumeRole",
# "Principal": {
#  "Service": "ec2.amazonaws.com",
#  "Service": "s3.amazonaws.com"
# },
# "Effect": "Allow"
# }
# ]
# }
# EOF

#   tags = {
#     tag-key = "EC2-CSYE6225"
#   }
# }

# IAM CodeDeployEC2ServiceRole Role
resource "aws_iam_role" "CodeDeployEC2ServiceRole" {
  name = "CodeDeployEC2ServiceRole"

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
    tag-key = "CodeDeployEC2ServiceRole"
  }
}

# IAM CodeDeployServiceRole Role
resource "aws_iam_role" "CodeDeployServiceRole" {
  name = "CodeDeployServiceRole"

  assume_role_policy = <<EOF
{
"Version": "2012-10-17",
"Statement": [
{
"Action": "sts:AssumeRole",
"Principal": {
 "Service": "codedeploy.amazonaws.com"
},
"Effect": "Allow"
}
]
}
EOF

  tags = {
    tag-key = "CodeDeployServiceRole"
  }
}

#----------------------------------------------------------Policy Attachment-----------------------------------------------------------------------------

# # IAM EC2-CSYE6225 Policy attachment
# resource "aws_iam_policy_attachment" "WebAppS3-attach" {
#   name       = "WebAppS3-attachment"
#   roles      = ["${aws_iam_role.EC2-CSYE6225.name}"]
#   policy_arn = "${aws_iam_policy.WebAppS3.arn}"
# }

# IAM cicd user Policy attachment
resource "aws_iam_user_policy_attachment" "CircleCI-Upload-To-S3-attach" {
  user      = "${var.circleci_user}"
  policy_arn = "${aws_iam_policy.CircleCI-Upload-To-S3.arn}"
}

# IAM cicd user Policy attachment
resource "aws_iam_user_policy_attachment" "CircleCI-Code-Deploy-attach" {
  user      = "${var.circleci_user}"
  policy_arn = "${aws_iam_policy.CircleCI-Code-Deploy.arn}"
}

# IAM cicd user Policy attachment
resource "aws_iam_user_policy_attachment" "circleci-ec2-ami-attach" {
  user      = "${var.circleci_user}"
  policy_arn = "${aws_iam_policy.circleci-ec2-ami.arn}"
}

# IAM CodeDeployEC2ServiceRole Policy attachment
resource "aws_iam_policy_attachment" "WebAppS3-attach" {
  name       = "WebAppS3-attachment"
  roles      = ["${aws_iam_role.CodeDeployEC2ServiceRole.name}"]
  policy_arn = "${aws_iam_policy.WebAppS3.arn}"
}

# IAM CodeDeployEC2ServiceRole Policy attachment
resource "aws_iam_policy_attachment" "CodeDeployEC2ServiceRole-attach" {
  name       = "CodeDeployEC2ServiceRole-attachment"
  roles      = ["${aws_iam_role.CodeDeployEC2ServiceRole.name}"]
  policy_arn = "${aws_iam_policy.CodeDeploy-EC2-S3.arn}"
}

# IAM CodeDeployEC2ServiceRole Policy attachment
resource "aws_iam_policy_attachment" "CloudWatchAgentServerPolicy-attach" {
  name       = "CloudWatchAgentServerPolicy-attachment"
  roles      = ["${aws_iam_role.CodeDeployEC2ServiceRole.name}"]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM CodeDeployEC2ServiceRole Policy attachment
resource "aws_iam_policy_attachment" "AmazonSSMManagedInstanceCore-attach" {
  name       = "AmazonSSMManagedInstanceCore-attachment"
  roles      = ["${aws_iam_role.CodeDeployEC2ServiceRole.name}"]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM CodeDeployServiceRole Policy attachment
resource "aws_iam_policy_attachment" "CodeDeployServiceRole-attach" {
  name       = "CodeDeployServiceRole-attachment"
  roles      = ["${aws_iam_role.CodeDeployServiceRole.name}"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# # IAM  EC2-CSYE6225 Profile Instance
# resource "aws_iam_instance_profile" "EC2-CSYE6225-instance-profile" {
#   name = "EC2-CSYE6225-instance-profile"
#   role = "${aws_iam_role.EC2-CSYE6225.name}"
# }

 # IAM  CodeDeployEC2ServiceRole Profile Instance
resource "aws_iam_instance_profile" "CodeDeployEC2ServiceRole-instance-profile" {
  name = "CodeDeployEC2ServiceRole-instance-profile"
  role = "${aws_iam_role.CodeDeployEC2ServiceRole.name}"
}

#----------------------Dynamodb---------------------------------------------------------------------------------------------------------

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

#--------------------------------------------------------------CodeDeploy-------------------------------------------------------------------------

resource "aws_codedeploy_app" "csye6225-webapp" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}

resource "aws_codedeploy_deployment_group" "csye6225-webapp-deployment" {
  app_name              = "${aws_codedeploy_app.csye6225-webapp.name}"
  deployment_group_name = "csye6225-webapp-deployment"
  service_role_arn      = "${aws_iam_role.CodeDeployServiceRole.arn}"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }
  
  ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "Webapp_EC2"
    }
  
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

}
