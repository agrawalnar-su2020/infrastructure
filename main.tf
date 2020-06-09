# AWS Provider
provider "aws" {
  region = "us-east-1"
}

# VPC name
variable "vpc_name" {
  type = "string"
}
# VPC_cidr
variable "vpc_cidr" {
type="string"
}

# Subnet_cidrs
variable "public_cidrs" {
  type    = "list"
  #default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
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
  count                   = 3
  cidr_block              = "${var.public_cidrs[count.index]}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"

  tags = {
    Name = "public-subnet.${count.index + 1}"
  }
}

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

# Associate Public Subnet with Public Route Table
resource "aws_route_table_association" "public_subnet_assoc" {
  count          = 3
  route_table_id = "${aws_route_table.public_route.id}"
  subnet_id      = "${aws_subnet.public_subnet.*.id[count.index]}"
}


