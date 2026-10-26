variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "vpc-test-ojflores"
}

variable "vpc_cidr" {
  description = "CIDR Block for the VPC"
  type        = string
  default     = "10.15.0.0/16"
}

variable "vpc_azs" {
  description = "Availability Zones for the VPC"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "vpc_private_subnets" {
  description = "List of private subnets in the VPC"
  type        = list(string)
  default     = ["10.15.1.0/24", "10.15.2.0/24", "10.15.3.0/24"]
}

variable "vpc_public_subnets" {
  description = "List of public subnets in the VPC"
  type        = list(string)
  default     = ["10.15.101.0/24", "10.15.102.0/24", "10.15.103.0/24"]
}

variable "vpc_intra_subnets" {
  description = "List of intra subnets in the VPC"
  type        = list(string)
  default     = ["10.15.201.0/24", "10.15.202.0/24", "10.15.203.0/24"]
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-learning-ojflores"
}

variable "cluster_version" {
  description = "Version of the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "db_engine" {
  type    = string
  default = "postgres"
}

variable "db_engine_version" {
  type    = string
  default = "18.6"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro" # update to a different version before submitting
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "dbadmin"
}

variable "domain_name" {
  description = "Domain name for the static site"
  type        = string
  default     = "cloudfront-test.ojflores-primary.ping-demo.com"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the domain"
  type        = string
  default     = "Z0006647AO87JRWW2730"
}

variable "alert_email" {
  description = "Email address for alarm notifications"
  type        = string
  default     = "you@example.com"
}