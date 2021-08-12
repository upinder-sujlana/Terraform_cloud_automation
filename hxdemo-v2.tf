################################################################################################
# Author: Upinder Sujlana
# Version: v1.0.0
# Date: 06/21/2021
# Description: This demo TF file will create a S3 bucket and 2 EC2 instances as demo.
# Usage: terraform apply
###############################################################################################

# Notes :-
# Firstly you need to AWS IAM user which terraform can use for programmatic access to AWS
#        Follow guide : https://www.simplified.guide/aws/iam/create-programmatic-access-user

# Second - Create a credentials and config file in %UserProfile%/.aws/credentials (windows) or ∼/.aws/credentials for MAC/Linux
#        Follow Guide : https://blog.gruntwork.io/authenticating-to-aws-with-the-credentials-file-d16c0fbcbf9e


terraform {
  # Below in required_providers block specify all the providers and their attributes
  required_providers {
    aws = {
      # Which provider your want to download
      source = "hashicorp/aws"
      # What version of the provider plugin you want
      version = "~> 3.40.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 3.39.0"
    }
  }
  # What version of terraform we want to use
  required_version = "~> 0.15.1"
}
#----------------------------------------------------------------------------
# What is the Region of AWS this infrastruture shall be created in.
provider "aws" {
  region = "us-west-2"
}
#----------------------------------------------------------------------------
# Create a S3 - I use locals to demo how you can custom create a S3 bucket name.
locals {
  first_part  = "terraform"
  second_part = "${local.first_part}-upi"
  bucket_name = "${local.second_part}-s3-bucket-june-21"
}
resource "aws_s3_bucket" "myTerraformBucket" {
  bucket = local.bucket_name
  versioning {
    enabled = true
  }
  tags = {
    Environment = "Demo"
  }
}
resource "aws_s3_bucket_public_access_block" "private-bucket-public-access-block" {
  bucket                  = aws_s3_bucket.myTerraformBucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
#----------------------------------------------------------------------------
# EC2 section
#Create a Security group for the EC2 that shall allow SSH, HTTP & HTTPS
variable "sg_ports" {
  type        = list(number)
  description = "list of ingress ports"
  default     = [22, 80, 443]
}
resource "aws_security_group" "terraform-allow-ssh-http-https-sg" {
  name        = "terraform-allow-ssh-http-https-sg"
  description = "Ingress for EC2"

  dynamic "ingress" {
    for_each = var.sg_ports
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  dynamic "egress" {
    for_each = var.sg_ports
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
#---------------------------------------------------------------------------
# EC2 section - Setup variables
variable "instance_tags" {
  type    = list(any)
  default = ["upinder-1", "upinder-2"]
}

variable "instance_type" {
  default = "t2.micro"
}

variable "instance_count" {
  default = "2"
}

variable "ami" {
  type = map(any)

  default = {
    "us-east-2" = "ami-04169656fea786776"
    "us-west-2" = "ami-0800fc0fa715fdcfe"
  }
}

variable "aws_region" {
  default = "us-west-2"
}
#-------------------------------------------------------------------------------
# EC2 section - Actually utilize what we created before to now sping up 2 EC2 instances.
resource "aws_instance" "my-instance" {
  count                  = var.instance_count
  ami                    = lookup(var.ami, var.aws_region)
  instance_type          = var.instance_type
  key_name               = "terraform-key-pair"
  vpc_security_group_ids = [aws_security_group.terraform-allow-ssh-http-https-sg.id]
  user_data              = file("http-server.sh")

  tags = {
    Name = element(var.instance_tags, count.index)
  }

}
#-------------------------------------------------------------------------------
# Lets print the time
locals {
  time = formatdate("DD MMM YYYY hh:mm ZZZ", timestamp())
}
output "timestamp" {
  value = local.time
}

#Lets print the created S3 buckets ARN
output "bucket_arn" {
  value = aws_s3_bucket.myTerraformBucket.arn
}
#Lets print the public IP of the created EC2 instances.
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.my-instance.*.public_ip
}
